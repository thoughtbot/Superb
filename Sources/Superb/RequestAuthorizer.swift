import Result
import UIKit

public protocol RequestAuthorizerProtocol {
  func performAuthorized(_ request: URLRequest, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void)
}

public final class RequestAuthorizer<Token>: RequestAuthorizerProtocol {
  let applicationDelegate: () -> UIApplicationDelegate?
  let authenticationProvider: AnyAuthenticationProvider<Token>
  let urlSession: URLSession

  private var authenticationState: AuthenticationState<Token>
  private var pendingRequests: [PendingRequest] = []

  private let callbackQueue: DispatchQueue
  private let messageQueue: OperationQueue

  public init<Provider: AuthenticationProvider, Storage: TokenStorage>(
    authenticationProvider: Provider,
    tokenStorage: Storage,
    queue callbackQueue: DispatchQueue = .main,
    applicationDelegate: @autoclosure @escaping () -> UIApplicationDelegate? = defaultApplicationDelegate,
    urlSession: URLSession = .shared
  ) where Provider.Token == Token, Storage.Token == Token {
    self.applicationDelegate = applicationDelegate
    self.authenticationState = AuthenticationState(tokenStorage: tokenStorage)
    self.authenticationProvider = AnyAuthenticationProvider(authenticationProvider)
    self.callbackQueue = callbackQueue
    self.messageQueue = urlSession.delegateQueue
    self.urlSession = urlSession

    precondition(messageQueue.maxConcurrentOperationCount == 1, "The provided URLSession's delegateQueue must have a maxConcurrentOperationCount of 1.")
  }

  /// Performs `request` based on the current authentication state.
  ///
  /// - If authenticated, authorizes the request using the cached token
  ///   and performs it.
  /// - If unauthenticated, invokes the auth provider to authenticate
  ///   before authorizing with the updated token.
  /// - If already authenticating, enqueues `request` to be performed
  ///   later, once authentication is complete.
  ///
  /// If the request fails with a 401 response, the cached authentication
  /// token is cleared and the request authorizer reauthenticates
  /// automatically, then once completed performs the request again with
  /// the new token.
  ///
  /// - parameters:
  ///     - request: The `URLRequest` to authorize and perform.
  ///     - completionHandler: A function to be invoked with the
  ///       response from performing `request`, or the error returned
  ///       from authentication.
  public func performAuthorized(_ request: URLRequest, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void) {
    messageQueue.addOperation {
      self.performAuthorized(request, reauthenticate: true, completionHandler: completionHandler)
    }
  }

  /// Safely clears the token from the underlying token storage.
  ///
  /// - throws: An error if the call to `TokenStorage.deleteToken()` fails.
  ///
  /// - note: If called while authenticating, this method will have no
  ///   effect on the authentication process, i.e., pending requests will
  ///   still be performed using the new token once authentication completes.
  public func clearToken() throws {
    try messageQueue.sync {
      try authenticationState.clearToken()
    }
  }

  /// Entry point for performing authorized requests, reauthenticating if
  /// necessary. Uses the current `authorizationState` to determine whether
  /// to perform the request, authenticate first, or wait for authentication
  /// to complete before performing the request.
  ///
  /// - parameters:
  ///     - request: A `URLRequest` to authorize and perform.
  ///     - reauthenticate: If `true`, a 401 response will intercepted
  ///       and the auth provider asked to reauthenticate, before
  ///       automicatically retrying `request`. If `false`, the 401
  ///       response will be passed back to the caller.
  ///     - completionHandler: A function to be invoked with the
  ///       response from performing `request`, or the error returned
  ///       from authentication.
  private func performAuthorized(_ request: URLRequest, reauthenticate: Bool, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void) {
    fetchAuthenticationState(handlingErrorsWith: completionHandler) { state, startedAuthenticating in
      switch state {
      case .authenticated(let token):
        perform(request, with: token, reauthenticate: reauthenticate, completionHandler: completionHandler)

      case .unauthenticated:
        startedAuthenticating = true
        enqueuePendingRequest(request, completionHandler: completionHandler)
        authenticate(errorHandler: completionHandler)

      case .authenticating:
        enqueuePendingRequest(request, completionHandler: completionHandler)
      }
    }
  }

  /// Performs `request`, authorizing it with the provided `token`,
  /// reauthenticating upon a 401 response if necessary.
  ///
  /// - parameters:
  ///     - request: A `URLRequest` to authorize and perform.
  ///     - token: A token used to set the `Authorization` header.
  ///     - reauthenticate: If `true`, a 401 response will intercepted
  ///       and the auth provider asked to reauthenticate, before
  ///       automicatically retrying `request`. If `false`, the 401
  ///       response will be passed back to the caller.
  ///     - completionHandler: A function to be invoked with the
  ///       response from performing `request`.
  private func perform(_ request: URLRequest, with token: Token, reauthenticate: Bool, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void) {
    var authorizedRequest = request

    do {
      try authenticationProvider.authorize(&authorizedRequest, with: token)
    } catch {
      callbackQueue.async {
        completionHandler(.failure(.authorizationFailed(error)))
      }
      return
    }

    let task = urlSession.dataTask(with: authorizedRequest) { data, response, error in
      let result: Result<(Data, URLResponse), SuperbError>

      if let error = error {
        result = .failure(.requestFailed(request.url, error))
      } else if let data = data, let response = response {
        result = .success(data, response)
      } else {
        fatalError("expected response data from the server, got \(response ??? "nil"), \(data ??? "nil")")
      }

      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 401,
        reauthenticate
        else {
          self.callbackQueue.async {
            completionHandler(result)
          }
          return
        }

      self.handlingAuthenticationErrors(with: completionHandler) {
        try self.authenticationState.clearToken()
        self.performAuthorized(request, reauthenticate: false, completionHandler: completionHandler)
      }
    }

    task.resume()
  }

  /// Enqueues a pending request that will be performed once authentication is complete.
  ///
  /// - precondition: Must be called on `messageQueue`.
  ///
  /// - parameters:
  ///     - request: A `URLRequest` to perform if authentication
  ///       completes sucessfully.
  ///     - completionHandler: Invoked with `SuperbError.unauthorized`
  ///       if authentication fails, otherwise invoked with the result
  ///       of performing `request`.
  private func enqueuePendingRequest(_ request: URLRequest, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void) {
    let request = PendingRequest(request: request, completionHandler: completionHandler)
    pendingRequests.append(request)
  }

  /// Notifies pending requests of the result of authentication, starting them if necessary.
  ///
  /// - precondition: Must be called on `messageQueue`.
  private func notifyPendingRequests(with authenticationResult: AuthenticationResult<Token>) {
    let complete: (PendingRequest) -> Void

    switch authenticationResult {
    case .authenticated(let token):
      complete = { pending in
        self.perform(pending.request, with: token, reauthenticate: false, completionHandler: pending.completionHandler)
      }

    case .cancelled:
      complete = { pending in
        self.callbackQueue.async {
          pending.completionHandler(.failure(.authenticationCancelled))
        }
      }

    case .failed(let error):
      complete = { pending in
        self.callbackQueue.async {
          pending.completionHandler(.failure(.authenticationFailed(error)))
        }
      }
    }

    let pendingRequests = self.pendingRequests
    self.pendingRequests.removeAll()
    pendingRequests.forEach(complete)
  }

  /// Invokes the auth provider to authenticate, updating `authenticationState`
  /// before performing `request` with the new token.
  ///
  /// - parameters:
  ///     - request: A `URLRequest` to perform after authenticating successfully.
  ///     - errorHandler: If authorization fails, this function will be invoked
  ///       with an appropriate `SuperbError` describing the reason.
  private func authenticate<T>(errorHandler: @escaping (Result<T, SuperbError>) -> Void) {
    DispatchQueue.main.async {
      guard let topViewController = self.topViewController else {
        self.callbackQueue.async {
          errorHandler(.failure(.userInteractionRequired))
        }
        return
      }

      self.authenticationProvider.authenticate(over: topViewController) { result in
        self.messageQueue.addOperation {
          self.completeAuthentication(with: result, errorHandler: errorHandler)
        }
      }
    }
  }

  private func completeAuthentication<T>(with result: AuthenticationResult<Token>, errorHandler: @escaping (Result<T, SuperbError>) -> Void) {
    updateAuthenticationState(handlingErrorsWith: errorHandler) {
      defer { notifyPendingRequests(with: result) }

      switch result {
      case let .authenticated(token):
        return .authenticated(token)
      case .cancelled, .failed:
        return .unauthenticated
      }
    }
  }

  private func fetchAuthenticationState<T>(handlingErrorsWith errorHandler: @escaping (Result<T, SuperbError>) -> Void, body: (CurrentAuthenticationState<Token>, inout Bool) -> Void) {
    handlingAuthenticationErrors(with: errorHandler) {
      try authenticationState.fetch(body)
    }
  }

  private func updateAuthenticationState<T>(handlingErrorsWith errorHandler: @escaping (Result<T, SuperbError>) -> Void, body: () -> NewAuthenticationState<Token>) {
    handlingAuthenticationErrors(with: errorHandler) {
      try authenticationState.update(body)
    }
  }

  private func handlingAuthenticationErrors<T>(with errorHandler: @escaping (Result<T, SuperbError>) -> Void, body: () throws -> Void) {
    let error: SuperbError

    do {
      try body()
      return
    } catch let superbError as SuperbError {
      error = superbError
    } catch {
      fatalError("Unexpected error: \(error.localizedDescription)")
    }

    callbackQueue.async {
      errorHandler(.failure(error))
    }
  }

  private var topViewController: UIViewController? {
    guard let rootViewController = applicationDelegate()?.window??.rootViewController
      else { return nil }

    return rootViewController.topPresentedViewController ?? rootViewController
  }
}

extension RequestAuthorizer where Token: KeychainDecodable & KeychainEncodable {
  public convenience init<Provider: AuthenticationProvider>(
    authenticationProvider: Provider,
    queue: DispatchQueue = .main,
    applicationDelegate: @autoclosure @escaping () -> UIApplicationDelegate? = defaultApplicationDelegate,
    urlSession: URLSession = .shared
  ) where Provider.Token == Token {
    let keychainTokenStorage = KeychainTokenStorage<Token>(service: Provider.keychainServiceName, label: Provider.identifier)
    self.init(authenticationProvider: authenticationProvider, tokenStorage: keychainTokenStorage, queue: queue, applicationDelegate: applicationDelegate, urlSession: urlSession)
  }
}

private var defaultApplicationDelegate: UIApplicationDelegate? {
  return UIApplication.shared.delegate
}

private extension Sequence {
  var first: Iterator.Element? {
    return first(where: { _ in true })
  }

  var last: Iterator.Element? {
    return suffix(1).first
  }
}

private extension UIViewController {
  var hierarchy: AnySequence<UIViewController> {
    return AnySequence { () -> AnyIterator<UIViewController> in
      var queue = [self]

      return AnyIterator {
        if !queue.isEmpty {
          let next = queue.removeFirst()
          queue.append(contentsOf: next.childViewControllers)
          return next
        } else {
          return nil
        }
      }
    }
  }

  var topPresentedViewController: UIViewController? {
    let presented = hierarchy.lazy.flatMap { $0.presentedViewController }
    let firstPresented = presented.first
    return firstPresented?.topPresentedViewController ?? firstPresented
  }
}

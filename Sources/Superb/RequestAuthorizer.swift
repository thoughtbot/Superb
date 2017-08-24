import Result
import UIKit

public protocol RequestAuthorizerProtocol {
  func performAuthorized(_ request: URLRequest, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void)
}

public final class RequestAuthorizer<Token>: RequestAuthorizerProtocol {
  let applicationDelegate: () -> UIApplicationDelegate?
  let authenticationProvider: AnyAuthenticationProvider<Token>
  let urlSession: URLSession

  private let authenticationComplete: Channel<AuthenticationResult<Token>>
  private var authenticationState: AuthenticationState<Token>
  private let callbackQueue: DispatchQueue
  private let messageQueue: DispatchQueue

  public init<Provider: AuthenticationProvider, Storage: TokenStorage>(
    authenticationProvider: Provider,
    tokenStorage: Storage,
    queue callbackQueue: DispatchQueue = .main,
    applicationDelegate: @autoclosure @escaping () -> UIApplicationDelegate? = defaultApplicationDelegate,
    urlSession: URLSession = .shared
  ) where Provider.Token == Token, Storage.Token == Token {
    self.applicationDelegate = applicationDelegate
    self.authenticationComplete = Channel()
    self.authenticationState = AuthenticationState(tokenStorage: tokenStorage)
    self.authenticationProvider = AnyAuthenticationProvider(authenticationProvider)
    self.callbackQueue = callbackQueue
    self.messageQueue = DispatchQueue(label: "com.thoughtbot.superb.\(type(of: self))")
    self.urlSession = urlSession
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
    performAuthorized(request, reauthenticate: true, completionHandler: completionHandler)
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
    authenticationProvider.authorize(&authorizedRequest, with: token)

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
        try self.clearToken()
        self.performAuthorized(request, reauthenticate: false, completionHandler: completionHandler)
      }
    }

    task.resume()
  }

  /// Enqueues a pending request that will be performed once authentication is complete.
  ///
  /// - note: In order to ensure pending requests see a consistent view
  ///   of the authentication state, this method **must** be called in the
  ///   `body` block of `fetchAuthenticationState()`, after checking that the
  ///   state is `.authenticating`.
  ///
  /// - parameters:
  ///     - request: A `URLRequest` to perform if authentication
  ///       completes sucessfully.
  ///     - completionHandler: Invoked with `SuperbError.unauthorized`
  ///       if authentication fails, otherwise invoked with the result
  ///       of performing `request`.
  private func enqueuePendingRequest(_ request: URLRequest, completionHandler: @escaping (Result<(Data, URLResponse), SuperbError>) -> Void) {
    authenticationComplete.subscribe { result in
      let complete: (() -> Void)?

      switch result {
      case .authenticated(let token):
        complete = nil
        self.perform(request, with: token, reauthenticate: false, completionHandler: completionHandler)

      case .cancelled:
        complete = {
          completionHandler(.failure(.authenticationCancelled))
        }

      case .failed(let error):
        complete = {
          completionHandler(.failure(.authenticationFailed(error)))
        }
      }

      if let complete = complete {
        self.callbackQueue.async(execute: complete)
      }
    }
  }

  /// Invokes the auth provider to authenticate, updating `authenticationState`
  /// before performing `request` with the new token.
  ///
  /// - note: This method must be called in the `body` block of
  ///   `fetchAuthenticationState()`, after checking that the state
  ///   is `.unauthenticated` and setting `startedAuthenticating` to `true`.
  ///
  /// - note: When authentication completes, the result is broadcast to
  ///   pending requests via the `authenticationComplete` channel. This
  ///   broadcast occurs while holding the `authenticationState` lock,
  ///   to ensure that no new pending requests are enqueued before the
  ///   the authentication state is updated. For this to remain true,
  ///   new subscribers must only be added while holding the
  ///   `authenticationState` lock. Once the lock is released, new
  ///   requests will then see the state as either a `.authenticated`
  ///   or `.unauthenticated`, and react accordingly.
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
        self.updateAuthenticationState(handlingErrorsWith: errorHandler) {
          defer { self.authenticationComplete.broadcast(result) }

          switch result {
          case let .authenticated(token):
            return .authenticated(token)
          case .cancelled, .failed:
            return .unauthenticated
          }
        }
      }
    }
  }

  private func fetchAuthenticationState<T>(handlingErrorsWith errorHandler: @escaping (Result<T, SuperbError>) -> Void, body: (CurrentAuthenticationState<Token>, inout Bool) -> Void) {
    handlingAuthenticationErrors(with: errorHandler) {
      try messageQueue.sync {
        try authenticationState.fetch(body)
      }
    }
  }

  private func updateAuthenticationState<T>(handlingErrorsWith errorHandler: @escaping (Result<T, SuperbError>) -> Void, body: () -> NewAuthenticationState<Token>) {
    handlingAuthenticationErrors(with: errorHandler) {
      try messageQueue.sync {
        try authenticationState.update(body)
      }
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

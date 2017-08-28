import SafariServices
import Superb
import UIKit

enum TwitterAuthError: Error {
  case authenticationDenied
  case parseFailed
  case requestFailed(String?)
}

final class TwitterOAuthProvider: AuthenticationProvider {
  static let identifier = "com.thoughtbot.superb.twitter.oauth"
  static let keychainServiceName = "Twitter OAuth"

  fileprivate var currentAuthentication: (
    cancelHandler: () -> Void,
    completionHandler: (VerifierToken) -> Void,
    errorHandler: (Error) -> Void,
    delegate: SafariViewControllerDelegate,
    safari: SFSafariViewController
  )?

  func authorize(_ request: inout URLRequest, with token: String) {
    print("here")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    precondition(currentAuthentication == nil, "already authenticating")

    createRequestToken(errorHandler: completionHandler) { requestToken in
      DispatchQueue.main.async {
        self.authenticateViaTwitter(using: requestToken, over: viewController, errorHandler: completionHandler) { verifierToken in
          print(verifierToken)
          completionHandler(.cancelled)
        }
      }
    }
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return handleTwitterCallback(url, options: options)
  }
}

// - MARK: 1. Create Request Token

private extension TwitterOAuthProvider {
  func createRequestToken<T>(errorHandler: @escaping (AuthenticationResult<T>) -> Void, completionHandler: @escaping (RequestToken) -> Void) {
    var request = URLRequest(url: URL(string: "https://api.twitter.com/oauth/request_token")!)
    request.httpMethod = "POST"

    do {
      try request.applyTwitterSignature(
        consumerKey: Secrets.Twitter.consumerKey,
        consumerSecret: Secrets.Twitter.consumerSecret,
        parameters: [
          "oauth_callback": Secrets.Twitter.callbackURL.absoluteString,
        ]
      )
    } catch {
      errorHandler(.failed(error))
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard error == nil else {
        errorHandler(.failed(error!))
        return
      }

      let body = data.flatMap(String.init(decoding:))
      let response = response as! HTTPURLResponse

      guard response.statusCode == 200, let query = body else {
        errorHandler(.failed(TwitterAuthError.requestFailed(body)))
        return
      }

      guard let queryItems = URLQueryItem.queryItems(from: query),
        let token = RequestToken(from: queryItems),
        token.isOAuthCallbackConfirmed
      else {
        errorHandler(.failed(TwitterAuthError.parseFailed))
        return
      }

      completionHandler(token)
    }

    task.resume()
  }
}

// - MARK: 2. Sign In via Twitter

private extension TwitterOAuthProvider {
  func authenticateViaTwitter<T>(using requestToken: RequestToken, over viewController: UIViewController, errorHandler: @escaping (AuthenticationResult<T>) -> Void, completionHandler: @escaping (VerifierToken) -> Void) {
    var components = URLComponents(string: "https://api.twitter.com/oauth/authenticate")!
    components.queryItems = [URLQueryItem(name: "oauth_token", value: requestToken.token)]

    let safari = SFSafariViewController(url: components.url!)
    let delegate = SafariViewControllerDelegate { [weak self] _ in self?.failIfUnauthenticated() }
    let cancelHandler = { errorHandler(.cancelled) }
    let errorHandler = { errorHandler(.failed($0)) }
    currentAuthentication = (cancelHandler, completionHandler, errorHandler, delegate, safari)

    safari.delegate = delegate
    viewController.present(safari, animated: true)
  }

  private func failIfUnauthenticated() {
    guard let cancelHandler = currentAuthentication?.cancelHandler else { return }
    currentAuthentication = nil
    cancelHandler()
  }

  func handleTwitterCallback(_ url: URL, options _: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    guard let (_, completionHandler, errorHandler, _, safari) = currentAuthentication,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let parameters = components.queryItems
    else { return false }

    let continuation: () -> Void

    do {
      let token = try VerifierToken(from: parameters)
      continuation = { completionHandler(token) }
    } catch {
      continuation = { errorHandler(error) }
    }

    currentAuthentication = nil
    safari.dismiss(animated: true)
    DispatchQueue.main.async(execute: continuation)

    return true
  }
}

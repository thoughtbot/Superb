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

  func authorize(_ request: inout URLRequest, with token: AccessToken) throws {
    guard let url = request.url,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      return
    }

    let bodyQueryItems = request.httpBody
      .flatMap(String.init(decoding:))
      .flatMap(URLQueryItem.queryItems(from:)) ?? []

    let urlQueryItems = components.queryItems ?? []

    var parameters: [String: String] = [:]
    for item in (bodyQueryItems + urlQueryItems) {
      guard let value = item.value else { continue }
      parameters[item.name] = value
    }

    try request.applyTwitterSignature(
      consumerKey: Secrets.Twitter.consumerKey,
      consumerSecret: Secrets.Twitter.consumerSecret,
      oauthToken: token.token,
      oauthTokenSecret: token.secret,
      parameters: parameters
    )
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<AccessToken>) -> Void) {
    precondition(currentAuthentication == nil, "already authenticating")

    let cancelHandler = { completionHandler(.cancelled) }
    let errorHandler = { completionHandler(.failed($0)) }

    createRequestToken(errorHandler: errorHandler) { requestToken in
      DispatchQueue.main.async {
        self.authenticateViaTwitter(using: requestToken, over: viewController, cancelHandler: cancelHandler, errorHandler: errorHandler) { verifierToken in
          self.createAccessToken(using: verifierToken, errorHandler: errorHandler) { accessToken in
            completionHandler(.authenticated(accessToken))
          }
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
  func createRequestToken(errorHandler: @escaping (Error) -> Void, completionHandler: @escaping (RequestToken) -> Void) {
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
      errorHandler(error)
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard error == nil else {
        errorHandler(error!)
        return
      }

      let body = data.flatMap(String.init(decoding:))
      let response = response as! HTTPURLResponse

      guard response.statusCode == 200, let query = body else {
        errorHandler(TwitterAuthError.requestFailed(body))
        return
      }

      guard let queryItems = URLQueryItem.queryItems(from: query),
        let token = RequestToken(from: queryItems),
        token.isOAuthCallbackConfirmed
      else {
        errorHandler(TwitterAuthError.parseFailed)
        return
      }

      completionHandler(token)
    }

    task.resume()
  }
}

// - MARK: 2. Sign In via Twitter

private extension TwitterOAuthProvider {
  func authenticateViaTwitter(using requestToken: RequestToken, over viewController: UIViewController, cancelHandler: @escaping () -> Void, errorHandler: @escaping (Error) -> Void, completionHandler: @escaping (VerifierToken) -> Void) {
    var components = URLComponents(string: "https://api.twitter.com/oauth/authenticate")!
    components.queryItems = [URLQueryItem(name: "oauth_token", value: requestToken.token)]

    let safari = SFSafariViewController(url: components.url!)
    let delegate = SafariViewControllerDelegate { [weak self] _ in self?.failIfUnauthenticated() }
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

// - MARK: 3. Create Access Token

private extension TwitterOAuthProvider {
  func createAccessToken(using verifierToken: VerifierToken, errorHandler: @escaping (Error) -> Void, completionHandler: @escaping (AccessToken) -> Void) {
    var parameters = URLComponents()
    parameters.queryItems = [URLQueryItem(name: "oauth_verifier", value: verifierToken.verifier)]

    var request = URLRequest(url: URL(string: "https://api.twitter.com/oauth/access_token")!)
    request.httpBody = parameters.query?.data(using: .utf8)
    request.httpMethod = "POST"

    do {
      try request.applyTwitterSignature(
        consumerKey: Secrets.Twitter.consumerKey,
        consumerSecret: Secrets.Twitter.consumerSecret,
        oauthToken: verifierToken.token,
        parameters: [
          "oauth_verifier": verifierToken.verifier,
        ]
      )
    } catch {
      errorHandler(error)
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard error == nil else {
        errorHandler(error!)
        return
      }

      let body = data.flatMap(String.init(decoding:))
      let response = response as! HTTPURLResponse

      guard response.statusCode == 200, let query = body else {
        errorHandler(TwitterAuthError.requestFailed(body))
        return
      }

      guard let queryItems = URLQueryItem.queryItems(from: query),
        let token = AccessToken(from: queryItems)
      else {
        errorHandler(TwitterAuthError.parseFailed)
        return
      }

      completionHandler(token)
    }

    task.resume()
  }
}

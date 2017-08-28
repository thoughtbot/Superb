import Superb
import UIKit

enum TwitterAuthError: Error {
  case parseFailed
  case requestFailed(String?)
}

final class TwitterOAuthProvider: AuthenticationProvider {
  static let identifier = "com.thoughtbot.superb.twitter.oauth"
  static let keychainServiceName = "Twitter OAuth"

  func authorize(_ request: inout URLRequest, with token: String) {
    print("here")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    createRequestToken(errorHandler: completionHandler) { requestToken in
      print(requestToken)
    }
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

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

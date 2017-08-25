import Superb
import UIKit

enum TwitterAuthError: Error {
  case parseError
}

extension CharacterSet {
  static let twitterAllowed: CharacterSet = {
    var characterSet = CharacterSet()
    characterSet.insert(charactersIn: "0123456789")
    characterSet.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    characterSet.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
    characterSet.insert(charactersIn: "-._~")
    return characterSet
  }()
}

private func signature(httpMethod: String, urlString: String, parameters: [String], consumerSecret: String, oauthTokenSecret: String? = nil) -> String {
  let parametersString = parameters.sorted().joined(separator: "&").addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!
  let signatureBaseString = [httpMethod, urlString.addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!, parametersString].joined(separator: "&")
  let signingKey = [consumerSecret, oauthTokenSecret ?? ""].joined(separator: "&")
  let signatureBaseStringLength = signatureBaseString.utf8.count
  let signingKeyLength = signingKey.utf8.count

  return signatureBaseString.withCString { signatureBaseString in
    signingKey.withCString { signingKey in
      let digestLength = Int(CC_SHA1_DIGEST_LENGTH)
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
      let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA1)
      CCHmac(algorithm, signingKey, signingKeyLength, signatureBaseString, signatureBaseStringLength, buffer)
      return Data(bytesNoCopy: buffer, count: digestLength, deallocator: .free).base64EncodedString()
    }
  }
}

extension String {
  static func makeRandomBase64EncodedString(length: Int) -> String {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
    // FIXME: Don't ignore the error
    _ = SecRandomCopyBytes(kSecRandomDefault, length, buffer)
    return Data(bytesNoCopy: buffer, count: length, deallocator: .free).base64EncodedString()
  }
}

final class TwitterOAuthProvider: AuthenticationProvider {
  static let identifier = "com.thoughtbot.superb.twitter.oauth"
  static let keychainServiceName = "Twitter OAuth"

  func authorize(_ request: inout URLRequest, with token: String) {
    print("here")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    var request = URLRequest(url: URL(string: "https://api.twitter.com/oauth/request_token")!)
    request.httpMethod = "POST"

    let oauthCallback = Secrets.Twitter.callbackURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!
    let oauthConsumerKey = Secrets.Twitter.consumerKey
    let oauthNonce = String.makeRandomBase64EncodedString(length: 32).addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!
    let signatureMethod = "HMAC-SHA1"
    let requestTimestamp = String(describing: Int(Date().timeIntervalSince1970))
    let oauthVersion = "1.0"

    let params = [
      "oauth_callback=\(oauthCallback)",
      "oauth_consumer_key=\(oauthConsumerKey)",
      "oauth_nonce=\(oauthNonce)",
      "oauth_signature_method=\(signatureMethod)",
      "oauth_timestamp=\(requestTimestamp)",
      "oauth_version=\(oauthVersion)"
    ]

    let oauthSignature = signature(httpMethod: "POST", urlString: request.url!.absoluteString, parameters: params, consumerSecret: Secrets.Twitter.consumerSecret).addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!

    let headerValue = "OAuth oauth_callback=\"\(oauthCallback)\",oauth_consumer_key=\"\(oauthConsumerKey)\",oauth_nonce=\"\(oauthNonce)\",oauth_signature=\"\(oauthSignature)\",oauth_signature_method=\"\(signatureMethod)\",oauth_timestamp=\"\(requestTimestamp)\",oauth_version=\"\(oauthVersion)\""
    request.setValue(headerValue, forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { (responseData, urlResponse, error) in
      var components = URLComponents()
      guard let queryStringData = responseData, let query = String(decoding: queryStringData) else {
        completionHandler(.failed(TwitterAuthError.parseError))
        return
      }

      components.query = query
      guard let queryComponents = components.queryItems else {
        completionHandler(.failed(TwitterAuthError.parseError))
        return
      }

      var oauthToken: String?
      var oauthTokenSecret: String?
      for component in queryComponents {
        if component.name == "oauth_token" {
          oauthToken = component.value
        } else if component.name == "oauth_token_secret" {
          oauthTokenSecret = component.value
        }
      }

      guard let token = oauthToken, let secret = oauthTokenSecret else {
        completionHandler(.failed(TwitterAuthError.parseError))
        return
      }

      print(token)
      print(secret)
    }

    task.resume()
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

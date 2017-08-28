import Foundation

struct RequestToken {
  let token: String
  let secret: String
  let isOAuthCallbackConfirmed: Bool

  init?(from queryItems: [URLQueryItem]) {
    var parameters: [String: String] = [:]
    for item in queryItems {
      if let value = item.value {
        parameters[item.name] = value
      }
    }

    guard let token = parameters["oauth_token"],
      let secret = parameters["oauth_token_secret"],
      let callbackConfirmed = parameters["oauth_callback_confirmed"]
    else { return nil }

    switch callbackConfirmed {
    case "true":
      isOAuthCallbackConfirmed = true
    case "false":
      isOAuthCallbackConfirmed = false
    default:
      return nil
    }

    self.token = token
    self.secret = secret
  }
}

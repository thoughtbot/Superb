import Foundation
import Superb

struct AccessToken {
  let token: String
  let secret: String

  init?(from queryItems: [URLQueryItem]) {
    let parameters = Dictionary(queryItems: queryItems, filteringEmptyKeys: true) ?? [:]

    guard let token = parameters["oauth_token"],
      let secret = parameters["oauth_token_secret"]
    else {
      return nil
    }

    self.token = token
    self.secret = secret
  }
}

extension AccessToken: KeychainDecodable, KeychainEncodable {
  init?(decoding data: Data) {
    guard let query = String(decoding: data),
      let queryItems = URLQueryItem.queryItems(from: query)
    else {
      return nil
    }

    self.init(from: queryItems)
  }

  func encoded() -> Data {
    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "oauth_token", value: token),
      URLQueryItem(name: "oauth_token_secret", value: secret),
    ]
    return components.query!.data(using: .utf8)!
  }
}

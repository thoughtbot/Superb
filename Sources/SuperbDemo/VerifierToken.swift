import Foundation

struct VerifierToken {
  let token: String
  let verifier: String

  init(from queryItems: [URLQueryItem]) throws {
    let parameters = Dictionary(queryItems: queryItems, filteringEmptyKeys: true) ?? [:]
    guard let token = parameters["oauth_token"],
      let verifier = parameters["oauth_verifier"]
    else {
      if parameters["denied"] != nil {
        throw TwitterAuthError.authenticationDenied
      } else {
        throw TwitterAuthError.parseFailed
      }
    }

    self.token = token
    self.verifier = verifier
  }
}

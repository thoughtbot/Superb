import CommonCrypto.CommonHMAC
import Foundation

extension URLRequest {
  mutating func applyTwitterSignature(consumerKey: String, consumerSecret: String, oauthToken: String? = nil, oauthTokenSecret: String? = nil, parameters: [String: String]) throws {
    var parameters = parameters
    parameters["oauth_consumer_key"] = consumerKey
    parameters["oauth_nonce"] = try String.makeRandomHexadecimalString(length: 32)
    parameters["oauth_signature_method"] = "HMAC-SHA1"
    parameters["oauth_timestamp"] = String(describing: Int(Date().timeIntervalSince1970))
    parameters["oauth_version"] = "1.0"

    if let oauthToken = oauthToken {
      parameters["oauth_token"] = oauthToken
    }

    func percentEncoded(_ string: String) -> String {
      return string.addingPercentEncoding(withAllowedCharacters: .twitterAllowed)!
    }

    let parameterString = parameters.lazy
      .map { "\(percentEncoded($0))=\(percentEncoded($1))" }
      .sorted()
      .joined(separator: "&")

    var baseURLComponents = URLComponents(url: url!, resolvingAgainstBaseURL: false)!
    baseURLComponents.fragment = nil
    baseURLComponents.query = nil

    let signatureBase = [
      httpMethod!,
      percentEncoded(baseURLComponents.string!),
      percentEncoded(parameterString),
    ].joined(separator: "&")

    let signingKey = [
      percentEncoded(consumerSecret),
      oauthTokenSecret.map(percentEncoded) ?? "",
    ].joined(separator: "&")

    parameters["oauth_signature"] = signatureBase.hmacSHA1(usingKey: signingKey)

    let authorizationString = parameters.lazy
      .map { "\(percentEncoded($0))=\"\(percentEncoded($1))\"" }
      .sorted()
      .joined(separator: ", ")

    setValue("OAuth \(authorizationString)", forHTTPHeaderField: "Authorization")
  }
}

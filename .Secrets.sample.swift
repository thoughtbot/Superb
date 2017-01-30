import struct Foundation.URL

enum Secrets {
  enum GitHubOAuth {
    static let clientId = "<client id>"
    static let clientSecret = "<client secret>"
    static let callbackURL = URL(string: "<callback url>")!
  }
}

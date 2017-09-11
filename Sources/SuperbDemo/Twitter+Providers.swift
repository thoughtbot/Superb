import Superb

extension TwitterOAuthProvider {
  static var shared: TwitterOAuthProvider {
    return Superb.register(
      TwitterOAuthProvider()
    )
  }
}

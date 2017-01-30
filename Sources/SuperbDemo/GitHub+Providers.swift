import Superb

extension GitHubBasicAuthProvider {
  static var shared: GitHubBasicAuthProvider {
    return Superb.register(
      GitHubBasicAuthProvider()
    )
  }
}

extension GitHubOAuthProvider {
  static var shared: GitHubOAuthProvider {
    return Superb.register(
      GitHubOAuthProvider(
        clientId: Secrets.GitHubOAuth.clientId,
        clientSecret: Secrets.GitHubOAuth.clientSecret,
        redirectURI: Secrets.GitHubOAuth.callbackURL
      )
    )
  }
}

import Superb

struct GitHubAPIClient: APIClient {
  static let basicAuthClient = GitHubAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authenticationProvider: GitHubBasicAuthProvider.shared,
      urlSession: .api
    )
  )

  static let oauthClient = GitHubAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authenticationProvider: GitHubOAuthProvider.shared,
      urlSession: .api
    )
  )

  private let authorizer: RequestAuthorizerProtocol

  init(requestAuthorizer: RequestAuthorizerProtocol) {
    authorizer = requestAuthorizer
  }

  func getProfile(_ completionHandler: @escaping (Result<Profile, AnyError>) -> Void) {
    let request = URLRequest(url: URL(string: "https://api.github.com/user")!)

    authorizer.performAuthorized(request) { result in
      let profile = result
        .mapError(AnyError.init)
        .tryMap(Profile.parse)

      completionHandler(profile)
    }
  }
}

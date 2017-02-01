import Superb

struct GitHubAPIClient {
  static let basicAuthClient = GitHubAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authorizationProvider: GitHubBasicAuthProvider.shared
    )
  )

  static let oauthClient = GitHubAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authorizationProvider: GitHubOAuthProvider.shared
    )
  )

  private let authorizer: RequestAuthorizerProtocol

  init(requestAuthorizer: RequestAuthorizerProtocol) {
    authorizer = requestAuthorizer
  }

  func getLogin(completionHandler: @escaping (Result<String, SuperbError>) -> Void) {
    let request = URLRequest(url: URL(string: "https://api.github.com/user")!)

    authorizer.performAuthorized(request) { result in
      switch result {
      case let .success(data, _):
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let login = object["login"] as! String
        completionHandler(.success(login))

      case let .failure(error):
        completionHandler(.failure(error))
      }
    }
  }
}

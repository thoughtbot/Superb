import Argo
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

extension Decodable {
  static func parse(data: Data, response _: URLResponse) throws -> DecodedType {
    let object = try JSONSerialization.jsonObject(with: data)
    let json = JSON(object)
    return try Self.decode(json).dematerialize()
  }
}

import Argo
import Superb

struct TwitterAPIClient: APIClient {
  static let oauthClient = TwitterAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authenticationProvider: TwitterOAuthProvider.shared,
      urlSession: .api
    )
  )

  private let authorizer: RequestAuthorizerProtocol

  init(requestAuthorizer: RequestAuthorizerProtocol) {
    authorizer = requestAuthorizer
  }

  func getProfile(_ completionHandler: @escaping (Result<Profile, AnyError>) -> Void) {
    let request = URLRequest(url: URL(string: "https://api.twitter.com/1.1/account/verify_credentials.json")!)

    authorizer.performAuthorized(request) { result in
      let profile = result
        .mapError(AnyError.init)
        .tryMap { try Profile.parse(data: $0, response: $1, decode: Profile.decodeTwitterProfile) }

      completionHandler(profile)
    }
  }
}

import Superb
import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize")!
let createAccessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

final class GitHubOAuthProvider: AuthenticationProvider {
  static let identifier = "com.thoughtbot.superb.github.oauth"
  static let keychainServiceName = "GitHub OAuth"

  let clientId: String
  let clientSecret: String
  let redirectURI: URL

  private var currentAuthorization: (
    safariViewController: SFSafariViewController,
    delegate: SafariViewControllerDelegate,
    completionHandler: (AuthenticationResult<String>) -> Void
  )?

  init(clientId: String, clientSecret: String, redirectURI: URL) {
    self.clientId = clientId
    self.clientSecret = clientSecret
    self.redirectURI = redirectURI
  }

  func authorize(_ request: inout URLRequest, with token: String) {
    request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    precondition(currentAuthorization == nil)

    var authorizeURLComponents = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
    authorizeURLComponents.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
    ]

    let safariViewController = SFSafariViewController(url: authorizeURLComponents.url!)
    let delegate = SafariViewControllerDelegate { [weak self] in self?.failIfUnauthorized() }
    safariViewController.delegate = delegate
    currentAuthorization = (safariViewController, delegate, completionHandler)
    viewController.present(safariViewController, animated: true)
  }

  private func failIfUnauthorized() {
    guard let completionHandler = currentAuthorization?.completionHandler else { return }
    currentAuthorization = nil
    completionHandler(.cancelled)
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    guard let authorization = self.currentAuthorization,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let query = components.queryItems,
      let codeParam = query.first(where: { $0.name == "code" }),
      let code = codeParam.value
      else { return false }

    var params: [URLQueryItem] = []
    params.append(URLQueryItem(name: "code", value: code))
    params.append(URLQueryItem(name: "client_secret", value: clientSecret))
    params.append(URLQueryItem(name: "client_id", value: clientId))

    var requestComponents = URLComponents()
    requestComponents.queryItems = params

    let requestQuery = requestComponents.query!
    let requestBody = requestQuery.data(using: .utf8)!

    var request = URLRequest(url: createAccessTokenURL)
    request.httpBody = requestBody
    request.httpMethod = "POST"

    let task = URLSession.shared.dataTask(with: request) { [weak self, completionHandler = authorization.completionHandler] data, response, error in
      self?.handleAuthorizationResponse(data, response, error, completionHandler: completionHandler)
    }

    task.resume()

    currentAuthorization = nil
    authorization.safariViewController.dismiss(animated: true)

    return true
  }

  private func handleAuthorizationResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    defer { currentAuthorization = nil }

    var result: AuthenticationResult<String>!

    defer {
      completionHandler(result)
    }

    guard error == nil else {
      result = .failed(GitHubAuthError.createAccessTokenFailed(error!))
      return
    }

    let response = data.flatMap { String(data: $0, encoding: .utf8) }

    var components = URLComponents()
    components.query = response

    guard let token = components.queryItems?.first(where: { $0.name == "access_token" })?.value else {
      result = .failed(GitHubAuthError.tokenResponseInvalid(response ?? data))
      return
    }

    result = .authenticated(token)
  }
}

private extension GitHubOAuthProvider {
  final class SafariViewControllerDelegate: NSObject, SFSafariViewControllerDelegate {
    private let completionHandler: () -> Void

    init(completionHandler: @escaping () -> Void) {
      self.completionHandler = completionHandler
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
      completionHandler()
    }
  }
}

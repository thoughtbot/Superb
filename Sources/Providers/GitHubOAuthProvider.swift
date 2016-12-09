import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize")!
let createAccessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

final class GitHubOAuthProvider: FinchProvider {
  static let identifier = "com.thoughtbot.finch.github.oauth"

  let clientId: String
  let clientSecret: String
  let redirectURI: URL

  private var currentAuthorization: (
    safariViewController: SFSafariViewController,
    completionHandler: (Result<String>) -> Void
  )?

  init(clientId: String, clientSecret: String, redirectURI: URL) {
    self.clientId = clientId
    self.clientSecret = clientSecret
    self.redirectURI = redirectURI
  }

  func authorizationHeader(forToken token: String) -> String {
    return "token \(token)"
  }

  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<String>) -> Void) {
    precondition(currentAuthorization == nil)

    var authorizeURLComponents = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
    authorizeURLComponents.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
    ]

    let safariViewController = SFSafariViewController(url: authorizeURLComponents.url!)
    currentAuthorization = (safariViewController, completionHandler)
    viewController.present(safariViewController, animated: true)
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

    authorization.safariViewController.dismiss(animated: true)
    currentAuthorization = nil

    return true
  }

  private func handleAuthorizationResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?, completionHandler: @escaping (Result<String>) -> Void) {
    defer { currentAuthorization = nil }

    var result: Result<String>!

    defer {
      completionHandler(result)
    }

    guard error == nil else {
      result = .failure(error!)
      return
    }

    let response = data.flatMap { String(data: $0, encoding: .utf8) }

    var components = URLComponents()
    components.query = response

    guard let token = components.queryItems?.first(where: { $0.name == "access_token" })?.value else {
      result = .failure(FinchError.authorizationResponseInvalid)
      return
    }

    result = .success(token)
  }
}

import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize?client_id=3127cd33caef9514cbc5&redirect_uri=finchui%3A%2F%2Foauth%2Fgithub%2Fcode")!
let createAccessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

final class GitHubOAuthProvider: FinchProvider {
  static let identifier = "com.thoughtbot.finch.github.oauth"

  private var currentAuthorization: (
    safariViewController: SFSafariViewController,
    completionHandler: (String?) -> Void
  )?

  func authorize(over viewController: UIViewController, completionHandler: @escaping (String?) -> Void) {
    precondition(currentAuthorization == nil)

    let safariViewController = SFSafariViewController(url: authorizeURL)
    currentAuthorization = (safariViewController, completionHandler)
    viewController.present(safariViewController, animated: true)
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let query = components.queryItems,
      let codeParam = query.first(where: { $0.name == "code" }),
      let code = codeParam.value
      else { return false }

    var params: [URLQueryItem] = []
    params.append(URLQueryItem(name: "code", value: code))
    params.append(URLQueryItem(name: "client_secret", value: "b9d69d245ca6f952b50c77a543dca4f4c612ff73"))
    params.append(URLQueryItem(name: "client_id", value: "3127cd33caef9514cbc5"))

    var requestComponents = URLComponents()
    requestComponents.queryItems = params

    let requestQuery = requestComponents.query!
    let requestBody = requestQuery.data(using: .utf8)!

    var request = URLRequest(url: createAccessTokenURL)
    request.httpBody = requestBody
    request.httpMethod = "POST"

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let `self` = self, let authorization = self.currentAuthorization else { return }

      defer { self.currentAuthorization = nil }

      var tokenResult: String?

      defer {
        DispatchQueue.main.async { [authorization] in
          authorization.safariViewController.dismiss(animated: true) {
            authorization.completionHandler(tokenResult)
          }
        }
      }

      guard error == nil else {
        return
      }

      let response = data.flatMap { String(data: $0, encoding: .utf8) }

      var components = URLComponents()
      components.query = response

      guard let token = components.queryItems?.first(where: { $0.name == "access_token" })?.value else {
        return
      }

      tokenResult = token
    }

    task.resume()

    return true
  }
}

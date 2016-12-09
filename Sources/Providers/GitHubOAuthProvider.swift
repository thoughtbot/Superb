import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize?client_id=3127cd33caef9514cbc5&redirect_uri=finchui%3A%2F%2Foauth%2Fgithub%2Fcode")!

final class GitHubOAuthProvider: FinchProvider {
  static let identifier = "com.thoughtbot.finch.github.oauth"

  func authorize(over viewController: UIViewController) {
    let safariViewController = SFSafariViewController(url: authorizeURL)
    viewController.present(safariViewController, animated: true)
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let query = components.queryItems,
      let codeParam = query.first(where: { $0.name == "code" }),
      let code = codeParam.value
      else { return false }
    print("received code", code)
    return true
  }
}

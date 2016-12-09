import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize?client_id=3127cd33caef9514cbc5&redirect_uri=finchui%3A%2F%2Foauth%2Fgithub%2Fcode")!

final class GitHubOAuthViewController: UIViewController {
  @IBAction func authorize(_ sender: Any?) {
    let safariViewController = SFSafariViewController(url: authorizeURL)
    present(safariViewController, animated: true)
  }
}

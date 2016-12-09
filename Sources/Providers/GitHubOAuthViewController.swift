import UIKit

final class GitHubOAuthViewController: UIViewController {
  @IBAction func authorize(_ sender: Any?) {
    AppDelegate.gitHubProvider.authorize(over: self)
  }
}

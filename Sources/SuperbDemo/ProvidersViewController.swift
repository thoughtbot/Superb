import UIKit

final class ProvidersViewController: UITableViewController {
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let profileViewController = segue.destination.childViewControllers.first! as! ProfileViewController

    switch segue.identifier {
    case "GitHub: Web Application Flow"?:
      profileViewController.api = GitHubAPIClient.oauthClient

    case "GitHub: Non-Web Application Flow"?:
      profileViewController.api = GitHubAPIClient.basicAuthClient

    case "Twitter: Web Application Flow"?:
      profileViewController.api = TwitterAPIClient.oauthClient

    case let identifier:
      fatalError("unknown segue '\(identifier ?? "")'")
    }
  }

  @IBAction func unwindToProviders(_ segue: UIStoryboardSegue) {
  }
}

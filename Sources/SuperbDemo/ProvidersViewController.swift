import UIKit

final class ProvidersViewController: UITableViewController {
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let profileViewController = segue.destination.childViewControllers.first! as! GitHubProfileViewController

    switch segue.identifier {
    case "Web Application Flow"?:
      profileViewController.api = GitHubAPIClient.oauthClient
    case "Non-Web Application Flow"?:
      profileViewController.api = GitHubAPIClient.basicAuthClient
    case let identifier:
      fatalError("unknown segue '\(identifier ?? "")'")
    }
  }

  @IBAction func unwindToProviders(_ segue: UIStoryboardSegue) {
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let identifier = tableView.cellForRow(at: indexPath)?.textLabel?.text else { return }
    performSegue(withIdentifier: identifier, sender: nil)
  }
}

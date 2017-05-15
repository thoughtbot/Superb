import UIKit

final class ProvidersViewController: UITableViewController {
  @IBAction func unwindToProviders(_ segue: UIStoryboardSegue) {
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let identifier = tableView.cellForRow(at: indexPath)?.textLabel?.text else { return }
    performSegue(withIdentifier: identifier, sender: nil)
  }
}

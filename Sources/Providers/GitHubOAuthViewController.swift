import UIKit

final class GitHubOAuthViewController: UIViewController {
  @IBAction func authorize(_ sender: Any?) {
    AppDelegate.gitHubProvider.authorize(over: self) { [weak self] token in
      guard let `self` = self else { return }

      let alert: UIAlertController

      if let token = token {
        print("authorized with token ", token)

        alert = UIAlertController(title: "Authorized!", message: "Token: \(token)", preferredStyle: .alert)

        let dismiss = UIAlertAction(title: "OK", style: .default) { _ in
          self.performSegue(withIdentifier: "unwindToProviders", sender: self)
        }
        alert.addAction(dismiss)
      } else {
        alert = UIAlertController(title: "Authorization Failed", message: "😢", preferredStyle: .alert)

        let confirm = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(confirm)
      }

      self.present(alert, animated: true)
    }
  }
}

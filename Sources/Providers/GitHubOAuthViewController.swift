import UIKit

final class GitHubOAuthViewController: UIViewController {
  @IBAction func getUser(_ sender: Any?) {
    let userRequest = URLRequest(url: URL(string: "https://api.github.com/user")!)

    AppDelegate.gitHubRequestAuthorizer.performAuthorized(userRequest) { result in
      switch result {
      case let .success(data?, response?):
        print(data, response)
      case let .success(data, response):
        print(data, response)
      case let .failure(error):
        print(error)
      }
    }
  }

  @IBAction func authorize(_ sender: Any?) {
    AppDelegate.gitHubProvider.authorize(over: self) { [weak self] result in
      guard let `self` = self else { return }

      let alert: UIAlertController

      switch result {
      case let .success(token):
        print("authorized with token ", token)

        alert = UIAlertController(title: "Authorized!", message: "Token: \(token)", preferredStyle: .alert)

        let dismiss = UIAlertAction(title: "OK", style: .default) { _ in
          self.performSegue(withIdentifier: "unwindToProviders", sender: self)
        }
        alert.addAction(dismiss)
      case let .failure(error):
        alert = UIAlertController(title: "Authorization Failed", message: error.localizedDescription, preferredStyle: .alert)

        let confirm = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(confirm)
      }

      self.present(alert, animated: true)
    }
  }
}

import UIKit

final class GitHubOAuthViewController: UIViewController {
  @IBOutlet var activityIndicator: UIActivityIndicatorView!
  @IBOutlet var userContainer: UIView!
  @IBOutlet var userNameLabel: UILabel!

  private var userRequest: URLRequest? = URLRequest(url: URL(string: "https://api.github.com/user")!)

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    activityIndicator.startAnimating()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    getUser(nil)
  }

  @IBAction func getUser(_ sender: Any?) {
    guard let userRequest = userRequest else { return }

    defer { self.userRequest = nil }

    AppDelegate.gitHubRequestAuthorizer.performAuthorized(userRequest) { result in
      switch result {
      case let .success(data?, response?):
        if let object = try? JSONSerialization.jsonObject(with: data) {
          DispatchQueue.main.async {
            self.showUser(object)
          }
        }
      case let .success(data, response):
        print(response ?? "<no response>")
        if let description = data.flatMap({ String(data: $0, encoding: .utf8) }) {
          print(description)
        } else {
          print(data ?? "<no data>")
        }
      case let .failure(error):
        print(error)
      }
    }
  }

  private func showUser(_ object: Any) {
    userContainer.alpha = 0
    userContainer.isHidden = false

    let user = object as? [String: Any]
    userNameLabel.text = user?["login"] as? String

    UIView.animate(withDuration: 0.3) {
      self.activityIndicator.alpha = 0
      self.userContainer.alpha = 1
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

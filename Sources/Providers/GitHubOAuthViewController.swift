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

    AppDelegate.gitHubOAuthRequestAuthorizer.performAuthorized(userRequest) { result in
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
}

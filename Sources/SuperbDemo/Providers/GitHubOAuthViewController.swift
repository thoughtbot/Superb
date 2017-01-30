import Superb
import UIKit

final class GitHubOAuthViewController: UIViewController {
  @IBOutlet var activityIndicator: UIActivityIndicatorView!
  @IBOutlet var userContainer: UIView!
  @IBOutlet var userNameLabel: UILabel!

  private var viewHasAppeared = false

  let api = GitHubAPIClient.oauthClient

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    activityIndicator.startAnimating()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !viewHasAppeared {
      getUser(nil)
    }

    viewHasAppeared = true
  }

  @IBAction func getUser(_ sender: Any?) {
    api.getLogin { result in
      if let error = result.error {
        print("error:", error)
      }

      self.showUser(result.value)
    }
  }

  private func showUser(_ login: String?) {
    userContainer.alpha = 0
    userContainer.isHidden = false

    userNameLabel.text = login

    UIView.animate(withDuration: 0.3) {
      self.activityIndicator.alpha = 0
      self.userContainer.alpha = 1
    }
  }
}

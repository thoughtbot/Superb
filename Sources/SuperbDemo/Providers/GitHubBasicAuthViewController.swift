import UIKit

final class GitHubBasicAuthViewController: UIViewController {
  @IBOutlet var activityIndicator: UIActivityIndicatorView!
  @IBOutlet var userContainer: UIView!
  @IBOutlet var userImageView: UIImageView!
  @IBOutlet var userLoginLabel: UILabel!
  @IBOutlet var userNameLabel: UILabel!

  private var viewHasAppeared = false

  let api = GitHubAPIClient.basicAuthClient

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
    api.getProfile { result in
      if let error = result.error?.error {
        print("error:", error)
      }

      self.showProfile(result.value)
    }
  }

  private func showProfile(_ profile: Profile?) {
    userContainer.alpha = 0
    userContainer.isHidden = false

    userLoginLabel.text = profile?.login
    userNameLabel.text = profile?.name

    if let avatar = profile?.avatar {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let data = try? Data(contentsOf: avatar) else { return }
        let image = UIImage(data: data)
        DispatchQueue.main.async {
          self?.userImageView?.image = image
        }
      }
    }

    UIView.animate(withDuration: 0.3) {
      self.activityIndicator.alpha = 0
      self.userContainer.alpha = 1
    }
  }
}

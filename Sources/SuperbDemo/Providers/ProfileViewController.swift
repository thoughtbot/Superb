import Superb
import UIKit

final class ProfileViewController: UIViewController {
  @IBOutlet var activityIndicator: UIActivityIndicatorView!
  @IBOutlet var userContainer: UIView!
  @IBOutlet var userImageView: UIImageView!
  @IBOutlet var userLoginLabel: UILabel!
  @IBOutlet var userNameLabel: UILabel!

  private var viewHasAppeared = false

  var api: APIClient?

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
    api!.getProfile { result in
      switch result {
      case let .success(profile):
        self.showProfile(profile)

      case let .failure(error):
        print("error:", error)
      }
    }
  }

  private func showProfile(_ profile: Profile) {
    userContainer.alpha = 0
    userContainer.isHidden = false

    userLoginLabel.text = profile.login
    userNameLabel.text = profile.name

    if let avatar = profile.avatar {
      URLSession.api.dataTask(with: avatar) { [weak self] data, _, _ in
        guard let data = data else { return }
        let image = UIImage(data: data)
        DispatchQueue.main.async {
          guard let `self` = self else { return }
          UIView.animate(withDuration: 0.3) {
            self.userImageView?.image = image
          }
        }
      }.resume()
    }

    UIView.animate(withDuration: 0.3) {
      self.activityIndicator.alpha = 0
      self.userContainer.alpha = 1
    }
  }
}

import UIKit

final class GitHubBasicAuthProvider : FinchProvider {
  static let identifier = "com.thoughtbot.finch.github.basic"

  private var login = ""
  private var password = ""

  func authorizationHeader(forToken token: String) -> String {
    return "token \(token)"
  }

  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<String>) -> Void) {
    let alert = UIAlertController(title: "Sign in to GitHub", message: nil, preferredStyle: .alert)

    alert.addTextField { textField in
      textField.addTarget(self, action: #selector(self.loginChanged), for: .editingDidEnd)
      textField.placeholder = "Login"
    }

    alert.addTextField { textField in
      textField.addTarget(self, action: #selector(self.passwordChanged), for: .editingDidEnd)
      textField.placeholder = "Password"
      textField.isSecureTextEntry = true
    }

    let submit = UIAlertAction(title: "OK", style: .default) { _ in
      print(self.login)
      print(self.password)
    }
    alert.addAction(submit)

    let cancel = UIAlertAction(title: "Cancel", style: .cancel)
    alert.addAction(cancel)

    viewController.present(alert, animated: true)
  }

  @objc func loginChanged(_ sender: UITextField) {
    login = sender.text ?? ""
  }

  @objc func passwordChanged(_ sender: UITextField) {
    password = sender.text ?? ""
  }
}

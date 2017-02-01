import Superb
import UIKit

let createPersonalAccessTokenURL = URL(string: "https://api.github.com/authorizations")!

final class GitHubBasicAuthProvider: AuthenticationProvider {
  static let identifier = "com.thoughtbot.superb.github.basic"
  static let keychainServiceName = "GitHub Personal Access Token"

  private var login = ""
  private var password = ""

  func authorize(_ request: inout URLRequest, with token: String) {
    request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
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
      self.createAccessToken(login: self.login, password: self.password, completionHandler: completionHandler)
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

  private func createAccessToken(login: String, password: String, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    let requestBody = try? JSONSerialization.data(withJSONObject: [
      "note": makePersonalAccessTokenNote()
    ])

    var request = URLRequest(url: createPersonalAccessTokenURL)
    request.httpBody = requestBody
    request.httpMethod = "POST"
    request.setValue(createAuthorizationHeader(login: login, password: password), forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      var result: AuthenticationResult<String>!

      defer {
        completionHandler(result)
      }

      guard error == nil else {
        result = .failed(error!)
        return
      }

      let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }

      guard let response = object as? [String: Any],
        let token = response["token"] as? String
        else {
          result = .failed(GitHubAuthError.tokenResponseInvalid(object ?? data))
          return
        }

      result = .authenticated(token)
    }

    task.resume()
  }

  private func makePersonalAccessTokenNote() -> String {
    let date = iso8601Formatter.string(from: Date())

    return "Superb GitHub Basic Auth Sign In \(date)"
  }

  private func createAuthorizationHeader(login: String, password: String) -> String {
    let rawValue = "\(login):\(password)".data(using: .utf8)!
    return "Basic \(rawValue.base64EncodedString())"
  }

  private let iso8601Formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    return formatter
  }()
}

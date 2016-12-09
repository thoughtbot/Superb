import UIKit

let createPersonalAccessTokenURL = URL(string: "https://api.github.com/authorizations")!

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

  private func createAccessToken(login: String, password: String, completionHandler: @escaping (Result<String>) -> Void) {

    let requestBody = try? JSONSerialization.data(withJSONObject: [
      "note": makePersonalAccessTokenNote()
    ])

    var request = URLRequest(url: createPersonalAccessTokenURL)
    request.httpBody = requestBody
    request.httpMethod = "POST"
    request.setValue(createAuthorizationHeader(login: login, password: password), forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      var result: Result<String>!

      defer {
        DispatchQueue.main.async {
          completionHandler(result)
        }
      }

      guard error == nil else {
        result = .failure(error!)
        return
      }

      guard let data = data,
        let object = try? JSONSerialization.jsonObject(with: data),
        let response = object as? [String: Any],
        let token = response["token"] as? String
        else {
          result = .failure(FinchError.authorizationResponseInvalid)
          return
        }

      result = .success(token)
    }

    task.resume()
  }

  private func makePersonalAccessTokenNote() -> String {
    let date = iso8601Formatter.string(from: Date())

    return "Finch GitHub Basic Auth Sign In \(date)"
  }

  private func createAuthorizationHeader(login: String, password: String) -> String {
    let rawValue = "\(login):\(password)".data(using: .utf8)!
    return "Basic \(rawValue.base64EncodedString())"
  }

  private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .autoupdatingCurrent
    return formatter
  }()
}

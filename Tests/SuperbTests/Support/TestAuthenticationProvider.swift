@testable import Superb
import Result
import UIKit

final class TestAuthenticationProvider: AuthenticationProvider {
  static let identifier = "test-provider"
  static let keychainServiceName = "Test Authentication Provider"

  private var completionHandler: ((AuthenticationResult<String>) -> Void)?

  private let authenticationLock = ConditionLock(label: "test-provider.authentication-lock", condition: AuthenticationCondition.ready)
  private let queue = DispatchQueue(label: "test-provider.queue")

  func authorize(_ request: inout URLRequest, with token: String) {
    request.setValue(token, forHTTPHeaderField: "Authorization")
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<String>) -> Void) {
    authenticationLock.lock(when: .ready)
    self.completionHandler = completionHandler
    authenticationLock.unlock(with: .authenticating)
  }

  func complete(with result: AuthenticationResult<String>) {
    queue.async { [authenticationLock] in
      authenticationLock.lock(when: .authenticating)
      guard let completionHandler = self.completionHandler else {
        preconditionFailure("expected completion handler to be set when authenticating")
      }
      self.completionHandler = nil
      authenticationLock.unlock(with: .ready)
      completionHandler(result)
    }
  }
}

private enum AuthenticationCondition: Int {
  case ready
  case authenticating
}

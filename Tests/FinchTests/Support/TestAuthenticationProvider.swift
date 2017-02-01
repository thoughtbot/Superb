@testable import Finch
import Result
import UIKit

final class TestAuthenticationProvider: AuthenticationProvider {
  static let identifier = "test-provider"
  static let keychainServiceName = "Test Finch Provider"

  private var completionHandler: ((Result<String, FinchError>) -> Void)?

  private let authenticationLock = ConditionLock(label: "test-provider.authentication-lock", condition: AuthenticationCondition.ready)
  private let queue = DispatchQueue(label: "test-provider.queue")

  func authorizationHeader(for token: String) -> String {
    return token
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (Result<String, FinchError>) -> Void) {
    authenticationLock.lock(when: .ready)
    self.completionHandler = completionHandler
    authenticationLock.unlock(with: .authenticating)
  }

  func complete(with token: String) {
    complete(with: .success(token))
  }

  func complete(with error: FinchError) {
    complete(with: .failure(error))
  }

  private func complete(with result: Result<String, FinchError>) {
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

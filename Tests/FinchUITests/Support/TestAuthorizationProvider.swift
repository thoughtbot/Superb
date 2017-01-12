@testable import FinchUI
import Result
import UIKit

final class TestAuthorizationProvider: FinchProvider {
  static let identifier = "test-provider"

  func authorizationHeader(for token: String) -> String {
    return token
  }

  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<String, FinchError>) -> Void) {
  }
}

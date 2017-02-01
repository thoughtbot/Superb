import Result
import UIKit

public protocol _CallbackHandler {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

public protocol _AuthenticationProvider: _CallbackHandler {
  associatedtype Token

  func authorizationHeader(for token: Token) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void)
}

public protocol AuthenticationProvider: _AuthenticationProvider {
  static var identifier: String { get }
  static var keychainServiceName: String { get }
}

extension AuthenticationProvider {
  public func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

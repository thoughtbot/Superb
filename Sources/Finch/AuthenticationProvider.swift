import Result
import UIKit

public protocol CallbackHandler {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

public protocol _AuthenticationProvider {
  associatedtype Token

  func authorizationHeader(for token: Token) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void)
}

public protocol AuthenticationProvider: _AuthenticationProvider, CallbackHandler {
  static var identifier: String { get }
  static var keychainServiceName: String { get }
}

extension AuthenticationProvider {
  public func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

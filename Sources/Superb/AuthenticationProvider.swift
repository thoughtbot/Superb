import UIKit

public protocol CallbackHandler {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

public protocol _AuthenticationProvider {
  associatedtype Token

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<Token>) -> Void)
  func authorize(_ request: inout URLRequest, with token: Token)
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

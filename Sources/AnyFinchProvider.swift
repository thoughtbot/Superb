import Result
import UIKit

internal final class AnyFinchProvider<Token>: _FinchProvider {
  let identifier: String
  private let _authorizationHeader: (Token) -> String
  private let _authorize: (UIViewController, @escaping (Result<Token, FinchError>) -> Void) -> Void
  private let _handleCallback: (URL, [UIApplicationOpenURLOptionsKey: Any]) -> Bool

  init<Base: FinchProvider>(_ provider: Base) where Base.Token == Token {
    identifier = Base.identifier
    _authorizationHeader = { provider.authorizationHeader(for: $0) }
    _authorize = { provider.authorize(over: $0, completionHandler: $1) }
    _handleCallback = { provider.handleCallback($0, options: $1) }
  }

  func authorizationHeader(for token: Token) -> String {
    return _authorizationHeader(token)
  }

  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void) {
    return _authorize(viewController, completionHandler)
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return _handleCallback(url, options)
  }
}

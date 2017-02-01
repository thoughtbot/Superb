import Result
import UIKit

internal final class AnyAuthenticationProvider<Token>: _AuthenticationProvider {
  let identifier: String
  private let _authorizationHeader: (Token) -> String
  private let _authenticate: (UIViewController, @escaping (Result<Token, FinchError>) -> Void) -> Void

  init<Base: AuthenticationProvider>(_ provider: Base) where Base.Token == Token {
    identifier = Base.identifier
    _authorizationHeader = { provider.authorizationHeader(for: $0) }
    _authenticate = { provider.authenticate(over: $0, completionHandler: $1) }
  }

  func authorizationHeader(for token: Token) -> String {
    return _authorizationHeader(token)
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void) {
    return _authenticate(viewController, completionHandler)
  }
}

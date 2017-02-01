import Result
import UIKit

internal final class AnyAuthenticationProvider<Token>: _AuthenticationProvider {
  let identifier: String
  private let _authenticate: (UIViewController, @escaping (AuthenticationResult<Token>) -> Void) -> Void
  private let _authorize: (inout URLRequest, Token) -> Void

  init<Base: AuthenticationProvider>(_ provider: Base) where Base.Token == Token {
    identifier = Base.identifier
    _authenticate = { provider.authenticate(over: $0, completionHandler: $1) }
    _authorize = { provider.authorize(&$0, with: $1) }
  }

  func authenticate(over viewController: UIViewController, completionHandler: @escaping (AuthenticationResult<Token>) -> Void) {
    return _authenticate(viewController, completionHandler)
  }

  func authorize(_ request: inout URLRequest, with token: Token) {
    _authorize(&request, token)
  }
}

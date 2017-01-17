import Result
import UIKit

enum Finch {
  private static var providers: [String: Any] = [:]

  static func register<Provider: FinchProvider>(_ makeProvider: @autoclosure () -> Provider) -> Provider {
    return register { makeProvider() }
  }

  static func register<Provider: FinchProvider>(makeProvider: () -> Provider) -> Provider {
    let id = Provider.identifier

    if let instance = providers[id] {
      return instance as! Provider
    } else {
      let instance = makeProvider()
      providers[id] = instance
      return instance
    }
  }

  static func handleAuthenticationRedirect(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    for (_, provider) in providers {
      let handler = provider as! _CallbackHandler
      if handler.handleCallback(url, options: options) {
        return true
      }
    }

    return false
  }
}

protocol _CallbackHandler {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

protocol _FinchProvider: _CallbackHandler {
  associatedtype Token

  func authorizationHeader(for token: Token) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void)
}

protocol FinchProvider: _FinchProvider {
  static var identifier: String { get }
  static var keychainServiceName: String { get }
}

extension FinchProvider {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

import Result
import UIKit

public enum Finch {
  private static var providers: [String: Any] = [:]

  public static func register<Provider: FinchProvider>(_ makeProvider: @autoclosure () -> Provider) -> Provider {
    return register { makeProvider() }
  }

  public static func register<Provider: FinchProvider>(makeProvider: () -> Provider) -> Provider {
    let id = Provider.identifier

    if let instance = providers[id] {
      return instance as! Provider
    } else {
      let instance = makeProvider()
      providers[id] = instance
      return instance
    }
  }

  public static func handleAuthenticationRedirect(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    for (_, provider) in providers {
      let handler = provider as! _CallbackHandler
      if handler.handleCallback(url, options: options) {
        return true
      }
    }

    return false
  }
}

public protocol _CallbackHandler {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

public protocol _FinchProvider: _CallbackHandler {
  associatedtype Token

  func authorizationHeader(for token: Token) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<Token, FinchError>) -> Void)
}

public protocol FinchProvider: _FinchProvider {
  static var identifier: String { get }
  static var keychainServiceName: String { get }
}

extension FinchProvider {
  public func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

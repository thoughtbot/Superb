import UIKit

enum Finch {
  private static var providers: [String: FinchProvider] = [:]

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
      if provider.handleCallback(url, options: options) {
        return true
      }
    }

    return false
  }
}

protocol FinchProvider {
  static var identifier: String { get }

  func authorizationHeader(forToken token: String) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<String>) -> Void)
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
}

extension FinchProvider {
  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return false
  }
}

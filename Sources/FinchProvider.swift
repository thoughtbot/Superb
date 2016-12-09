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
}

protocol FinchProvider {
  static var identifier: String { get }

  func authorizationHeader(forToken token: String) -> String
  func authorize(over viewController: UIViewController, completionHandler: @escaping (Result<String>) -> Void)
}

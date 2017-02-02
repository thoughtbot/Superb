import UIKit

public enum Superb {
  private static var providers: [String: Any] = [:]

  public static func register<Provider: AuthenticationProvider>(_ makeProvider: @autoclosure () -> Provider) -> Provider {
    return register { makeProvider() }
  }

  public static func register<Provider: AuthenticationProvider>(makeProvider: () -> Provider) -> Provider {
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
      let handler = provider as! CallbackHandler
      if handler.handleCallback(url, options: options) {
        return true
      }
    }

    return false
  }
}

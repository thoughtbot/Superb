import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let query = components.queryItems,
      let codeParam = query.first(where: { $0.name == "code" }),
      let code = codeParam.value
      else { return false }
    print("received code", code)
    return true
  }
}

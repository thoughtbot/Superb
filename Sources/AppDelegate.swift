import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  static var gitHubProvider: GitHubOAuthProvider {
    return Finch.register(
      GitHubOAuthProvider(
        clientId: "3127cd33caef9514cbc5",
        clientSecret: "b9d69d245ca6f952b50c77a543dca4f4c612ff73",
        redirectURI: URL(string: "finchui://oauth/github/code")!
      )
    )
  }

  static let gitHubRequestAuthorizer: RequestAuthorizer = {
    return RequestAuthorizer(
      applicationDelegate: UIApplication.shared.delegate!,
      authorizationProvider: gitHubProvider
    )
  }()

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    return true
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return AppDelegate.gitHubProvider.handleCallback(url, options: options)
  }
}

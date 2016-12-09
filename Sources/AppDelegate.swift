import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  static var gitHubOAuthProvider: GitHubOAuthProvider {
    return Finch.register(
      GitHubOAuthProvider(
        clientId: "3127cd33caef9514cbc5",
        clientSecret: "b9d69d245ca6f952b50c77a543dca4f4c612ff73",
        redirectURI: URL(string: "finchui://oauth/github/code")!
      )
    )
  }

  static let gitHubOAuthRequestAuthorizer: RequestAuthorizer = {
    return RequestAuthorizer(
      applicationDelegate: UIApplication.shared.delegate!,
      authorizationProvider: gitHubOAuthProvider
    )
  }()

  static var gitHubBasicAuthProvider: GitHubBasicAuthProvider {
    return Finch.register(
      GitHubBasicAuthProvider()
    )
  }

  static let gitHubBasicAuthRequestAuthorizer: RequestAuthorizer = {
    return RequestAuthorizer(
      applicationDelegate: UIApplication.shared.delegate!,
      authorizationProvider: gitHubBasicAuthProvider
    )
  }()

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    return Finch.handleAuthenticationRedirect(url, options: options)
  }
}

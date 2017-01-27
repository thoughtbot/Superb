# Finch

Pluggable HTTP authentication for Swift.

**Advantages**

- Safe, **secure token storage** in the iOS Keychain.
- Automatic handling of 401 responses and **reauthentication**.
- Scales to handle many concurrent requests in a **thread-safe** way.
- Stays out of your way until you need it with a simple, **minimal API**.
- Promotes Apple's [Authentication Guidelines][hig] by "delaying sign-in as long as possible".
- Supports **adapters** for any number of authentication providers.
- **Extensible** without requiring any source modifications or pull requests.

**Caveats**

- *Opinionated* about user experience.

[hig]: https://developer.apple.com/ios/human-interface-guidelines/interaction/authentication/

## Usage

### Example: GitHub OAuth Authentication

When you register the app with your OAuth provider, you will give a redirect
URI. This URI must use a URL scheme that is registered for your app in your
app's `Info.plist`.

Finch allows your app to support multiple authentication providers via a
registration mechanism. iOS apps have a single entrypoint for URLs, so Finch
searches through the registered providers to find the correct one to handle the
redirect URL.

```swift
// AppDelegate.swift

import Finch
import FinchGitHub
import UIKit

extension AppDelegate {
  static let gitHubRequestAuthorizer: RequestAuthorizer = {
    // Create a Finch RequestAuthorizer for GitHub OAuth
    return RequestAuthorizer(
      // Register a provider to handle callback URLs, such as with OAuth
      authenticationProvider: Finch.register(
        GitHubOAuthProvider(
          clientId: "<your client id>",
          clientSecret: "<your client secret>",
          redirectURI: URL(string: "<your chosen redirect URI>")!
        )
      )
    )
  }()

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    // Pass the URL and options off to Finch.
    return Finch.handleAuthenticationRedirect(url, options: options)
  }
}
```

Then, in our controller, we can use the `RequestAuthorizer` set up in the
`AppDelegate` to fence the code that must be run with authentication, using
`RequestAuthorizer.performAuthorized()`.

```swift
// GitHubProfileController.swift

// A simple controller for showing a user their GitHub profile.
final class GitHubProfileController {
  // Get the RequestAuthorizer singleton.
  let authorizer = AppDelegate.gitHubRequestAuthorizer

  func loadProfile() {
    // Prepare the request against the GitHub API.
    let request = URLRequest(url: URL(string: "https://api.github.com/user")!)

    // Here we are (potentially) unauthenticated.
    // The RequestAuthorizer will automatically authenticate the first time,
    // or reauthenticate if the stored token is stale.
    authorizer.performAuthorized(request) { result in
      switch result {
      case let .success(data, response):
        // Here we are authenticated and have a response from the API,
        // so we can parse the response data.

      case let .failure(error):
        // Authentication failed, the HTTP response was an error, etc.
        print(error)
      }
    }
  }
}
```

## Installation

### [Carthage][]

[Carthage]: https://github.com/Carthage/Carthage

Add the following to your Cartfile:

```
github "thoughtbot/Finch" ~> 0.1
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

You will need to embed both `Finch.framework` and `Result.framework` in your
application.

[carthage-installation]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application

## Troubleshooting

### Authentication always fails when using OAuth

#### You forgot to call `Finch.register`.

If you do not call `Finch.register` then your authentication provider will not
have a chance to receive callback URLs.

## Contributing

See the [CONTRIBUTING] document. Thank you, [contributors]!

[CONTRIBUTING]: CONTRIBUTING.md
[contributors]: https://github.com/thoughtbot/Finch/graphs/contributors

## License

Finch is Copyright (c) 2017 thoughtbot, inc. It is free software, and may be
redistributed under the terms specified in the [LICENSE] file.

[LICENSE]: /LICENSE

## About

![thoughtbot](https://thoughtbot.com/logo.png)

Finch is maintained and funded by thoughtbot, inc. The names and logos for
thoughtbot are trademarks of thoughtbot, inc.

We love open source software! See [our other projects][community] or look at
our product [case studies] and [hire us][hire] to help build your iOS app.

[community]: https://thoughtbot.com/community?utm_source=github
[case studies]: https://thoughtbot.com/work?utm_source=github
[hire]: https://thoughtbot.com/hire-us?utm_source=github

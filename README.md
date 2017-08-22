# Superb [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

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

Superb allows your app to support multiple authentication providers via a
registration mechanism. iOS apps have a single entrypoint for URLs, so Superb
searches through the registered providers to find the correct one to handle the
redirect URL.

```swift
// GitHub+Providers.swift

import Superb
import SuperbGitHub

extension GitHubOAuthProvider {
  static var shared: GitHubOAuthProvider {
    // Register a provider to handle callback URLs
    return Superb.register(
      GitHubOAuthProvider(
        clientId: "<your client id>",
        clientSecret: "<your client secret>",
        redirectURI: URL(string: "<your chosen redirect URI>")!
      )
    )
  }
}
```

```swift
// AppDelegate.swift

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  // ...

  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    // Pass the URL and options off to Superb.
    return Superb.handleAuthenticationRedirect(url, options: options)
  }
}
```

Then, in our API client, we can use `RequestAuthorizer` to fence the code that
must be run with authentication, using `RequestAuthorizer.performAuthorized()`.

```swift
// GitHubAPIClient.swift

struct GitHubAPIClient {
  static let oauthClient = GitHubAPIClient(
    requestAuthorizer: RequestAuthorizer(
      authorizationProvider: GitHubOAuthProvider.shared
    )
  )

  private let authorizer: RequestAuthorizerProtocol

  init(requestAuthorizer: RequestAuthorizerProtocol) {
    authorizer = requestAuthorizer
  }

  // An authorized request to get the current user's profile.
  func getProfile(completionHandler: @escaping (Result<Profile, SuperbError>) -> Void) {
    let request = URLRequest(url: URL(string: "https://api.github.com/user")!)

    authorizer.performAuthorized(request) { result in
      switch result {
      case let .success(data, _):
        let profile = parseProfile(from: data)
        completionHandler(.success(profile))

      case let .failure(error):
        completionHandler(.failure(error))
      }
    }
  }

  // An unauthorized request.
  func getZen(completionHandler: @escaping (Result<String, SuperbError>) -> Void) {
    let request = URLRequest(url: URL(string: "https://api.github.com/zen")!)

    URLSession.shared.dataTask(with: request) { data, _, error in
      let result = parseZen(data, error)
      completionHandler(result)
    }.resume()
  }
}

// later
let api = GitHubAPIClient.oauthClient

api.getProfile { result in
  // ...
}
```

## List of Authentication Providers

- [GitHub](https://github.com/thoughtbot/SuperbGitHub)

## Installation

### [Carthage][]

[Carthage]: https://github.com/Carthage/Carthage

Add the following to your Cartfile:

```
github "thoughtbot/Superb" ~> 0.2
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

You will need to embed both `Superb.framework` and `Result.framework` in your
application.

[carthage-installation]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application

### [CocoaPods][]

[CocoaPods]: https://cocoapods.org

Add the following to your [Podfile](https://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod "Superb", "~> 0.2.0"
```

You will also need to make sure you're opting into using frameworks:

```ruby
use_frameworks!
```

Then run `pod install`.

## Troubleshooting

### Authentication always fails when using OAuth

#### You forgot to call `Superb.register`.

If you do not call `Superb.register` then your authentication provider will not
have a chance to receive callback URLs.

## Contributing

See the [CONTRIBUTING] document. Thank you, [contributors]!

[CONTRIBUTING]: CONTRIBUTING.md
[contributors]: https://github.com/thoughtbot/Superb/graphs/contributors

## License

Superb is Copyright (c) 2017 thoughtbot, inc. It is free software, and may be
redistributed under the terms specified in the [LICENSE] file.

[LICENSE]: /LICENSE

## About

![thoughtbot](http://presskit.thoughtbot.com/images/thoughtbot-logo-for-readmes.svg)

Superb is maintained and funded by thoughtbot, inc. The names and logos for
thoughtbot are trademarks of thoughtbot, inc.

We love open source software! See [our other projects][community] or look at
our product [case studies] and [hire us][hire] to help build your iOS app.

[community]: https://thoughtbot.com/community?utm_source=github
[case studies]: https://thoughtbot.com/work?utm_source=github
[hire]: https://thoughtbot.com/hire-us?utm_source=github

import UIKit

public extension RequestAuthorizer {
  @available(*, unavailable, renamed: "init(authenticationProvider:tokenStorage:applicationDelegate:urlSession:)")
  convenience init<Provider: AuthenticationProvider, Storage: TokenStorage>(authorizationProvider: Provider, tokenStorage: Storage, applicationDelegate: @autoclosure @escaping () -> UIApplicationDelegate? = nil, urlSession: URLSession = .shared)
  where Provider.Token == Token, Storage.Token == Token {
    fatalError("unavailable")
  }
}

public extension RequestAuthorizer where Token: KeychainDecodable & KeychainEncodable {
  @available(*, unavailable, renamed: "init(authenticationProvider:applicationDelegate:urlSession:)")
  convenience init<Provider: AuthenticationProvider>(authorizationProvider: Provider, applicationDelegate: @autoclosure @escaping () -> UIApplicationDelegate? = nil, urlSession: URLSession = .shared)
  where Provider.Token == Token {
    fatalError("unavailable")
  }
}

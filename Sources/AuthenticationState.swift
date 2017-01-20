import Foundation

struct AuthenticationState<Token> {
  private var isAuthenticating = false
  private let storage: AnyTokenStorage<Token>

  static func makeActor<Storage: TokenStorage>(tokenStorage: Storage) -> Actor<AuthenticationState> where Storage.Token == Token {
    return Actor(AuthenticationState(tokenStorage: tokenStorage))
  }

  private init<Storage: TokenStorage>(tokenStorage: Storage) where Storage.Token == Token {
    storage = AnyTokenStorage(tokenStorage)
  }

  mutating func fetch(_ body: (_ state: CurrentAuthenticationState<Token>, _ startedAuthenticating: inout Bool) -> Void) throws {
    let state = try currentState()
    var startedAuthenticating = false

    body(state, &startedAuthenticating)

    if startedAuthenticating {
      isAuthenticating = true
    }
  }

  mutating func update(_ body: () -> NewAuthenticationState<Token>) throws {
    defer { isAuthenticating = false }

    let result = body()

    switch result {
    case let .authenticated(token):
      try storage.saveToken(token)
    case .unauthenticated:
      try storage.deleteToken()
    }
  }

  mutating func clearToken() throws {
    try storage.deleteToken()
  }

  private func currentState() throws -> CurrentAuthenticationState<Token> {
    guard !isAuthenticating else { return .authenticating }
    let token = try storage.fetchToken()
    return CurrentAuthenticationState(token: token)
  }
}

enum CurrentAuthenticationState<Token> {
  case unauthenticated
  case authenticating
  case authenticated(Token)
}

enum NewAuthenticationState<Token> {
  case unauthenticated
  case authenticated(Token)
}

private extension CurrentAuthenticationState {
  init(token: Token?) {
    if let token = token {
      self = .authenticated(token)
    } else {
      self = .unauthenticated
    }
  }

  var isAuthenticating: Bool {
    switch self {
    case .authenticating:
      return true
    case .unauthenticated, .authenticated:
      return false
    }
  }
}

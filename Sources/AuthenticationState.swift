import Foundation

final class AuthenticationState<Token> {
  private var isAuthenticating = false
  private let queue = DispatchQueue(label: "com.thoughtbot.finch.AuthenticationState")
  private let storage: AnyTokenStorage<Token>

  init<Storage: TokenStorage>(tokenStorage: Storage) where Storage.Token == Token {
    storage = AnyTokenStorage(tokenStorage)
  }

  func modify<Result>(body: (inout AuthenticationStateResult<Token>) throws -> Result) throws -> Result {
    return try queue.sync {
      var state = try currentState()
      let result = try body(&state)
      try update(from: state)
      return result
    }
  }

  func clearToken() {
  }

  private func currentState() throws -> AuthenticationStateResult<Token> {
    guard !isAuthenticating else { return .authenticating }
    let token = try storage.fetchToken()
    return AuthenticationStateResult(token: token)
  }

  private func update(from state: AuthenticationStateResult<Token>) throws {
    switch state {
    case let .authenticated(token):
      try storage.saveToken(token)
    case .unauthenticated:
      try storage.deleteToken()
    case .authenticating:
      break
    }

    isAuthenticating = state.isAuthenticating
  }
}

enum AuthenticationStateResult<Token> {
  case unauthenticated
  case authenticating
  case authenticated(Token)
}

private extension AuthenticationStateResult {
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

protocol TokenStorage {
  associatedtype Token

  func fetchToken() throws -> Token?
  func saveToken(_ token: Token) throws
  func deleteToken() throws
}

struct AnyTokenStorage<Token>: TokenStorage {
  private let _fetchToken: () throws -> Token?
  private let _saveToken: (Token) throws -> Void
  private let _deleteToken: () throws -> Void

  init<Base: TokenStorage>(_ base: Base) where Base.Token == Token {
    _fetchToken = { try base.fetchToken() }
    _saveToken = { try base.saveToken($0) }
    _deleteToken = { try base.deleteToken() }
  }

  func fetchToken() throws -> Token? {
    return try _fetchToken()
  }

  func saveToken(_ token: Token) throws {
    try _saveToken(token)
  }

  func deleteToken() throws {
    try _deleteToken()
  }
}

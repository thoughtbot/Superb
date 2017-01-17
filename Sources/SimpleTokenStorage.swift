struct SimpleTokenStorage<Token>: TokenStorage {
  private var token: Token?

  init(token: Token? = nil) {
    self.token = token
  }

  func fetchToken() -> Token? {
    return token
  }
}

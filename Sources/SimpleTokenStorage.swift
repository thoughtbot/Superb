struct SimpleTokenStorage<Token>: TokenStorage {
  private let token: Atomic<Token?>

  init(token: Token? = nil) {
    self.token = Atomic(token)
  }

  func fetchToken() -> Token? {
    return token.value
  }

  func saveToken(_ newToken: Token) {
    token.value = newToken
  }

  func deleteToken() {
    token.value = nil
  }
}

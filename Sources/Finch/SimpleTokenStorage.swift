public struct SimpleTokenStorage<Token>: TokenStorage {
  private let token: Atomic<Token?>

  public init(token: Token? = nil) {
    self.token = Atomic(token)
  }

  public func fetchToken() -> Token? {
    return token.value
  }

  public func saveToken(_ newToken: Token) {
    token.value = newToken
  }

  public func deleteToken() {
    token.value = nil
  }
}

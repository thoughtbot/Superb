protocol TokenStorage {
  associatedtype Token

  func fetchToken() throws -> Token?
}

public enum AuthenticationResult<Token> {
  case authenticated(Token)
  case failed(Error)
  case cancelled
}

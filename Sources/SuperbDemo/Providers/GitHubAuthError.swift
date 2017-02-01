enum GitHubAuthError: Error {
  case createAccessTokenFailed(Error)
  case tokenResponseInvalid(Any?)
}

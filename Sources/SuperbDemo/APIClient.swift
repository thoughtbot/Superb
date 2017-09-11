import Result

protocol APIClient {
  func getProfile(_ completionHandler: @escaping (Result<Profile, AnyError>) -> Void)
}

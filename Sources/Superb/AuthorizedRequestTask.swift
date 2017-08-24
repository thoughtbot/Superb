public final class AuthorizedRequestTask {
  var request: Request {
    return _request
  }

  private var _request: Request!
  private var _cancel: (() -> Void)!

  init<Token>(urlRequest: URLRequest, requestAuthorizer: RequestAuthorizer<Token>) {
    _request = Request(identifier: ObjectIdentifier(self), urlRequest: urlRequest)
    _cancel = { [request = _request!] in requestAuthorizer.cancelRequest(request) }
  }

  public func cancel() {
    _cancel()
  }
}

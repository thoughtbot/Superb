@testable import FinchUI
import Result
import Quick
import Nimble

final class RequestAuthorizerSpec: QuickSpec {
  override func spec() {
    func testURL(path: String) -> URL {
      return URL(string: "http://example.com")!.appendingPathComponent(path)
    }

    var requests: RequestExpectation!
    beforeEach { requests = self.requestExpectation() }
    afterEach { requests = nil }

    it("authorizes a request with the current token") {
      let testProvider = TestAuthorizationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, token: "test-token")
      let request = URLRequest(url: testURL(path: "/example"))

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "test-token"))
      authorizer.performAuthorized(request) { _ in }
      requests.verify()
    }

    it("calls the request authorizer when unathenticated") {
      let testProvider = TestAuthorizationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider)
      let request = URLRequest(url: testURL(path: "/example"))

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "dynamic-token"))

      authorizer.performAuthorized(request) { _ in }

      testProvider.complete(with: "dynamic-token")

      requests.verify()
    }

    it("calls the request authorizer and retries on a 401 response") {
      let testProvider = TestAuthorizationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, token: "stale-token")
      let request = URLRequest(url: testURL(path: "/example"))

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "stale-token")) { _ in
        return OHHTTPStubsResponse(data: Data(), statusCode: 401, headers: nil)
      }

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "new-token"))

      var response: HTTPURLResponse?
      var error: FinchError?

      authorizer.performAuthorized(request) { result in
        response = result.value?.1 as? HTTPURLResponse
        error = result.error
      }

      testProvider.complete(with: "new-token")

      requests.verify()
      expect(response?.statusCode).toEventually(equal(200))
      expect(error).to(beNil())
    }
  }
}

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
  }
}

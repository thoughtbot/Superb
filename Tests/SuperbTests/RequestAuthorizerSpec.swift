import Superb
import Result
import Quick
import Nimble

final class RequestAuthorizerSpec: QuickSpec {
  override func spec() {
    func emptyResponse(withStatus statusCode: Int32) -> OHHTTPStubsResponseBlock {
      return { _ in OHHTTPStubsResponse(data: Data(), statusCode: statusCode, headers: nil) }
    }

    func testRequest(path: String) -> URLRequest {
      let url = URL(string: "http://example.com")!.appendingPathComponent(path)
      return URLRequest(url: url)
    }

    var requests: RequestExpectation!
    beforeEach { requests = self.requestExpectation() }
    afterEach { requests = nil }

    it("authorizes a request with the current token") {
      let testProvider = TestAuthenticationProvider()
      let testTokenStorage = SimpleTokenStorage(token: "test-token")
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: testTokenStorage)
      let request = testRequest(path: "/example")

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "test-token"))
      authorizer.performAuthorized(request) { _ in }
      requests.verify()
    }

    it("calls the request authorizer when unathenticated") {
      let testProvider = TestAuthenticationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: SimpleTokenStorage())
      let request = testRequest(path: "/example")

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "dynamic-token"))

      authorizer.performAuthorized(request) { _ in }

      testProvider.complete(with: .authenticated("dynamic-token"))

      requests.verify()
    }

    it("calls the request authorizer and retries on a 401 response") {
      let testProvider = TestAuthenticationProvider()
      let testTokenStorage = SimpleTokenStorage(token: "stale-token")
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: testTokenStorage)
      let request = testRequest(path: "/example")

      requests.expect(
        where: isPath("/example") && hasHeaderNamed("Authorization", value: "stale-token"),
        andReturn: emptyResponse(withStatus: 401)
      )

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "new-token"))

      var response: HTTPURLResponse?
      var error: SuperbError?

      authorizer.performAuthorized(request) { result in
        response = result.value?.1 as? HTTPURLResponse
        error = result.error
      }

      testProvider.complete(with: .authenticated("new-token"))

      requests.verify()
      expect(response?.statusCode).toEventually(equal(200))
      expect(error).to(beNil())
    }

    it("authorizes multiple pending requests") {
      let testProvider = TestAuthenticationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: SimpleTokenStorage())

      var statusCodes: [Int] = []
      let queue = DispatchQueue(label: "response queue")
      let group = DispatchGroup()

      let limit = 50
      (0..<limit).forEach { _ in group.enter() }

      DispatchQueue.concurrentPerform(iterations: limit) { i in
        let example = "/example\(i + 1)"

        requests.expect(where: isPath(example) && hasHeaderNamed("Authorization", value: "shared-token"))

        authorizer.performAuthorized(testRequest(path: example)) { result in
          if let httpResponse = result.value?.1 as? HTTPURLResponse {
            queue.sync { statusCodes.append(httpResponse.statusCode) }
          }
        }

        group.leave()
      }

      group.wait()

      testProvider.complete(with: .authenticated("shared-token"))

      requests.verify()
      expect(statusCodes.count).toEventually(equal(limit))
      expect(Set(statusCodes)).to(equal(Set([200])))
    }

    it("notifies multiple pending requests of authentication failure") {
      let testProvider = TestAuthenticationProvider()
      let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: SimpleTokenStorage())

      var errors: [SuperbError] = []
      let queue = DispatchQueue(label: "response queue")
      let group = DispatchGroup()

      let limit = 50
      (0..<limit).forEach { _ in group.enter() }

      DispatchQueue.concurrentPerform(iterations: limit) { i in
        let example = "/example\(i + 1)"

        authorizer.performAuthorized(testRequest(path: example)) { result in
          if let error = result.error {
            queue.sync { errors.append(error) }
          }
        }

        group.leave()
      }

      group.wait()

      testProvider.complete(with: .cancelled)

      var allCancelled: Bool {
        for error in errors {
          switch error {
          case .authenticationCancelled:
            continue
          default:
            return false
          }
        }
        return true
      }

      requests.verify()
      expect(errors.count).toEventually(equal(limit))
      expect(allCancelled).to(beTrue())
    }

    describe("token storage") {
      it("updates the stored token after authenticating") {
        let testProvider = TestAuthenticationProvider()
        let testTokenStorage = SimpleTokenStorage<String>()
        let authorizer = RequestAuthorizer(authorizationProvider: testProvider, tokenStorage: testTokenStorage)
        let request = testRequest(path: "/example")

        requests.expect(where: isPath("/example"))

        authorizer.performAuthorized(request) { _ in }
        testProvider.complete(with: .authenticated("new-token"))

        expect(testTokenStorage.fetchToken()).toEventually(equal("new-token"))

        requests.verify()
      }
    }
  }
}

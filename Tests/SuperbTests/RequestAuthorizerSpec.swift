import Superb
import Result
import Quick
import Nimble

final class RequestAuthorizerSpec: QuickSpec {
  override func spec() {
    func delayedResponse(by interval: CFTimeInterval = 0.1, _ response: @escaping OHHTTPStubsResponseBlock) -> OHHTTPStubsResponseBlock {
      return { request in
        CFRunLoopRunInMode(.defaultMode, interval, false)
        return response(request)
      }
    }

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
      let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: testTokenStorage)
      let request = testRequest(path: "/example")

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "test-token"))
      authorizer.performAuthorized(request) { _ in }
      requests.verify()
    }

    it("calls the request authorizer when unathenticated") {
      let testProvider = TestAuthenticationProvider()
      let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: SimpleTokenStorage())
      let request = testRequest(path: "/example")

      requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "dynamic-token"))

      authorizer.performAuthorized(request) { _ in }

      testProvider.complete(with: .authenticated("dynamic-token"))

      requests.verify()
    }

    it("calls the request authorizer and retries on a 401 response") {
      let testProvider = TestAuthenticationProvider()
      let testTokenStorage = SimpleTokenStorage(token: "stale-token")
      let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: testTokenStorage)
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
      let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: SimpleTokenStorage())

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
      let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: SimpleTokenStorage())

      var completedRequests: Set<String> = []
      var errors: [SuperbError] = []
      let group = DispatchGroup()

      let examples = (1...5000).map { "/example\($0)" }
      examples.forEach { _ in group.enter() }

      DispatchQueue.concurrentPerform(iterations: examples.count) { i in
        let example = examples[i]
        let request = testRequest(path: example)

        authorizer.performAuthorized(request) { result in
          DispatchQueue.main.async {
            completedRequests.insert(example)
            if let error = result.error {
              errors.append(error)
            }
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

      expect(completedRequests).toEventually(equal(Set(examples)))
      expect(errors.count).to(equal(examples.count))
      expect(allCancelled).to(beTrue())
      requests.verify()
    }

    describe("token storage") {
      it("updates the stored token after authenticating") {
        let testProvider = TestAuthenticationProvider()
        let testTokenStorage = SimpleTokenStorage<String>()
        let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: testTokenStorage)
        let request = testRequest(path: "/example")

        requests.expect(where: isPath("/example"))

        authorizer.performAuthorized(request) { _ in }
        testProvider.complete(with: .authenticated("new-token"))

        expect(testTokenStorage.fetchToken()).toEventually(equal("new-token"))

        requests.verify()
      }
    }

    describe("clearToken") {
      it("removes the token from token storage") {
        let testTokenStorage = SimpleTokenStorage(token: "some-token")
        let authorizer = RequestAuthorizer(authenticationProvider: TestAuthenticationProvider(), tokenStorage: testTokenStorage)

        try? authorizer.clearToken()

        expect(testTokenStorage.fetchToken()).to(beNil())
      }

      it("doesn't affect pending requests while authenticating") {
        let testProvider = TestAuthenticationProvider()
        let testTokenStorage = SimpleTokenStorage(token: "old-token")
        let authorizer = RequestAuthorizer(authenticationProvider: testProvider, tokenStorage: testTokenStorage)
        let request = testRequest(path: "/example")

        requests.expect(where: isPath("/example") && hasHeaderNamed("Authorization", value: "new-token"))

        try? authorizer.clearToken()
        authorizer.performAuthorized(request) { _ in }
        testProvider.complete(with: .authenticated("new-token"))

        requests.verify()
      }
    }

    describe("cancellation") {
      it("cancels the underlying request") {
        let testTokenStorage = SimpleTokenStorage(token: "some-token")
        let authorizer = RequestAuthorizer(authenticationProvider: TestAuthenticationProvider(), tokenStorage: testTokenStorage)

        var isCancelled: Bool?
        let request = testRequest(path: "/long-request")

        requests.expect(where: isPath("/long-request"), andReturn: delayedResponse(emptyResponse(withStatus: 200)))

        let task = authorizer.performAuthorized(request) { result in
          DispatchQueue.main.async {
            switch result {
            case let .failure(.requestFailed(url, URLError.cancelled)) where url == request.url:
              isCancelled = true
            default:
              isCancelled = false
            }
          }
        }

        task.cancel()

        expect(isCancelled).toEventually(beTrue())
        requests.verify()
      }

      it("calls the completion handler with URLError.cancelled for pending requests") {
        let unauthenticatedStorage = SimpleTokenStorage<String>()
        let authorizer = RequestAuthorizer(authenticationProvider: TestAuthenticationProvider(), tokenStorage: unauthenticatedStorage)

        var isCancelled: Bool?
        let request = testRequest(path: "/never")

        let task = authorizer.performAuthorized(request) { result in
          DispatchQueue.main.async {
            switch result {
            case let .failure(.requestFailed(url, URLError.cancelled)) where url == request.url:
              isCancelled = true
            default:
              isCancelled = false
            }
          }
        }

        task.cancel()

        expect(isCancelled).toEventually(beTrue())
        requests.verify()
      }
    }
  }
}

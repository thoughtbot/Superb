@_exported import OHHTTPStubs
import XCTest

extension XCTestCase {
  func requestExpectation() -> RequestExpectation {
    return RequestExpectation(test: self)
  }
}

final class RequestExpectation: NSObject {
  private let responsesQueue = DispatchQueue(label: "responses queue")
  private var responses = Responses()
  private let stubsQueue = DispatchQueue(label: "stubs queue")
  private var stubs = Stubs()
  private let test: XCTestCase
  private var unexpectedStub: OHHTTPStubsDescriptor?

  fileprivate init(test: XCTestCase) {
    self.test = test
    super.init()
    self.unexpectedStub = stub(condition: { _ in true }) { [unowned self] request in
      self.willChangeValue(forKey: #keyPath(responseCount))
      self.responsesQueue.sync {
        self.responses.recordUnexpected(request)
      }
      self.didChangeValue(forKey: #keyPath(responseCount))
      return OHHTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
    }
  }

  deinit {
    tearDown()
  }

  func expect(where predicate: @escaping OHHTTPStubsTestBlock, file: StaticString = #file, line: UInt = #line, andReturn response: @escaping OHHTTPStubsResponseBlock = { _ in OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil) }) {
    var expectation: OHHTTPStubsDescriptor!
    expectation = stub(condition: predicate) { [unowned self] request in
      self.willChangeValue(forKey: #keyPath(responseCount))
      self.responsesQueue.sync {
        self.responses.recordComplete(expectation, request)
      }
      self.didChangeValue(forKey: #keyPath(responseCount))
      return response(request)
    }
    stubsQueue.sync { stubs.add(expectation, file, line) }
  }

  func verify(timeout: TimeInterval = 1, file: StaticString = #file, line: UInt = #line) {
    test.keyValueObservingExpectation(for: self, keyPath: #keyPath(responseCount), expectedValue: stubs.count)

    test.waitForExpectations(timeout: timeout) { error in
      var missing = self.stubsQueue.sync { self.stubs }
      for (stub, _) in self.expectedResponses.values {
        missing.remove(stub)
      }

      if error?._code == XCTestErrorCode.timeoutWhileWaiting.rawValue {
        for (_, file, line) in missing.stubs.values {
          XCTFail("timed out before receiving expected request", file: file, line: line)
        }
      }

      for request in self.unexpectedRequests {
        XCTFail("received unexpected request: \(string(describing: request))", file: file, line: line)
      }
    }
  }

  private func tearDown() {
    if let stub = unexpectedStub {
      OHHTTPStubs.removeStub(stub)
    }

    for stub in stubs.descriptors {
      OHHTTPStubs.removeStub(stub)
    }

    self.stubs = Stubs()
    self.unexpectedStub = nil
  }

  @objc private var responseCount: Int {
    return responsesQueue.sync {
      return responses.responseCount
    }
  }

  private var expectedResponses: [ObjectIdentifier: (OHHTTPStubsDescriptor, URLRequest)] {
    return responsesQueue.sync {
      responses.expected
    }
  }

  private var unexpectedRequests: [URLRequest] {
    return responsesQueue.sync {
      responses.unexpected
    }
  }
}

private func string(describing request: URLRequest) -> String {
  var components: [String] = []

  if let method = request.httpMethod {
    components.append(method)
  }

  if let url = request.url {
    components.append(url.description)
  }

  if let headers = request.allHTTPHeaderFields {
    let description = headers.map { "\($0): \($1)" }.joined(separator: ", ")
    components.append("{\(description)}")
  }

  return components.joined(separator: " ")
}

private struct Stubs {
  private(set) var stubs: [ObjectIdentifier: (OHHTTPStubsDescriptor, StaticString, UInt)]

  init() {
    stubs = [:]
  }

  var count: Int {
    return stubs.count
  }

  var descriptors: AnySequence<OHHTTPStubsDescriptor> {
    let descriptors = stubs.values.map { stub, _, _ in stub }
    return AnySequence(descriptors)
  }

  mutating func add(_ stub: OHHTTPStubsDescriptor, _ file: StaticString, _ line: UInt) {
    let identifer = ObjectIdentifier(stub)
    stubs[identifer] = (stub, file, line)
  }

  mutating func remove(_ stub: OHHTTPStubsDescriptor) {
    let identifier = ObjectIdentifier(stub)
    stubs[identifier] = nil
  }
}

private struct Responses {
  private(set) var expected: [ObjectIdentifier: (OHHTTPStubsDescriptor, URLRequest)] = [:]
  private(set) var unexpected: [URLRequest] = []

  mutating func recordComplete(_ stub: OHHTTPStubsDescriptor, _ request: URLRequest) {
    let identifier = ObjectIdentifier(stub)
    expected[identifier] = (stub, request)
  }

  mutating func recordUnexpected(_ request: URLRequest) {
    unexpected.append(request)
  }

  var responseCount: Int {
    return expected.count + unexpected.count
  }
}

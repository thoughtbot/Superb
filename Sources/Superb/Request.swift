import Foundation

struct Request {
  let identifier: ObjectIdentifier
  let urlRequest: URLRequest

  var url: URL? {
    return urlRequest.url
  }
}

extension Request: Equatable {
  static func == (lhs: Request, rhs: Request) -> Bool {
    return lhs.identifier == rhs.identifier && lhs.urlRequest == rhs.urlRequest
  }
}

extension Request: Hashable {
  var hashValue: Int {
    return identifier.hashValue
  }
}

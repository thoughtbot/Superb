import Foundation

extension URLError {
  static func makeCancelledError() -> URLError {
    let nsError = NSError(domain: URLError.errorDomain, code: URLError.cancelled.rawValue, userInfo: nil)
    return nsError as! URLError
  }
}

import Foundation
import Result

struct PendingRequest {
  let request: URLRequest
  let completionHandler: (Result<(Data, URLResponse), SuperbError>) -> Void
}

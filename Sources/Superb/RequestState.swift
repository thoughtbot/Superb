import Foundation
import Result

enum RequestState {
  typealias CompletionHandler = (Result<(Data, URLResponse), SuperbError>) -> Void

  case pending(CompletionHandler)
  case cancelled
  case running(URLSessionDataTask)
}

import Foundation

extension DispatchQueue {
  static let networking = DispatchQueue(label: "com.thoughtbot.superbdemo.networking")
}

extension OperationQueue {
  static let networking: OperationQueue = {
    let operationQueue = OperationQueue()
    operationQueue.maxConcurrentOperationCount = 1
    operationQueue.underlyingQueue = .networking
    return operationQueue
  }()
}

extension URLSession {
  static let api = URLSession(configuration: .default, delegate: nil, delegateQueue: .networking)
}

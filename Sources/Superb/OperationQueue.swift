import Foundation

extension OperationQueue {
  func sync<Result>(_ block: () throws -> Result) rethrows -> Result {
    return try withoutActuallyEscaping(block) { block in
      var result: OperationResult<Result>?

      let operation = BlockOperation {
        result = OperationResult { try block() }
      }

      addOperations([operation], waitUntilFinished: true)

      switch result! {
      case let .success(value):
        return value
      case let .failure(error):
        throw error
      }
    }
  }
}

private enum OperationResult<T> {
  case success(T)
  case failure(Error)

  init(_ body: () throws -> T) {
    do {
      self = .success(try body())
    } catch {
      self = .failure(error)
    }
  }
}

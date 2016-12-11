import Foundation

final class Atomic<Value> {
  private let lock = NSLock()
  private var _value: Value

  init(_ initial: Value) {
    _value = initial
  }

  var value: Value {
    get {
      return withValue { $0 }
    }
    set {
      modify { $0 = newValue }
    }
  }

  func modify<Result>(body: (inout Value) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&_value)
  }

  func withValue<Result>(body: (Value) throws -> Result) rethrows -> Result {
    return try modify {
      try body($0)
    }
  }
}

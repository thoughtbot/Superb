import Dispatch

/// Wraps some `Base` type so that all method calls become
/// "message sends", e.g., `async { $0.foo() }` or `sync { $0.bar() }`.
final class Actor<Base> {
  private var instance: Base
  private let queue: DispatchQueue

  init(_ instance: Base, target: DispatchQueue? = nil) {
    self.instance = instance
    self.queue = DispatchQueue(label: "com.thoughtbot.superb.\(Actor.self).queue", target: target)
  }

  func sync<Result>(_ message: (inout Base) throws -> Result) rethrows -> Result {
    return try queue.sync {
      try message(&instance)
    }
  }
}

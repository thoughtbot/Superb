import Foundation

final class ConditionLock<Condition: RawRepresentable> where Condition.RawValue == Int {
  private let lock: NSConditionLock

  init(label: String, condition: Condition) {
    lock = NSConditionLock(condition: condition.rawValue)
    lock.name = label
  }

  func lock(when condition: Condition) {
    lock.lock(whenCondition: condition.rawValue)
  }

  func unlock(with condition: Condition) {
    lock.unlock(withCondition: condition.rawValue)
  }
}

@testable import Finch
import Quick
import Nimble

final class ChannelSpec: QuickSpec {
  override func spec() {
    var channel: Channel<Int>!
    beforeEach { channel = Channel() }
    afterEach { channel = nil }

    it("notifies a subscriber when a message is broadcast") {
      var received: Int?
      channel.subscribe { received = $0 }
      channel.broadcast(1)
      expect(received).toEventually(equal(1))
    }

    it("notifies multiple subscribers concurrently") {
      var received: [Int: Int] = [:]
      let queue = DispatchQueue(label: "received queue")

      DispatchQueue.concurrentPerform(iterations: 100) { i in
        channel.subscribe { message in
          queue.sync { received[i] = message }
        }
      }

      channel.broadcast(1)

      var keys: Set<Int> { return queue.sync { Set(received.keys) } }
      var values: Set<Int> { return queue.sync { Set(received.values) } }

      expect(keys).toEventually(equal(Set(0..<100)))
      expect(values).toEventually(equal(Set([1])))
    }

    it("doesn't notify the same subscriber twice") {
      // Use high-priority queue to ensure subscribers execute promptly.
      let queue = DispatchQueue(label: "receive queue", qos: .userInteractive)

      var received: [Int] = []

      let possibleExecutions = DispatchGroup()
      possibleExecutions.enter()
      possibleExecutions.enter()

      channel.subscribe { message in
        queue.async {
          received.append(message)
          possibleExecutions.leave()
        }
      }

      channel.broadcast(1)
      channel.broadcast(2)

      let secondExecutionResult = possibleExecutions.wait(timeout: .now() + .milliseconds(100))

      expect(secondExecutionResult == .timedOut) == true
      expect(received) == [1]
    }

    it("handles concurrent subscription and broadcasting safely") {
      let subscriptions = 10000
      let subscriptionInterval = 0.0001

      let group = DispatchGroup()
      (0..<subscriptions).forEach { _ in group.enter() }
      DispatchQueue.concurrentPerform(iterations: subscriptions) { _ in
        Thread.sleep(forTimeInterval: subscriptionInterval)
        channel.subscribe { _ in
          group.leave()
        }
      }

      let broadcasts = subscriptions / 10
      let broadcastInterval = subscriptionInterval * 10

      DispatchQueue.concurrentPerform(iterations: broadcasts) { i in
        Thread.sleep(forTimeInterval: broadcastInterval)
        channel.broadcast(i)
      }

      guard case .success = group.wait(timeout: .now() + .seconds(1)) else {
        fail("expected all subscriptions to complete")
        return
      }
    }
  }
}

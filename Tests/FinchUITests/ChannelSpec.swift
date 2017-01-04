@testable import FinchUI
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
      let queue = DispatchQueue(label: "receive queue")

      var received: [Int] = []

      channel.subscribe { message in
        queue.async {
          received.append(message)
        }
      }

      channel.broadcast(1)
      channel.broadcast(2)

      Thread.sleep(forTimeInterval: 0.1)

      expect(received) == [1]
    }
  }
}

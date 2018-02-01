import Quick
import Nimble

final class ConcurrencySpec: QuickSpec {
  override func spec() {
    describe("OperationQueue underlyingQueue") {
      it("uses a shared exclusion context") {
        let eq = DispatchQueue(label: "EQ")
        let oq = OperationQueue()
        oq.underlyingQueue = eq

        let group = DispatchGroup()
        var total = 0

        DispatchQueue.concurrentPerform(iterations: 5000) { i in
          let increment = { total += 1 }

          if i % 2 == 0 {
            eq.async(group: group, execute: increment)
          } else {
            group.enter()
            oq.addOperation { increment(); group.leave() }
          }
        }

        group.wait()

        expect(total).to(equal(5000))
      }
    }

    describe("URLSession shared delegateQueue") {
      it("is thread-safe") {
        let queue = URLSession.shared.delegateQueue
        let group = DispatchGroup()
        var total = 0

        DispatchQueue.concurrentPerform(iterations: 5000) { _ in
          group.enter()

          queue.addOperation {
            total += 1
            group.leave()
          }
        }

        group.wait()

        expect(queue.maxConcurrentOperationCount).to(equal(1))
        expect(total).to(equal(5000))
      }
    }
  }
}

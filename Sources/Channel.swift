import Foundation

/// An asynchronous, unbuffered channel for broadcasting messages
/// to 0 or more subscribers.
final class Channel<Message> {
  private var message: Message?
  private let broadcasting = NSLock()
  private let queue = DispatchQueue(label: "com.thoughtbot.finch.\(Channel.self).subscribe", attributes: .concurrent)
  private let receivedMessage = DispatchSemaphore(value: 0)
  private let subscribers = DispatchGroup()

  init() {
    broadcasting.name = "com.thoughtbot.finch.\(Channel.self).broadcast"
  }

  /// Subscribe to the next message.
  ///
  /// - parameter receive: A function to be invoked asynchronously with the next message.
  func subscribe(_ receive: @escaping (Message) -> Void) {
    subscribers.enter()
    queue.async {
      self.receivedMessage.wait()
      let message = self.message!
      self.subscribers.leave()
      receive(message)
    }
  }

  /// Synchronously broadcast `message` to all subscribers.
  ///
  /// - parameter message: The message to broadcast.
  func broadcast(_ message: Message) {
    self.broadcasting.lock()
    self.message = message

    defer {
      self.message = nil
      self.broadcasting.unlock()
    }

    while true {
      receivedMessage.signal()

      switch subscribers.wait(timeout: .now()) {
      case .timedOut:
        continue
      case .success:
        return
      }
    }
  }
}

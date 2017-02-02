import Foundation

/// An asynchronous, unbuffered channel for broadcasting messages
/// to 0 or more subscribers.
final class Channel<Message> {
  private let subscribers: Atomic<[(Message) -> Void]> = Atomic([])
  private let queue = DispatchQueue(label: "com.thoughtbot.superb.\(Channel.self).subscribe", attributes: .concurrent)

  /// Subscribe to the next message.
  ///
  /// - parameter receive: A function to be invoked asynchronously with the next message.
  func subscribe(_ receive: @escaping (Message) -> Void) {
    subscribers.modify { $0.append(receive) }
  }

  /// Synchronously broadcast `message` to all subscribers.
  ///
  /// - parameter message: The message to broadcast.
  func broadcast(_ message: Message) {
    for subscriber in subscribers.swap([]) {
      queue.async { [send = subscriber] in
        send(message)
      }
    }
  }
}

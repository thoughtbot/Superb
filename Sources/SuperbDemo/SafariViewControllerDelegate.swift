import SafariServices

final class SafariViewControllerDelegate: NSObject, SFSafariViewControllerDelegate {
  private let completionHandler: () -> Void

  init(completionHandler: @escaping () -> Void) {
    self.completionHandler = completionHandler
  }

  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    completionHandler()
  }
}

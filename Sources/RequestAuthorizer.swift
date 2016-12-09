import UIKit

final class RequestAuthorizer {
  let applicationDelegate: UIApplicationDelegate
  let authorizationProvider: FinchProvider

  private var token: String?

  init(applicationDelegate: UIApplicationDelegate, authorizationProvider: FinchProvider) {
    self.applicationDelegate = applicationDelegate
    self.authorizationProvider = authorizationProvider
  }

  func performAuthorized(_ request: URLRequest, completionHandler: @escaping (Result<(Data?, URLResponse?)>) -> Void) {
    performAuthorized(request, reauthorize: true, completionHandler: completionHandler)
  }

  private func performAuthorized(_ request: URLRequest, reauthorize shouldReauthorize: Bool = true, completionHandler: @escaping (Result<(Data?, URLResponse?)>) -> Void) {
    var authorizedRequest = request

    if let authorization = token.map(authorizationProvider.authorizationHeader(forToken:)) {
      authorizedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    let task = URLSession.shared.dataTask(with: authorizedRequest) { data, response, error in
      let result: Result<(Data?, URLResponse?)>

      if let error = error {
        result = .failure(error)
      } else {
        result = .success(data, response)
      }

      func complete(failingWith newError: Error? = nil) {
        let finalResult = newError.map(Result.failure) ?? result
        DispatchQueue.main.async {
          completionHandler(finalResult)
        }
      }

      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 401,
        shouldReauthorize
        else {
          complete()
          return
        }

      guard let topViewController = self.topViewController else {
        complete(failingWith: FinchError.userInteractionRequired)
        return
      }

      DispatchQueue.main.async {
        self.authorizationProvider.authorize(over: topViewController) { result in
          switch result {
          case let .success(token):
            self.token = token
            self.performAuthorized(request, reauthorize: false, completionHandler: completionHandler)

          case let .failure(error):
            complete(failingWith: error)
          }
        }

      }
    }

    task.resume()
  }

  private var topViewController: UIViewController? {
    guard let rootViewController = applicationDelegate.window??.rootViewController
      else { return nil }

    return rootViewController.topPresentedViewController
  }
}

private extension Sequence {
  var first: Iterator.Element? {
    return first(where: { _ in true })
  }

  var last: Iterator.Element? {
    return suffix(1).first
  }
}

private extension UIViewController {
  var hierarchy: AnySequence<UIViewController> {
    return AnySequence { () -> AnyIterator<UIViewController> in
      var queue = [self]

      return AnyIterator {
        if !queue.isEmpty {
          let next = queue.removeFirst()
          queue.append(contentsOf: next.childViewControllers)
          return next
        } else {
          return nil
        }
      }
    }
  }

  var topPresentedViewController: UIViewController? {
    let presented = hierarchy.lazy.flatMap { $0.presentedViewController }
    let firstPresented = presented.first
    return firstPresented?.topPresentedViewController ?? firstPresented
  }
}

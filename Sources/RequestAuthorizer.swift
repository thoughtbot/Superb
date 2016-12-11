import Result
import UIKit

final class RequestAuthorizer<Token> {
  let applicationDelegate: UIApplicationDelegate
  let authorizationProvider: AnyFinchProvider<Token>

  private var token: Token?

  init<Provider: FinchProvider>(applicationDelegate: UIApplicationDelegate, authorizationProvider: Provider) where Provider.Token == Token {
    self.applicationDelegate = applicationDelegate
    self.authorizationProvider = AnyFinchProvider(authorizationProvider)
  }

  func performAuthorized(_ request: URLRequest, qos: DispatchQoS.QoSClass = .default, completionHandler: @escaping (Result<(Data?, URLResponse?), FinchError>) -> Void) {
    DispatchQueue.global(qos: qos).async {
      self.performAuthorized(request, reauthenticate: true, completionHandler: completionHandler)
    }
  }

  private func performAuthorized(_ request: URLRequest, reauthenticate: Bool = true, completionHandler: @escaping (Result<(Data?, URLResponse?), FinchError>) -> Void) {
    var authorizedRequest = request

    if let authorization = token.map(authorizationProvider.authorizationHeader(forToken:)) {
      authorizedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    let task = URLSession.shared.dataTask(with: authorizedRequest) { data, response, error in
      let result: Result<(Data?, URLResponse?), FinchError>

      if let error = error {
        result = .failure(.requestFailed(error))
      } else {
        result = .success(data, response)
      }

      func complete(overridingResultWith newError: FinchError?) {
        let finalResult = newError.map(Result.failure) ?? result
        DispatchQueue.main.async {
          completionHandler(finalResult)
        }
      }

      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 401,
        reauthenticate
        else {
          complete(overridingResultWith: nil)
          return
        }

      guard let topViewController = self.topViewController else {
        complete(overridingResultWith: .userInteractionRequired)
        return
      }

      DispatchQueue.main.async {
        self.authorizationProvider.authorize(over: topViewController) { result in
          switch result {
          case let .success(token):
            self.token = token
            self.performAuthorized(request, reauthenticate: false, completionHandler: completionHandler)

          case let .failure(error):
            complete(overridingResultWith: error)
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

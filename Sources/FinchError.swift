import Foundation

enum FinchError: Error {
  case authorizationResponseInvalid
}

extension FinchError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authorizationResponseInvalid:
      return "😢"
    }
  }
}

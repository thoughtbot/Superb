import Foundation

enum FinchError: Error {
  case authorizationResponseInvalid
  case requestFailed(Error)
  case unauthorized
  case userInteractionRequired
}

extension FinchError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authorizationResponseInvalid:
      return "😢"
    case .requestFailed(let error):
      return "FinchError.requestFailed(\(error.localizedDescription))"
    case .unauthorized:
      return "🙅"
    case .userInteractionRequired:
      return "📱🔨"
    }
  }
}

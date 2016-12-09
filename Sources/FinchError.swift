import Foundation

enum FinchError: Error {
  case authorizationResponseInvalid
  case userInteractionRequired
}

extension FinchError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authorizationResponseInvalid:
      return "😢"
    case .userInteractionRequired:
      return "📱🔨"
    }
  }
}

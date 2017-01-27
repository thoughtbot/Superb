import Foundation

enum FinchError: Error {
  case authorizationResponseInvalid
  case keychainAccessFailure(OSStatus)
  case keychainDecodeFailure(Data)
  case requestFailed(Error)
  case unauthorized
  case userInteractionRequired
}

extension FinchError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authorizationResponseInvalid:
      return "😢"
    case .keychainAccessFailure(let status):
      return "Keychain access failed: \(status)"
    case .keychainDecodeFailure:
      return "Keychain decode failed"
    case .requestFailed(let error):
      return "FinchError.requestFailed(\(error.localizedDescription))"
    case .unauthorized:
      return "🙅"
    case .userInteractionRequired:
      return "📱🔨"
    }
  }
}

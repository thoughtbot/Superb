import Foundation

public enum SuperbError: Error {
  case authorizationResponseInvalid
  case keychainAccessFailure(OSStatus)
  case keychainDecodeFailure(Data)
  case requestFailed(Error)
  case unauthorized
  case userInteractionRequired
}

extension SuperbError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authorizationResponseInvalid:
      return "😢"
    case .keychainAccessFailure(let status):
      return "Keychain access failed: \(status)"
    case .keychainDecodeFailure:
      return "Keychain decode failed"
    case .requestFailed(let error):
      return "SuperbError.requestFailed(\(error.localizedDescription))"
    case .unauthorized:
      return "🙅"
    case .userInteractionRequired:
      return "📱🔨"
    }
  }
}

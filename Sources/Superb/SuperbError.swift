import Foundation

public enum SuperbError: Error {
  case authenticationCancelled
  case authenticationFailed(Error)
  case keychainAccessFailure(OSStatus)
  case keychainDecodeFailure(Data)
  case requestFailed(Error)
  case userInteractionRequired
}

extension SuperbError: LocalizedError {
  var localizedDescription: String {
    switch self {
    case .authenticationCancelled:
      return "🤷‍♀️"
    case .authenticationFailed:
      return "🙅"
    case .keychainAccessFailure(let status):
      return "Keychain access failed: \(status)"
    case .keychainDecodeFailure:
      return "Keychain decode failed"
    case .requestFailed(let error):
      return "SuperbError.requestFailed(\(error.localizedDescription))"
    case .userInteractionRequired:
      return "📱🔨"
    }
  }
}

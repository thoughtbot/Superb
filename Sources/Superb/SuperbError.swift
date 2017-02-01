import Foundation

public enum SuperbError: Error {
  /// Authentication was cancelled by the user.
  case authenticationCancelled

  /// An error occurred during authentication.
  case authenticationFailed(Error)

  /// A problem occurred while reading from the keychain.
  case keychainReadFailure(OSStatus)

  /// A problem occurred while writing to the keychain.
  case keychainWriteFailure(OSStatus)

  /// Unable to decode the token data from the keychain.
  case keychainDecodeFailure(Data)

  /// A HTTP request failed during authentication.
  case requestFailed(URL?, Error)

  /// Attempted to authenticate, but the top view controller could not be found.
  case userInteractionRequired
}

extension SuperbError: CustomNSError {
  public static let errorDomain = "FinchError"

  public var errorCode: Int {
    switch self {
    case .authenticationCancelled:
      return 10
    case .authenticationFailed:
      return 11

    case .keychainReadFailure:
      return 20
    case .keychainWriteFailure:
      return 21
    case .keychainDecodeFailure:
      return 22

    case .requestFailed:
      return 30

    case .userInteractionRequired:
      return 40
    }
  }

  public var errorUserInfo: [String : Any] {
    var userInfo: [String: Any] = [:]
    userInfo[NSLocalizedDescriptionKey] = errorDescription
    userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
    userInfo[NSUnderlyingErrorKey] = underlyingError
    userInfo[NSURLErrorKey] = url
    return userInfo
  }
}

extension SuperbError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .authenticationCancelled,
         .authenticationFailed,
         .keychainDecodeFailure,
         .userInteractionRequired:
      return failureReason

    case .keychainReadFailure(let code),
         .keychainWriteFailure(let code):
      return String(
        format: NSLocalizedString("Failed to access the keychain (code %@).", bundle: .superb, comment: "Error description for keychain access failure"),
        arguments: [code]
      )

    case .requestFailed:
      return NSLocalizedString("Authentication failed because the server responded with an error.", bundle: .superb, comment: "Error description for authentication request failed")
    }
  }

  public var failureReason: String? {
    switch self {
    case .authenticationCancelled:
      return NSLocalizedString("Authentication was cancelled.", bundle: .superb, comment: "Failure reason for authentication cancelled")

    case .authenticationFailed:
      return NSLocalizedString("Authentication failed.", bundle: .superb, comment: "Failure reason for authentication failed")

    case .keychainReadFailure:
      return NSLocalizedString("The keychain could not be read.", bundle: .superb, comment: "Failure reason for keychain read failed")

    case .keychainWriteFailure:
      return NSLocalizedString("The keychain could not be written.", bundle: .superb, comment: "Failure reason for keychain write failed")

    case .keychainDecodeFailure:
      return NSLocalizedString("The data was not in a recognisable format.", bundle: .superb, comment: "Failure reason for data decode failure")

    case .requestFailed:
      return NSLocalizedString("The server returned an error.", bundle: .superb, comment: "Failure reason for authentication request failed")

    case .userInteractionRequired:
      return NSLocalizedString("The user interface was unavailable.", bundle: .superb, comment: "Failure reason for UI unavailable")
    }
  }

  public var underlyingError: Error? {
    switch self {
    case .authenticationFailed(let error),
         .requestFailed(_, let error):
      return error

    case .authenticationCancelled,
         .keychainReadFailure,
         .keychainWriteFailure,
         .keychainDecodeFailure,
         .userInteractionRequired:
      return nil
    }
  }

  public var url: URL? {
    switch self {
    case .requestFailed(let url, _):
      return url

    case .authenticationCancelled,
         .authenticationFailed,
         .keychainReadFailure,
         .keychainWriteFailure,
         .keychainDecodeFailure,
         .userInteractionRequired:
      return nil
    }
  }
}

private extension Bundle {
  static var superb: Bundle {
    return Bundle(for: Superb.self)
  }

  private final class Superb {}
}

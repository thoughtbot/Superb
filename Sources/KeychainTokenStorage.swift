import Foundation

enum KeychainTokenStorageError: Error {
  case decodeFailure(Data)
  case keychain(OSStatus)
}

struct KeychainTokenStorage<Token: KeychainDecodable & KeychainEncodable> {
  func fetchToken(for service: String) throws -> Token? {
    let query: NSDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecReturnData: true,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)

    guard status != errSecItemNotFound else {
      return nil
    }

    guard status == noErr else {
      throw KeychainTokenStorageError.keychain(status)
    }

    let data = result as! Data
    guard let token = Token(decoding: data) else {
      throw KeychainTokenStorageError.decodeFailure(data)
    }

    return token
  }

  func saveToken(_ token: Token, for service: String) throws {
    let item: NSDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecValueData: token.encoded(),
    ]

    let status = SecItemAdd(item, nil)
    guard status == noErr else {
      throw KeychainTokenStorageError.keychain(status)
    }
  }

  func deleteToken(for service: String) throws {
    let item: NSDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]

    let status = SecItemDelete(item)
    guard status == noErr else {
      throw KeychainTokenStorageError.keychain(status)
    }
  }
}

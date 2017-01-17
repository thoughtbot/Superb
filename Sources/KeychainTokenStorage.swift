import Foundation

struct KeychainTokenStorage<Token: KeychainDecodable & KeychainEncodable>: TokenStorage {
  let service: String

  func fetchToken() throws -> Token? {
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
      throw FinchError.keychainAccessFailure(status)
    }

    let data = result as! Data
    guard let token = Token(decoding: data) else {
      throw FinchError.keychainDecodeFailure(data)
    }

    return token
  }

  func saveToken(_ token: Token) throws {
    let item: NSDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecValueData: token.encoded(),
    ]

    let status = SecItemAdd(item, nil)
    guard status == noErr else {
      throw FinchError.keychainAccessFailure(status)
    }
  }

  func deleteToken() throws {
    let item: NSDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]

    let status = SecItemDelete(item)
    guard status == noErr else {
      throw FinchError.keychainAccessFailure(status)
    }
  }
}

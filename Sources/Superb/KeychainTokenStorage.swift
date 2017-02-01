import Foundation

public struct KeychainTokenStorage<Token: KeychainDecodable & KeychainEncodable>: TokenStorage {
  let service: String
  let label: String?
  private let labelData: Data?

  public init(service: String, label: String? = nil) {
    self.service = service
    self.label = label
    self.labelData = label.flatMap { $0.data(using: .utf8) }
  }

  public func fetchToken() throws -> Token? {
    let query: NSMutableDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecReturnData: true,
    ]

    addLabelIfNecessary(to: query)

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)

    guard status != errSecItemNotFound else {
      return nil
    }

    guard status == noErr else {
      throw SuperbError.keychainReadFailure(status)
    }

    let data = result as! Data
    guard let token = Token(decoding: data) else {
      throw SuperbError.keychainDecodeFailure(data)
    }

    return token
  }

  public func saveToken(_ token: Token) throws {
    let item: NSMutableDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecValueData: token.encoded(),
    ]

    addLabelIfNecessary(to: item)

    let status = SecItemAdd(item, nil)
    guard status == noErr else {
      throw SuperbError.keychainWriteFailure(status)
    }
  }

  public func deleteToken() throws {
    let item: NSMutableDictionary = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
    ]

    addLabelIfNecessary(to: item)

    let status = SecItemDelete(item)

    guard status != errSecItemNotFound else {
      return
    }

    guard status == noErr else {
      throw SuperbError.keychainWriteFailure(status)
    }
  }

  private func addLabelIfNecessary(to item: NSMutableDictionary) {
    if let label = labelData {
      item[kSecAttrGeneric] = label
    }
  }
}

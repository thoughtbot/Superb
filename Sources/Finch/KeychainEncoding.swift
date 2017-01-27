import Foundation

public protocol KeychainDecodable {
  init?(decoding data: Data)
}

public protocol KeychainEncodable {
  func encoded() -> Data
}

extension String: KeychainDecodable {
  public init?(decoding data: Data) {
    guard let string = String(data: data, encoding: .utf8) else { return nil }
    self = string
  }
}

extension String: KeychainEncodable {
  public func encoded() -> Data {
    return data(using: .utf8)!
  }
}

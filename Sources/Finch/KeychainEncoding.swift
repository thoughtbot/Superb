import Foundation

protocol KeychainDecodable {
  init?(decoding data: Data)
}

protocol KeychainEncodable {
  func encoded() -> Data
}

extension String: KeychainDecodable {
  init?(decoding data: Data) {
    guard let string = String(data: data, encoding: .utf8) else { return nil }
    self = string
  }
}

extension String: KeychainEncodable {
  func encoded() -> Data {
    return data(using: .utf8)!
  }
}

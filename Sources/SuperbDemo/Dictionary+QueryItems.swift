import Foundation

extension Dictionary where Key == String, Value == String {
  init?(queryItems: [URLQueryItem], filteringEmptyKeys: Bool) {
    self = [:]

    for item in queryItems {
      if let value = item.value {
        self[item.name] = value
      } else if !filteringEmptyKeys {
        return nil
      }
    }
  }
}

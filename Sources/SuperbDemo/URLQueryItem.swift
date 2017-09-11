import Foundation

extension URLQueryItem {
  static func queryItems(from queryString: String) -> [URLQueryItem]? {
    var components = URLComponents()
    components.query = queryString
    return components.queryItems
  }
}

import Argo
import Foundation

extension URL: Decodable {
  public static func decode(_ json: JSON) -> Decoded<URL> {
    return String.decode(json).flatMap { .fromOptional(URL(string: $0)) }
  }
}

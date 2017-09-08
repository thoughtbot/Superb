import Argo
import Foundation

extension Argo.Decodable {
  static func parse(data: Data, response _: URLResponse, decode decoder: (JSON) -> Decoded<DecodedType>) throws -> DecodedType {
    let object = try JSONSerialization.jsonObject(with: data)
    let json = JSON(object)
    return try decoder(json).dematerialize()
  }

  static func parse(data: Data, response: URLResponse) throws -> DecodedType {
    return try parse(data: data, response: response, decode: Self.decode)
  }
}

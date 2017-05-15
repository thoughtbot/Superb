import Argo
import Curry
import Runes

struct Profile {
  var login: String
}

extension Profile: Decodable {
  static func decode(_ json: JSON) -> Decoded<Profile> {
    return curry(Profile.init)
      <^> json <| "login"
  }
}

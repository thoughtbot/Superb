import Argo
import Curry
import Runes

struct Profile {
  var login: String
  var name: String?
  var avatar: URL?
}

extension Profile: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<Profile> {
    return curry(Profile.init)
      <^> json <| "login"
      <*> json <|? "name"
      <*> json <|? "avatar_url"
  }

  static func decodeTwitterProfile(_ json: JSON) -> Decoded<Profile> {
    return curry(Profile.init)
      <^> json <| "screen_name"
      <*> json <|? "name"
      <*> json <|? "profile_image_url"
  }
}

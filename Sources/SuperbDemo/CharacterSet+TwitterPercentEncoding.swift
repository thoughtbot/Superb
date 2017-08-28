import Foundation

extension CharacterSet {
  static let twitterAllowed: CharacterSet = {
    var characterSet = CharacterSet()
    characterSet.insert(charactersIn: "0123456789")
    characterSet.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    characterSet.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
    characterSet.insert(charactersIn: "-._~")
    return characterSet
  }()
}

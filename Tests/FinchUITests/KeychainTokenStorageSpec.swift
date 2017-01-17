@testable import FinchUI
import Quick
import Nimble

final class KeychainTokenStorageSpec: QuickSpec {
  override func spec() {
    let account = "test account"
    let service = "finch tests"

    func deleteTestToken() {
      let item: NSDictionary = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
      ]

      SecItemDelete(item)
    }

    func fetchTestToken() -> String? {
      let query: NSDictionary = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecReturnData: true,
      ]

      var result: CFTypeRef?
      SecItemCopyMatching(query, &result)
      let data = result as! Data?
      return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    func saveTestToken(_ token: String) {
      let item: NSDictionary = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecValueData: token.data(using: .utf8)!,
      ]
      let result = SecItemAdd(item, nil)
      expect(result) == noErr
    }

    beforeEach {
      deleteTestToken()
    }

    afterEach {
      deleteTestToken()
    }

    it("fetches the token from the keychain") {
      let storage = KeychainTokenStorage<String>()
      saveTestToken("s3cret")
      expect { try storage.fetchToken(for: service) } == "s3cret"
    }

    it("returns nil if the fetched token doesn't exist in the keychain") {
      let storage = KeychainTokenStorage<String>()
      expect { try storage.fetchToken(for: service) }.to(beNil())
    }

    it("saves the token to the keychain") {
      let storage = KeychainTokenStorage<String>()
      expect { try storage.saveToken("passw0rd", for: service) }.toNot(throwError())
      expect { fetchTestToken() } == "passw0rd"
    }

    it("deletes the token from the keychain") {
      let storage = KeychainTokenStorage<String>()
      saveTestToken("1nsecure")
      expect { try storage.deleteToken(for: service) }.toNot(throwError())
      expect { fetchTestToken() }.to(beNil())
    }
  }
}

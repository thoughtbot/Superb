import CommonCrypto.CommonHMAC
import Foundation

extension String {
  func hmacSHA1(usingKey key: String) -> String {
    let baseLength = utf8.count
    let keyLength = key.utf8.count

    return withCString { base in
      key.withCString { key in
        let digestLength = Int(CC_SHA1_DIGEST_LENGTH)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
        defer { buffer.deallocate(capacity: digestLength) }
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA1)
        CCHmac(algorithm, key, keyLength, base, baseLength, buffer)
        return Data(bytesNoCopy: buffer, count: digestLength, deallocator: .none).base64EncodedString()
      }
    }
  }
}

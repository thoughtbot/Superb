import Foundation

extension String {
  static func makeRandomHexadecimalString(length: Int) throws -> String {
    let bufferLength = length / 2 + 1
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferLength)
    defer { buffer.deallocate(capacity: bufferLength) }

    guard SecRandomCopyBytes(kSecRandomDefault, bufferLength, buffer) == errSecSuccess else {
      let code = POSIXErrorCode(rawValue: errno)!
      throw POSIXError(code)
    }

    var output = ""
    for byte in Data(bytesNoCopy: buffer, count: length, deallocator: .none) {
      let hex = String(byte, radix: 16)
      output.append(hex)
    }
    return output
  }
}

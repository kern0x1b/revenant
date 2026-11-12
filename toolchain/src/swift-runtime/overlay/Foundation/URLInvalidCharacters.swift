import Foundation

private let revenantURLAllowedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=".utf8)
private let revenantURLHexDigits = Set("0123456789ABCDEFabcdef".utf8)

func revenantEncodingInvalidCharacters(_ string: String) -> String {
    let upperHexDigits = Array("0123456789ABCDEF".utf8)
    let bytes = Array(string.utf8)
    var result: [UInt8] = []
    result.reserveCapacity(bytes.count)
    var index = 0
    while index < bytes.count {
        let byte = bytes[index]
        if byte == UInt8(ascii: "%"), index + 2 < bytes.count,
           revenantURLHexDigits.contains(bytes[index + 1]), revenantURLHexDigits.contains(bytes[index + 2]) {
            result.append(byte)
        } else if revenantURLAllowedBytes.contains(byte) {
            result.append(byte)
        } else {
            result.append(UInt8(ascii: "%"))
            result.append(upperHexDigits[Int(byte >> 4)])
            result.append(upperHexDigits[Int(byte & 0x0F)])
        }
        index += 1
    }
    return String(decoding: result, as: UTF8.self)
}

func revenantHostHasInvalidCharacters(_ string: String) -> Bool {
    let bytes = Array(string.utf8)
    let slash = UInt8(ascii: "/"), question = UInt8(ascii: "?"), hash = UInt8(ascii: "#")
    var start = 0
    if bytes.count >= 2, bytes[0] == slash, bytes[1] == slash {
        start = 2
    } else {
        var index = 0
        while index < bytes.count, bytes[index] != slash, bytes[index] != question, bytes[index] != hash,
              bytes[index] != UInt8(ascii: ":") {
            index += 1
        }
        guard index + 2 < bytes.count, bytes[index] == UInt8(ascii: ":"),
              bytes[index + 1] == slash, bytes[index + 2] == slash else {
            return false
        }
        start = index + 3
    }
    var end = start
    while end < bytes.count, bytes[end] != slash, bytes[end] != question, bytes[end] != hash {
        end += 1
    }
    var host = start
    var index = start
    while index < end {
        if bytes[index] == UInt8(ascii: "@") {
            host = index + 1
        }
        index += 1
    }
    for byte in bytes[host..<end] where !revenantURLAllowedBytes.contains(byte) {
        return true
    }
    return false
}

extension URL {
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public init?(string: __shared String, encodingInvalidCharacters: Bool) {
        if encodingInvalidCharacters {
            if revenantHostHasInvalidCharacters(string) {
                return nil
            }
            self.init(string: revenantEncodingInvalidCharacters(string))
        } else {
            if revenantEncodingInvalidCharacters(string) != string || string.utf8.filter({ $0 == UInt8(ascii: "#") }).count > 1 {
                return nil
            }
            self.init(string: string)
        }
    }
}

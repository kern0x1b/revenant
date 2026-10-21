import Foundation

public enum MusicAPIs {
    public static let host = "https://api.music.apple.com"

    public static func catalogURL(storefront: String, path: String) -> URL? {
        URL(string: "\(host)/v1/catalog/\(storefront)/\(path)")
    }
}

public enum MusicError: Error {
    case developerTokenUnauthorized
    case unexpectedStatus(Int)
    case malformedResponse
    case transport(Error)
}

public enum MusicDeveloperToken {

    public static var developerToken: String?

    public static var current: String? {
        get { developerToken }
        set { developerToken = newValue }
    }

    public static func mint(keyIdentifier: String, teamIdentifier: String, privateKeyPEM: String) -> String? {
        guard let key = RevenantBase64URL.decode(RevenantBase64URL.pemBody(privateKeyPEM)),
              key.count > 0 else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        let header = #"{"alg":"ES256","kid":"\#(keyIdentifier)"}"#
        let payload = #"{"iss":"\#(teamIdentifier)","iat":\#(now),"exp":\#(now + 3600)}"#
        let encodedHeader = RevenantBase64URL.encode(Data(header.utf8))
        let encodedPayload = RevenantBase64URL.encode(Data(payload.utf8))
        let signing = "\(encodedHeader).\(encodedPayload)"
        let message = Array(signing.utf8)
        var der = [UInt8](repeating: 0, count: 72)
        let keyBytes = Array(key)
        let length = keyBytes.withUnsafeBufferPointer { privateKey in
            message.withUnsafeBufferPointer { body in
                RevenantMusicKitSignES256(privateKey.baseAddress, privateKey.count,
                                       body.baseAddress, body.count, &der, der.count)
            }
        }
        guard length > 0 else { return nil }
        return "\(signing).\(RevenantBase64URL.encode(Data(der[0..<Int(length)])))"
    }
}

enum RevenantBase64URL {
    static func pemBody(_ pem: String) -> String {
        guard let begin = pem.range(of: "-----BEGIN"),
              let end = pem.range(of: "-----END", range: begin.upperBound ..< pem.endIndex) else {
            return ""
        }
        let afterHeader = pem[begin.upperBound...].drop(while: { $0 != "\n" })
        return String(afterHeader[..<end.lowerBound].filter { !$0.isWhitespace })
    }

    private static func value(of byte: UInt8) -> Int? {
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): return Int(byte - UInt8(ascii: "A"))
        case UInt8(ascii: "a")...UInt8(ascii: "z"): return Int(byte - UInt8(ascii: "a")) + 26
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(byte - UInt8(ascii: "0")) + 52
        case UInt8(ascii: "+"), UInt8(ascii: "-"): return 62
        case UInt8(ascii: "/"), UInt8(ascii: "_"): return 63
        default: return nil
        }
    }

    static func decode(_ text: String) -> Data? {
        var out = Data()
        out.reserveCapacity(text.count * 3 / 4)
        var buffer: UInt32 = 0
        var bits = 0
        for byte in Array(text.utf8) {
            if byte == UInt8(ascii: "=") { break }
            guard let value = value(of: byte) else { continue }
            buffer = (buffer << 6) | UInt32(value)
            bits += 6
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> UInt32(bits)) & 0xFF))
            }
        }
        return out.isEmpty ? nil : out
    }

    static func encode(_ data: Data) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        var out = ""
        out.reserveCapacity((data.count + 2) / 3 * 4)
        var index = 0
        while index + 2 < data.count {
            let triple = (UInt32(data[index]) << 16) | (UInt32(data[index + 1]) << 8) | UInt32(data[index + 2])
            out.append(alphabet[Int((triple >> 18) & 0x3F)])
            out.append(alphabet[Int((triple >> 12) & 0x3F)])
            out.append(alphabet[Int((triple >> 6) & 0x3F)])
            out.append(alphabet[Int(triple & 0x3F)])
            index += 3
        }
        if index + 1 == data.count {
            let pair = UInt32(data[index]) << 16
            out.append(alphabet[Int((pair >> 18) & 0x3F)])
            out.append(alphabet[Int((pair >> 12) & 0x3F)])
        } else if index + 2 == data.count {
            let pair = (UInt32(data[index]) << 16) | (UInt32(data[index + 1]) << 8)
            out.append(alphabet[Int((pair >> 18) & 0x3F)])
            out.append(alphabet[Int((pair >> 12) & 0x3F)])
            out.append(alphabet[Int((pair >> 6) & 0x3F)])
        }
        return out
    }
}

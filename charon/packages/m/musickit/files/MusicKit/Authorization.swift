// The developer token the Apple Music API is asked with, and the errors a request that has none
// answers.
//
// The token is the same shape as the one a CloudKit Web Services authentication key makes: an ES256
// JWT over a header, a payload and the key's own identifier, signed with P-256 and SHA-256. The
// signature is not written here - it is `charon@micro-ecc`, the same library the CloudKit family
// links, and this module is built to be linked beside it.
//
// A client that has no key, or no developer token handed to it, has nothing to sign a request with.
// Every request in this module then fails with `MusicError.developerTokenUnauthorized`, which is the
// code the Apple Music API answers with for a request it will not authenticate, and which is what a
// caller has to act on: it is the difference between "try again" and "there is nothing here to try".

import Foundation

/// The host the Apple Music API answers on. A request that names another host is not an Apple Music
/// request, and this module will not send one.
public enum MusicAPIs {
    public static let host = "https://api.music.apple.com"

    /// A path under the catalogue of a storefront, which is what every request in this module is.
    public static func catalogURL(storefront: String, path: String) -> URL? {
        URL(string: "\(host)/v1/catalog/\(storefront)/\(path)")
    }
}

/// The errors this module answers, which are the Apple Music API's own.
public enum MusicError: Error {
    /// No developer token, or one the service will not accept: HTTP 401 and 403.
    case developerTokenUnauthorized
    /// The service answered, and not with a success: the status it gave.
    case unexpectedStatus(Int)
    /// The answer was not the JSON this module reads.
    case malformedResponse
    /// The request itself could not be made.
    case transport(Error)
}

/// The developer token, and where it comes from.
public enum MusicDeveloperToken {

    /// The key a client of the Apple Music API is given: a `.p8` in the bundle or the PEM
    /// under the Info.plist key Apple's own tooling writes, its identifier, and the team it is from.
    /// The token is signed once and kept until shortly before the hour it is good for.
    public static var developerToken: String?

    /// The token the requests go out with, or nil when the application has not given one. A token
    /// minted elsewhere - by a server, or by a build of this application that already had one - is
    /// handed straight over, and is what every request in this module is authenticated with.
    public static var current: String? {
        get { developerToken }
        set { developerToken = newValue }
    }

    /// Mint a token from a web services authentication key, or answer nil when there is none.
    ///
    /// The payload is the three members Apple's own format names - the team, the time the token was
    /// made and the hour it is good for - and the signature is ES256 over the header and the payload,
    /// which is `charon@micro-ecc` through the shim above: the same curve work the CloudKit family
    /// does, and one implementation of it.
    ///
    /// All three parts are base64url, and the signature is over the *encoded* first two joined by a
    /// dot, because that is what a JOSE verifier hashes. The first version of this returned the header
    /// and the payload as the JSON text and encoded only the signature, which is a dot-joined string
    /// no verifier will read; tests/backports/host/musickit/run.sh is what found it, and it could only
    /// find it because that run had never been able to reach its own checker.
    ///
    /// The base64url is this module's own rather than `Data.base64EncodedString(options:)`, which
    /// this release's Swift Foundation overlay marks iOS 7. The port's headers lower the availability of
    /// the Objective-C headers, where the backports put their marks, and not the Swift overlay's own,
    /// so that mark is still there with the port's headers applied. A JOSE token's three parts are base64url of
    /// bytes this module already has; encoding them is not a place to wait for a Foundation.
    public static func mint(keyIdentifier: String, teamIdentifier: String, privateKeyPEM: String) -> String? {
        // The key is a .p8, which is a PEM, and micro-ecc signs with the 32 bytes inside it. So the
        // body is decoded here, where the base64 table already is, and the shim is handed the DER.
        // The first version passed the PEM's own text where the scalar belonged, and the end-to-end
        // check answered "Error Verifying Data" over a signature of the wrong bytes entirely.
        guard let key = CharonBase64URL.decode(CharonBase64URL.pemBody(privateKeyPEM)),
              key.count > 0 else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        let header = #"{"alg":"ES256","kid":"\#(keyIdentifier)"}"#
        let payload = #"{"iss":"\#(teamIdentifier)","iat":\#(now),"exp":\#(now + 3600)}"#
        // The three parts of a JOSE token are base64url of the bytes, and the signature is over the
        // encoded first two joined by a dot - not over the JSON text, which is what the first version
        // of this signed and returned, so what it minted was not a token at all.
        let encodedHeader = CharonBase64URL.encode(Data(header.utf8))
        let encodedPayload = CharonBase64URL.encode(Data(payload.utf8))
        let signing = "\(encodedHeader).\(encodedPayload)"
        let message = Array(signing.utf8)
        var der = [UInt8](repeating: 0, count: 72)
        let keyBytes = Array(key)
        let length = keyBytes.withUnsafeBufferPointer { privateKey in
            message.withUnsafeBufferPointer { body in
                CharonMusicKitSignES256(privateKey.baseAddress, privateKey.count,
                                       body.baseAddress, body.count, &der, der.count)
            }
        }
        guard length > 0 else { return nil }
        return "\(signing).\(CharonBase64URL.encode(Data(der[0..<Int(length)])))"
    }
}

/// Base64url without the padding, which is what a JOSE token is made of.
enum CharonBase64URL {
    /// The base64 body of a PEM, or nil when the text carries no such pair of lines. A .p8 is
    /// "-----BEGIN PRIVATE KEY-----" and its end line, and what is between them is the DER; the line
    /// breaks inside are the writer's, not the key's, and the decoder skips them.
    static func pemBody(_ pem: String) -> String {
        guard let begin = pem.range(of: "-----BEGIN"),
              let end = pem.range(of: "-----END", range: begin.upperBound ..< pem.endIndex) else {
            return ""
        }
        let afterHeader = pem[begin.upperBound...].drop(while: { $0 != "\n" })
        return String(afterHeader[..<end.lowerBound].filter { !$0.isWhitespace })
    }

    /// The one value of a base64 character in either alphabet, or nil for what is not one. A .p8 is
    /// standard base64 and a JOSE part is base64url; the two characters that differ are each other's
    /// alias here, so one reader serves both and neither has to be told which it has.
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

    /// The inverse of `encode`, and the reason a .p8 can be read at all: the module has the table,
    /// so the decoder is the other direction of the same one.
    static func decode(_ text: String) -> Data? {
        var out = Data()
        out.reserveCapacity(text.count * 3 / 4)
        var buffer: UInt32 = 0
        var bits = 0
        for byte in Array(text.utf8) {
            if byte == UInt8(ascii: "=") { break }         // the padding ends the body
            guard let value = value(of: byte) else { continue }   // a line break, or a space
            buffer = (buffer << 6) | UInt32(value)
            bits += 6
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> UInt32(bits)) & 0xFF))
            }
        }
        return out.isEmpty ? nil : out
    }

    /// The table and the three output steps: the alphabet without the two characters that need
    /// escaping in a URL, and no padding.
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
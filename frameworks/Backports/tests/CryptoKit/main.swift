#if !REVENANT_BACKPORT
import CryptoKit
#endif
import Foundation

func hex(_ bytes: some Sequence<UInt8>) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func pattern(_ count: Int, _ seed: UInt8) -> Data {
    Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ Int(seed)) })
}

let messages: [Data] = [Data(), Data("abc".utf8), pattern(55, 1), pattern(56, 2), pattern(64, 3), pattern(65, 4), pattern(128, 5), pattern(1000, 6), pattern(200_003, 7)]

for message in messages {
    print("sha256 \(message.count) \(SHA256.hash(data: message).description)")
    print("sha384 \(message.count) \(SHA384.hash(data: message).description)")
    print("sha512 \(message.count) \(SHA512.hash(data: message).description)")
}

var incremental = SHA256()
incremental.update(data: pattern(70, 8))
incremental.update(data: pattern(130, 9))
var joined = pattern(70, 8)
joined.append(pattern(130, 9))
print("incremental \(incremental.finalize().description == SHA256.hash(data: joined).description)")

print("digest sizes \(SHA256.byteCount) \(SHA256.blockByteCount) \(SHA384.byteCount) \(SHA384.blockByteCount) \(SHA512.byteCount) \(SHA512.blockByteCount)")
let sha256Size: Int = SHA256Digest.byteCount
let sha512Count: Int = Array(SHA512.hash(data: Data())).count
print("digest sizes of values \(sha256Size) \(sha512Count)")
print("digest equality \(SHA256.hash(data: Data("abc".utf8)) == SHA256.hash(data: Data("abc".utf8))) \(SHA256.hash(data: Data("abc".utf8)) == Data("abc".utf8))")

let keys: [Data] = [Data(), pattern(16, 10), pattern(64, 11), pattern(200, 12)]
for key in keys {
    for message in [Data(), pattern(17, 13), pattern(300, 14)] {
        let symmetric = SymmetricKey(data: key)
        print("hmac256 \(key.count) \(message.count) \(HMAC<SHA256>.authenticationCode(for: message, using: symmetric).description)")
        print("hmac384 \(key.count) \(message.count) \(HMAC<SHA384>.authenticationCode(for: message, using: symmetric).description)")
        print("hmac512 \(key.count) \(message.count) \(HMAC<SHA512>.authenticationCode(for: message, using: symmetric).description)")
        var streaming = HMAC<SHA256>(key: symmetric)
        streaming.update(data: message.prefix(3))
        streaming.update(data: message.dropFirst(3))
        let code = streaming.finalize()
        print("hmac stream \(key.count) \(message.count) \(code.description == HMAC<SHA256>.authenticationCode(for: message, using: symmetric).description)")
        print("hmac valid \(HMAC<SHA256>.isValidAuthenticationCode(code, authenticating: message, using: symmetric)) \(HMAC<SHA256>.isValidAuthenticationCode(code, authenticating: message + Data([0]), using: symmetric))")
    }
}

for size in [SymmetricKeySize.bits128, SymmetricKeySize.bits192, SymmetricKeySize.bits256] {
    let key = SymmetricKey(size: size)
    print("size \(size.bitCount) \(key.bitCount) \(key.withUnsafeBytes { $0.count })")
}
print("symmetric equality \(SymmetricKey(data: Data([1, 2])) == SymmetricKey(data: Data([1, 2]))) \(SymmetricKey(data: Data([1, 2])) == SymmetricKey(data: Data([1, 3])))")
print("symmetric bits \(SymmetricKey(data: pattern(24, 15)).bitCount)")

let gcmKeys: [Data] = [pattern(16, 20), pattern(24, 21), pattern(32, 22)]
let gcmNonce = try! AES.GCM.Nonce(data: pattern(12, 23))
let plaintexts: [Data] = [Data(), Data([0x41]), pattern(15, 24), pattern(16, 25), pattern(17, 26), pattern(31, 27), pattern(32, 28), pattern(33, 29), pattern(100, 30)]
let aads: [Data] = [Data(), Data([1]), pattern(16, 31), pattern(20, 32), pattern(33, 33)]
for key in gcmKeys {
    for plaintext in plaintexts {
        for aad in aads {
            let box = try! AES.GCM.seal(plaintext, using: SymmetricKey(data: key), nonce: gcmNonce, authenticating: aad)
            print("gcm \(key.count) \(plaintext.count) \(aad.count) \(hex(box.combined!)) \(box.tag.count) \(box.ciphertext.count)")
            let opened = try! AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
            print("gcm open \(opened == plaintext)")
        }
    }
}

print("gcm without aad \(hex(try! AES.GCM.seal(pattern(40, 34), using: SymmetricKey(data: pattern(16, 35)), nonce: gcmNonce).combined!))")
print("gcm open without aad \(try! AES.GCM.open(try! AES.GCM.seal(pattern(40, 34), using: SymmetricKey(data: pattern(16, 35)), nonce: gcmNonce), using: SymmetricKey(data: pattern(16, 35))) == pattern(40, 34))")

let sealed = try! AES.GCM.seal(Data("secret".utf8), using: SymmetricKey(data: pattern(16, 36)), nonce: gcmNonce, authenticating: Data("aad".utf8))
let tampered = try! AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: sealed.ciphertext, tag: Data(repeating: 0, count: 16))
do {
    _ = try AES.GCM.open(tampered, using: SymmetricKey(data: pattern(16, 36)), authenticating: Data("aad".utf8))
    print("open tampered tag accepted")
} catch {
    print("open tampered tag error \(error)")
}
do {
    _ = try AES.GCM.open(sealed, using: SymmetricKey(data: pattern(16, 36)), authenticating: Data("aaX".utf8))
    print("open wrong aad accepted")
} catch {
    print("open wrong aad error \(error)")
}
do {
    _ = try AES.GCM.open(sealed, using: SymmetricKey(data: pattern(16, 37)))
    print("open wrong key accepted")
} catch {
    print("open wrong key error \(error)")
}
do {
    _ = try AES.GCM.seal(Data(), using: SymmetricKey(data: pattern(15, 38)))
    print("seal bad key accepted")
} catch {
    print("seal bad key error \(error)")
}
do {
    _ = try AES.GCM.Nonce(data: pattern(11, 39))
    print("nonce accepted")
} catch {
    print("nonce error \(error)")
}
do {
    _ = try AES.GCM.SealedBox(combined: pattern(27, 40))
    print("combined accepted")
} catch {
    print("combined error \(error)")
}
let combined = try! AES.GCM.SealedBox(combined: sealed.combined!)
let roundtrip: Bool = combined.combined! == sealed.combined!
let parts: [Int] = [Array(combined.nonce).count, combined.ciphertext.count, combined.tag.count]
print("combined roundtrip \(roundtrip) \(parts)")
do {
    _ = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: Data(), tag: Data(repeating: 0, count: 15))
    print("short tag accepted")
} catch {
    print("short tag error \(error)")
}
print("errors equal \(CryptoKitError.authenticationFailure == CryptoKitError.authenticationFailure) \(CryptoKitError.incorrectKeySize == CryptoKitError.incorrectParameterSize)")

let hkdfKey = SymmetricKey(data: pattern(22, 41))
let hkdfSalt = pattern(13, 42)
let hkdfInfo = pattern(10, 43)
print("hkdf extract \(hex(HKDF<SHA256>.extract(inputKeyMaterial: hkdfKey, salt: hkdfSalt)))")
for length in [1, 31, 32, 33, 64, 100, 255] {
    let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: hkdfKey, salt: hkdfSalt, info: hkdfInfo, outputByteCount: length)
    print("hkdf \(length) \(hex(derived.withUnsafeBytes { Array($0) }))")
}
let rfcKey = SymmetricKey(data: Data(repeating: 0x0b, count: 22))
let rfcSalt = Data((0...12).map { UInt8($0) })
let rfcInfo = Data((0xf0...0xf9).map { UInt8($0) })
let rfcOne = HKDF<SHA256>.deriveKey(inputKeyMaterial: rfcKey, salt: rfcSalt, info: rfcInfo, outputByteCount: 42)
print("hkdf rfc5869 1 \(hex(rfcOne.withUnsafeBytes { Array($0) }) == "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")")
let rfcThree = HKDF<SHA256>.deriveKey(inputKeyMaterial: rfcKey, outputByteCount: 42)
print("hkdf rfc5869 3 \(hex(rfcThree.withUnsafeBytes { Array($0) }) == "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8")")

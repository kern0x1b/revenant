import CryptoKit
import Foundation

var failures = 0

func hex(_ bytes: some Sequence<UInt8>) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func bytes(hex text: String) -> [UInt8] {
    var result = [UInt8]()
    var index = text.startIndex
    while index < text.endIndex {
        let next = text.index(index, offsetBy: 2)
        result.append(UInt8(text[index..<next], radix: 16)!)
        index = next
    }
    return result
}

func check(_ name: String, _ got: String, _ expected: String) {
    if got == expected {
        print("\(name) true")
    } else {
        failures += 1
        print("\(name) false got=\(got) expected=\(expected)")
    }
}

func check(_ name: String, _ condition: Bool) {
    if condition {
        print("\(name) true")
    } else {
        failures += 1
        print("\(name) false")
    }
}

let abc = Data("abc".utf8)

check("sha256 abc", hex(SHA256.hash(data: abc)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
check("sha256 empty", hex(SHA256.hash(data: Data())), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
check("sha384 abc", hex(SHA384.hash(data: abc)), "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7")
check("sha512 abc", hex(SHA512.hash(data: abc)), "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
check("sha3-256 abc", hex(SHA3_256.hash(data: abc)), "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
check("sha3-256 empty", hex(SHA3_256.hash(data: Data())), "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
check("sha1 abc", hex(Insecure.SHA1.hash(data: abc)), "a9993e364706816aba3e25717850c26c9cd0d89d")
check("md5 abc", hex(Insecure.MD5.hash(data: abc)), "900150983cd24fb0d6963f7d28e17f72")

let hmacKey1 = SymmetricKey(data: Data(repeating: 0x0b, count: 20))
check("hmac-sha256 rfc4231 case 1", hex(HMAC<SHA256>.authenticationCode(for: Data("Hi There".utf8), using: hmacKey1)),
      "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
let hmacKey2 = SymmetricKey(data: Data("Jefe".utf8))
check("hmac-sha256 rfc4231 case 2", hex(HMAC<SHA256>.authenticationCode(for: Data("what do ya want for nothing?".utf8), using: hmacKey2)),
      "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")

func hkdf(ikm: [UInt8], salt: [UInt8], info: [UInt8], count: Int) -> String {
    let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(ikm)), salt: Data(salt), info: Data(info), outputByteCount: count)
    return key.withUnsafeBytes { hex($0) }
}

check("hkdf-sha256 rfc5869 case 1", hkdf(ikm: [UInt8](repeating: 0x0b, count: 22), salt: bytes(hex: "000102030405060708090a0b0c"),
      info: bytes(hex: "f0f1f2f3f4f5f6f7f8f9"), count: 42),
      "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")
check("hkdf-sha256 rfc5869 case 3", hkdf(ikm: [UInt8](repeating: 0x0b, count: 22), salt: [], info: [], count: 42),
      "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8")

let zeroKey128 = SymmetricKey(data: Data(repeating: 0, count: 16))
let zeroKey256 = SymmetricKey(data: Data(repeating: 0, count: 32))
let zeroNonce = try! AES.GCM.Nonce(data: Data(repeating: 0, count: 12))
let zeroBlock = Data(repeating: 0, count: 16)

let gcm128 = try! AES.GCM.seal(zeroBlock, using: zeroKey128, nonce: zeroNonce)
check("aes-128-gcm gcm-spec case 2 ciphertext", hex(gcm128.ciphertext), "0388dace60b6a392f328c2b971b2fe78")
check("aes-128-gcm gcm-spec case 2 tag", hex(gcm128.tag), "ab6e47d42cec13bdf53a67b21257bddf")

let gcm256 = try! AES.GCM.seal(zeroBlock, using: zeroKey256, nonce: zeroNonce)
check("aes-256-gcm gcm-spec case 14 ciphertext", hex(gcm256.ciphertext), "cea7403d4d606b6e074ec5d3baf39d18")
check("aes-256-gcm gcm-spec case 14 tag", hex(gcm256.tag), "d0d1c8a799996bf0265b98b5d48ab919")

let gcmOpened = try! AES.GCM.open(gcm256, using: zeroKey256)
check("aes-256-gcm open round trip", gcmOpened == zeroBlock)

var tampered = gcm256
tampered = try! AES.GCM.SealedBox(nonce: zeroNonce, ciphertext: Data(repeating: 1, count: 16), tag: gcm256.tag)
var rejected = false
do {
    _ = try AES.GCM.open(tampered, using: zeroKey256)
} catch {
    rejected = true
}
check("aes-256-gcm rejects a forged ciphertext", rejected)

let chachaKey = SymmetricKey(data: bytes(hex: "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"))
let chachaNonce = try! ChaChaPoly.Nonce(data: bytes(hex: "070000004041424344454647"))
let chachaAAD = Data(bytes(hex: "50515253c0c1c2c3c4c5c6c7"))
let chachaPlain = Data("Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.".utf8)
let chachaBox = try! ChaChaPoly.seal(chachaPlain, using: chachaKey, nonce: chachaNonce, authenticating: chachaAAD)
check("chacha20-poly1305 rfc8439 2.8.2 tag", hex(chachaBox.tag), "1ae10b594f09e26a7e902ecbd0600691")
check("chacha20-poly1305 open round trip", (try? ChaChaPoly.open(chachaBox, using: chachaKey, authenticating: chachaAAD)) == chachaPlain)

let alicePrivate = try! Curve25519.KeyAgreement.PrivateKey(rawRepresentation: bytes(hex: "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
let bobPrivate = try! Curve25519.KeyAgreement.PrivateKey(rawRepresentation: bytes(hex: "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"))
check("x25519 rfc7748 6.1 alice public", hex(alicePrivate.publicKey.rawRepresentation), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
check("x25519 rfc7748 6.1 bob public", hex(bobPrivate.publicKey.rawRepresentation), "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")
let aliceShared = try! alicePrivate.sharedSecretFromKeyAgreement(with: bobPrivate.publicKey)
check("x25519 rfc7748 6.1 shared secret", aliceShared.withUnsafeBytes { hex($0) },
      "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")

let p256Alice = P256.KeyAgreement.PrivateKey()
let p256Bob = P256.KeyAgreement.PrivateKey()
let p256Secret = try! p256Alice.sharedSecretFromKeyAgreement(with: p256Bob.publicKey)
let p256Other = try! p256Bob.sharedSecretFromKeyAgreement(with: p256Alice.publicKey)
check("p256 ecdh agreement", p256Secret.withUnsafeBytes { hex($0) } == p256Other.withUnsafeBytes { hex($0) })

let signing = P256.Signing.PrivateKey()
let signature = try! signing.signature(for: abc)
check("p256 ecdsa verifies its signature", signing.publicKey.isValidSignature(signature, for: abc))
check("p256 ecdsa rejects another message", !signing.publicKey.isValidSignature(signature, for: Data("abd".utf8)))

let generated = SymmetricKey(size: .bits256)
check("symmetric key size", generated.bitCount == 256)

if failures > 0 {
    print("failures \(failures)")
    exit(1)
}
print("all true")

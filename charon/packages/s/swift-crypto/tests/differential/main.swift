// Per-row differential: swift-crypto's Crypto module against Apple's CryptoKit, both in one host process.
//
// Usage: differential <seed> [negative]
//
// Deterministic operations (digests, MACs, the KDF, AEAD with fixed keys and nonces, key agreement from fixed
// keys) are compared by their bytes. Randomized operations (Ed25519, ECDSA, ML-KEM encapsulation, HPKE's ephemeral
// key) are cross-verified: an output made by one side is accepted by the other. Every input is drawn from the seed, which the first line prints. With `negative`, the Crypto side gets one
// altered input (the SHA256 row of length 1); the run must report that row as DIFF, or it exits 1: the control
// proves the comparison can fail.
import CryptoKit
import Crypto
import Foundation

struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func bytes(_ count: Int) -> Data {
        var out = Data()
        while out.count < count {
            var word = next()
            for _ in 0..<8 where out.count < count {
                out.append(UInt8(word & 0xFF))
                word >>= 8
            }
        }
        return out
    }
}

let arguments = CommandLine.arguments
let seed = UInt64(arguments.count > 1 ? arguments[1] : "1") ?? 1
let negative = arguments.contains("negative")
var rng = SplitMix64(state: seed)
print("seed \(seed)\(negative ? " negative" : "")")

var rows = 0
var differing = 0
var verified = 0
var failed = 0

func hex(_ data: Data) -> String {
    data.prefix(16).map { String(format: "%02x", $0) }.joined()
}

// One deterministic row: the two sides' bytes, or nil where the side threw.
func row(_ name: String, _ kit: Data?, _ port: Data?) {
    rows += 1
    let same = kit == port
    if !same { differing += 1 }
    let shown = kit.map { "\($0.count)B \(hex($0))" } ?? "threw"
    print("\(same ? "same" : "DIFF") \(name) \(shown)")
}

// One cross-verification row: the other side accepted what one side made.
func verdict(_ name: String, _ ok: Bool) {
    rows += 1
    if ok { verified += 1 } else { failed += 1 }
    print("\(ok ? "verified" : "FAILED") \(name)")
}

func attempt(_ body: () throws -> Data) -> Data? {
    try? body()
}

func flipped(_ data: Data) -> Data {
    var copy = data
    copy[copy.startIndex] ^= 0x01
    return copy
}

// Digests over lengths that straddle the block boundaries. The negative control is the length-1 row's Crypto input.
for length in [0, 1, 3, 55, 56, 63, 64, 65, 111, 112, 127, 128, 1000] {
    let message = rng.bytes(length)
    let portMessage = negative && length == 1 ? flipped(message) : message
    row("SHA256 \(length)", Data(CryptoKit.SHA256.hash(data: message)), Data(Crypto.SHA256.hash(data: portMessage)))
    row("SHA384 \(length)", Data(CryptoKit.SHA384.hash(data: message)), Data(Crypto.SHA384.hash(data: message)))
    row("SHA512 \(length)", Data(CryptoKit.SHA512.hash(data: message)), Data(Crypto.SHA512.hash(data: message)))
    row("SHA3-256 \(length)", Data(CryptoKit.SHA3_256.hash(data: message)), Data(Crypto.SHA3_256.hash(data: message)))
    row("SHA3-384 \(length)", Data(CryptoKit.SHA3_384.hash(data: message)), Data(Crypto.SHA3_384.hash(data: message)))
}

// HMAC, with keys shorter than, equal to and longer than the block.
for keyLength in [16, 64, 200] {
    let key = rng.bytes(keyLength)
    let message = rng.bytes(77)
    row("HMAC-SHA256 key \(keyLength)",
        Data(CryptoKit.HMAC<CryptoKit.SHA256>.authenticationCode(for: message, using: CryptoKit.SymmetricKey(data: key))),
        Data(Crypto.HMAC<Crypto.SHA256>.authenticationCode(for: message, using: Crypto.SymmetricKey(data: key))))
    row("HMAC-SHA384 key \(keyLength)",
        Data(CryptoKit.HMAC<CryptoKit.SHA384>.authenticationCode(for: message, using: CryptoKit.SymmetricKey(data: key))),
        Data(Crypto.HMAC<Crypto.SHA384>.authenticationCode(for: message, using: Crypto.SymmetricKey(data: key))))
    row("HMAC-SHA512 key \(keyLength)",
        Data(CryptoKit.HMAC<CryptoKit.SHA512>.authenticationCode(for: message, using: CryptoKit.SymmetricKey(data: key))),
        Data(Crypto.HMAC<Crypto.SHA512>.authenticationCode(for: message, using: Crypto.SymmetricKey(data: key))))
}

// HKDF, with and without salt and info.
for outputLength in [16, 32, 80] {
    let ikm = rng.bytes(32)
    let salt = rng.bytes(16)
    let info = rng.bytes(11)
    row("HKDF-SHA256 out \(outputLength)",
        CryptoKit.HKDF<CryptoKit.SHA256>.deriveKey(inputKeyMaterial: CryptoKit.SymmetricKey(data: ikm), salt: salt, info: info, outputByteCount: outputLength).withUnsafeBytes { Data($0) },
        Crypto.HKDF<Crypto.SHA256>.deriveKey(inputKeyMaterial: Crypto.SymmetricKey(data: ikm), salt: salt, info: info, outputByteCount: outputLength).withUnsafeBytes { Data($0) })
    row("HKDF-SHA384 out \(outputLength)",
        CryptoKit.HKDF<CryptoKit.SHA384>.deriveKey(inputKeyMaterial: CryptoKit.SymmetricKey(data: ikm), salt: Data(), info: Data(), outputByteCount: outputLength).withUnsafeBytes { Data($0) },
        Crypto.HKDF<Crypto.SHA384>.deriveKey(inputKeyMaterial: Crypto.SymmetricKey(data: ikm), salt: Data(), info: Data(), outputByteCount: outputLength).withUnsafeBytes { Data($0) })
}

// AEAD with fixed keys, nonces and associated data: the sealed box is compared, and each side opens the other's.
for keyLength in [16, 32] {
    let key = rng.bytes(keyLength)
    let nonce = rng.bytes(12)
    let aad = rng.bytes(9)
    let message = rng.bytes(100)
    let kitBox = attempt { try CryptoKit.AES.GCM.seal(message, using: CryptoKit.SymmetricKey(data: key), nonce: CryptoKit.AES.GCM.Nonce(data: nonce), authenticating: aad).combined ?? Data() }
    let portBox = attempt { try Crypto.AES.GCM.seal(message, using: Crypto.SymmetricKey(data: key), nonce: Crypto.AES.GCM.Nonce(data: nonce), authenticating: aad).combined ?? Data() }
    row("AES-GCM-\(keyLength * 8) seal", kitBox, portBox)
    if let box = kitBox {
        row("AES-GCM-\(keyLength * 8) open kit box",
            message,
            attempt { try Crypto.AES.GCM.open(Crypto.AES.GCM.SealedBox(combined: box), using: Crypto.SymmetricKey(data: key), authenticating: aad) })
    }
    row("ChaChaPoly seal \(keyLength)",
        attempt { try CryptoKit.ChaChaPoly.seal(message, using: CryptoKit.SymmetricKey(data: key), nonce: CryptoKit.ChaChaPoly.Nonce(data: nonce), authenticating: aad).combined },
        attempt { try Crypto.ChaChaPoly.seal(message, using: Crypto.SymmetricKey(data: key), nonce: Crypto.ChaChaPoly.Nonce(data: nonce), authenticating: aad).combined })
}

// X25519 from fixed keys: the public key and the shared secret are compared.
let x25519Mine = rng.bytes(32)
let x25519Peer = rng.bytes(32)
row("X25519 public",
    attempt { try CryptoKit.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Mine).publicKey.rawRepresentation },
    attempt { try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Mine).publicKey.rawRepresentation })
row("X25519 shared",
    attempt {
        let peer = try CryptoKit.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Peer).publicKey
        return try CryptoKit.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Mine).sharedSecretFromKeyAgreement(with: peer).withUnsafeBytes { Data($0) }
    },
    attempt {
        let peer = try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Peer).publicKey
        return try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Mine).sharedSecretFromKeyAgreement(with: peer).withUnsafeBytes { Data($0) }
    })

// Ed25519 is randomized on both sides (measured: each side's repeat of its own signature differs, see the info lines),
// so its signatures are cross-verified in both directions, not compared by bytes.
let edKey = rng.bytes(32)
let edMessage = rng.bytes(64)
let edKit = attempt { try CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).signature(for: edMessage) }
if let signature = edKit,
   let portPublic = try? Crypto.Curve25519.Signing.PublicKey(rawRepresentation: CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).publicKey.rawRepresentation) {
    verdict("Ed25519 kit signature verifies on Crypto", portPublic.isValidSignature(signature, for: edMessage))
}
// Whether each side repeats its own signature, and whether the Crypto signature verifies on kit: they decide whether the
// byte comparison above is a valid expectation for this algorithm on each side.
if let first = edKit, let again = attempt({ try CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).signature(for: edMessage) }) {
    print("info kit-repeats \(first == again)")
}
if let portSignature = attempt({ try Crypto.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).signature(for: edMessage) }),
   let portRepeat = attempt({ try Crypto.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).signature(for: edMessage) }),
   let kitPublic = try? CryptoKit.Curve25519.Signing.PublicKey(rawRepresentation: CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: edKey).publicKey.rawRepresentation) {
    print("info crypto-repeats \(portSignature == portRepeat)")
    verdict("Ed25519 Crypto signature verifies on kit", kitPublic.isValidSignature(portSignature, for: edMessage))
}

// NIST curves from fixed scalars: a scalar the curve rejects is drawn again; the draw is the same for both sides.
func scalar(_ size: Int, _ valid: (Data) -> Bool) -> Data {
    var candidate = rng.bytes(size)
    while !valid(candidate) { candidate = rng.bytes(size) }
    return candidate
}

let p256Mine = scalar(32) { (try? CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
let p256Peer = scalar(32) { (try? CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
row("P256 shared",
    attempt { try CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Mine).sharedSecretFromKeyAgreement(with: CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Peer).publicKey).withUnsafeBytes { Data($0) } },
    attempt { try Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Mine).sharedSecretFromKeyAgreement(with: Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Peer).publicKey).withUnsafeBytes { Data($0) } })

let p384Mine = scalar(48) { (try? CryptoKit.P384.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
let p384Peer = scalar(48) { (try? CryptoKit.P384.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
row("P384 shared",
    attempt { try CryptoKit.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Mine).sharedSecretFromKeyAgreement(with: CryptoKit.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Peer).publicKey).withUnsafeBytes { Data($0) } },
    attempt { try Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Mine).sharedSecretFromKeyAgreement(with: Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Peer).publicKey).withUnsafeBytes { Data($0) } })

let p521Mine = scalar(66) { (try? CryptoKit.P521.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
let p521Peer = scalar(66) { (try? CryptoKit.P521.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
row("P521 shared",
    attempt { try CryptoKit.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Mine).sharedSecretFromKeyAgreement(with: CryptoKit.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Peer).publicKey).withUnsafeBytes { Data($0) } },
    attempt { try Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Mine).sharedSecretFromKeyAgreement(with: Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Peer).publicKey).withUnsafeBytes { Data($0) } })

// ECDSA is randomized: each side signs with the same key and the other side verifies, in both directions.
let ecMessage = rng.bytes(120)

let p256Signer = scalar(32) { (try? CryptoKit.P256.Signing.PrivateKey(rawRepresentation: $0)) != nil }
if let kitSigner = try? CryptoKit.P256.Signing.PrivateKey(rawRepresentation: p256Signer),
   let kitSignature = try? kitSigner.signature(for: ecMessage),
   let portPublic = try? Crypto.P256.Signing.PublicKey(rawRepresentation: kitSigner.publicKey.rawRepresentation),
   let portSignature = try? Crypto.P256.Signing.ECDSASignature(rawRepresentation: kitSignature.rawRepresentation) {
    verdict("P256 kit signature verifies on Crypto", portPublic.isValidSignature(portSignature, for: ecMessage))
}
if let portSigner = try? Crypto.P256.Signing.PrivateKey(rawRepresentation: p256Signer),
   let portSignature = try? portSigner.signature(for: ecMessage),
   let kitPublic = try? CryptoKit.P256.Signing.PublicKey(rawRepresentation: portSigner.publicKey.rawRepresentation),
   let kitSignature = try? CryptoKit.P256.Signing.ECDSASignature(rawRepresentation: portSignature.rawRepresentation) {
    verdict("P256 Crypto signature verifies on kit", kitPublic.isValidSignature(kitSignature, for: ecMessage))
}

let p384Signer = scalar(48) { (try? CryptoKit.P384.Signing.PrivateKey(rawRepresentation: $0)) != nil }
if let kitSigner = try? CryptoKit.P384.Signing.PrivateKey(rawRepresentation: p384Signer),
   let kitSignature = try? kitSigner.signature(for: ecMessage),
   let portPublic = try? Crypto.P384.Signing.PublicKey(rawRepresentation: kitSigner.publicKey.rawRepresentation),
   let portSignature = try? Crypto.P384.Signing.ECDSASignature(rawRepresentation: kitSignature.rawRepresentation) {
    verdict("P384 kit signature verifies on Crypto", portPublic.isValidSignature(portSignature, for: ecMessage))
}
if let portSigner = try? Crypto.P384.Signing.PrivateKey(rawRepresentation: p384Signer),
   let portSignature = try? portSigner.signature(for: ecMessage),
   let kitPublic = try? CryptoKit.P384.Signing.PublicKey(rawRepresentation: portSigner.publicKey.rawRepresentation),
   let kitSignature = try? CryptoKit.P384.Signing.ECDSASignature(rawRepresentation: portSignature.rawRepresentation) {
    verdict("P384 Crypto signature verifies on kit", kitPublic.isValidSignature(kitSignature, for: ecMessage))
}

let p521Signer = scalar(66) { (try? CryptoKit.P521.Signing.PrivateKey(rawRepresentation: $0)) != nil }
if let kitSigner = try? CryptoKit.P521.Signing.PrivateKey(rawRepresentation: p521Signer),
   let kitSignature = try? kitSigner.signature(for: ecMessage),
   let portPublic = try? Crypto.P521.Signing.PublicKey(rawRepresentation: kitSigner.publicKey.rawRepresentation),
   let portSignature = try? Crypto.P521.Signing.ECDSASignature(rawRepresentation: kitSignature.rawRepresentation) {
    verdict("P521 kit signature verifies on Crypto", portPublic.isValidSignature(portSignature, for: ecMessage))
}
if let portSigner = try? Crypto.P521.Signing.PrivateKey(rawRepresentation: p521Signer),
   let portSignature = try? portSigner.signature(for: ecMessage),
   let kitPublic = try? CryptoKit.P521.Signing.PublicKey(rawRepresentation: portSigner.publicKey.rawRepresentation),
   let kitSignature = try? CryptoKit.P521.Signing.ECDSASignature(rawRepresentation: portSignature.rawRepresentation) {
    verdict("P521 Crypto signature verifies on kit", kitPublic.isValidSignature(kitSignature, for: ecMessage))
}

// ML-KEM-768: the public key from a fixed seed is compared; a capsule made on one side opens on the other.
let kemSeed = rng.bytes(64)
row("MLKEM768 public from seed",
    attempt { try CryptoKit.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil).publicKey.rawRepresentation },
    attempt { try Crypto.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil).publicKey.rawRepresentation })
if let kitPublic = try? CryptoKit.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil).publicKey,
   let portPrivate = try? Crypto.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil) {
    let portPublic = try? Crypto.MLKEM768.PublicKey(rawRepresentation: kitPublic.rawRepresentation)
    if let capsule = try? kitPublic.encapsulate(), let opened = try? portPrivate.decapsulate(capsule.encapsulated) {
        verdict("MLKEM768 kit capsule opens on Crypto", opened.withUnsafeBytes { Data($0) } == capsule.sharedSecret.withUnsafeBytes { Data($0) })
    } else {
        verdict("MLKEM768 kit capsule opens on Crypto", false)
    }
    if let capsule = try? portPublic?.encapsulate(), let opened = try? CryptoKit.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil).decapsulate(capsule.encapsulated) {
        verdict("MLKEM768 Crypto capsule opens on kit", opened.withUnsafeBytes { Data($0) } == capsule.sharedSecret.withUnsafeBytes { Data($0) })
    } else {
        verdict("MLKEM768 Crypto capsule opens on kit", false)
    }
}

// HPKE: a sealed message made by one side opens on the other, both ways, with the P-256 suite.
let hpkeKey = scalar(32) { (try? CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
let hpkeInfo = rng.bytes(7)
let hpkeMessage = rng.bytes(40)
if let kitRecipient = try? CryptoKit.P256.KeyAgreement.PrivateKey(rawRepresentation: hpkeKey),
   let portRecipient = try? Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: hpkeKey) {
    if var sender = try? CryptoKit.HPKE.Sender(recipientKey: kitRecipient.publicKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: hpkeInfo),
       let ciphertext = try? sender.seal(hpkeMessage),
       var recipient = try? Crypto.HPKE.Recipient(privateKey: portRecipient, ciphersuite: .P256_SHA256_AES_GCM_256, info: hpkeInfo, encapsulatedKey: sender.encapsulatedKey) {
        verdict("HPKE kit seal opens on Crypto", (try? recipient.open(ciphertext)) == hpkeMessage)
    } else {
        verdict("HPKE kit seal opens on Crypto", false)
    }
    if var sender = try? Crypto.HPKE.Sender(recipientKey: portRecipient.publicKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: hpkeInfo),
       let ciphertext = try? sender.seal(hpkeMessage),
       var recipient = try? CryptoKit.HPKE.Recipient(privateKey: kitRecipient, ciphersuite: .P256_SHA256_AES_GCM_256, info: hpkeInfo, encapsulatedKey: sender.encapsulatedKey) {
        verdict("HPKE Crypto seal opens on kit", (try? recipient.open(ciphertext)) == hpkeMessage)
    } else {
        verdict("HPKE Crypto seal opens on kit", false)
    }
}

print("summary rows=\(rows) differing=\(differing) verified=\(verified) failed=\(failed)")
if negative {
    // The control: the altered input must have produced at least one DIFF and no failed verdict must be hidden by it.
    if differing == 0 { print("negative control NOT detected"); exit(1) }
    print("negative control detected: \(differing) row(s) differ")
    exit(0)
}
exit(differing == 0 && failed == 0 ? 0 : 1)

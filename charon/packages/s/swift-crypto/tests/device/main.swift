// The armv7 probe of swift-crypto, and its host twin. One source: on the device it is linked against the installed
// libswiftCrypto.dylib; on the host it is compiled with `-module-alias Crypto=CryptoKit`, so every `Crypto.` name is
// Apple's CryptoKit there. The host run is therefore the host's answers, and the device run is the module under test.
//
// Modes (every output line starts with "P| " so a log is filtered with grep):
//   rows [seed] [negative] [nohmac]  deterministic rows, full bytes: digests, MACs, KDF, AEAD with fixed keys and nonces,
//                                    key agreement from fixed keys, ML-KEM public key from a fixed seed, ECDSA DER encode and
//                                    round trip (the decoder and encoder of P-256/384/521), DH-HKDF from the agreed secrets.
//                                    With `negative`, the SHA256 input of length 1 is flipped on this side: exactly one row must
//                                    differ from the host. With `nohmac`, the HMAC, HKDF and DH-HKDF rows are skipped on both sides
//                                    (same draws skipped).
//   make                             randomized outputs made from random keys (on the device: the keys come from BoringSSL's
//                                    RNG), one record per line: "rec name|field|...", every field in hex. ECDSA appears twice,
//                                    raw ("ecdsa-pNNN") and DER ("ecdsa-pNNN-der").
//   make-hpke                        the HPKE record of `make`, separately: HPKE derives its keys with HKDF, which is HMAC.
//   verify <hex>                     the records of a `make` run, passed as the hex of their text: each is checked on this side.
//   entropy                          one random P-256 private key, printed: two runs must print different keys.
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

func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    var text = ""
    for byte in bytes {
        text += (byte < 16 ? "0" : "") + String(byte, radix: 16)
    }
    return text
}

func unhex(_ text: Substring) -> Data {
    var out = Data()
    var index = text.startIndex
    while index < text.endIndex {
        let next = text.index(index, offsetBy: 2)
        out.append(UInt8(text[index..<next], radix: 16) ?? 0)
        index = next
    }
    return out
}

func attempt(_ body: () throws -> Data) -> Data? {
    try? body()
}

func flipped(_ data: Data) -> Data {
    var copy = data
    copy[copy.startIndex] ^= 0x01
    return copy
}

func emit(_ line: String) {
    print("P| " + line)
    fflush(stdout)
}

// MARK: rows

func rowsMode(seed: UInt64, negative: Bool, macs: Bool) {
    var rng = SplitMix64(state: seed)
    emit("rows seed \(seed)\(negative ? " negative" : "")\(macs ? "" : " nohmac")")

    func row(_ name: String, _ value: Data?) {
        emit("row \(name) \(value.map { hex($0) } ?? "threw")")
    }

    for length in [0, 1, 3, 55, 56, 63, 64, 65, 111, 112, 127, 128, 1000] {
        let message = rng.bytes(length)
        let input = negative && length == 1 ? flipped(message) : message
        row("SHA256 \(length)", Data(Crypto.SHA256.hash(data: input)))
        row("SHA384 \(length)", Data(Crypto.SHA384.hash(data: message)))
        row("SHA512 \(length)", Data(Crypto.SHA512.hash(data: message)))
        row("SHA3-256 \(length)", Data(Crypto.SHA3_256.hash(data: message)))
        row("SHA3-384 \(length)", Data(Crypto.SHA3_384.hash(data: message)))
    }

    if macs {
        for keyLength in [16, 64, 200] {
            let key = Crypto.SymmetricKey(data: rng.bytes(keyLength))
            let message = rng.bytes(77)
            row("HMAC-SHA256 key \(keyLength)", Data(Crypto.HMAC<Crypto.SHA256>.authenticationCode(for: message, using: key)))
            row("HMAC-SHA384 key \(keyLength)", Data(Crypto.HMAC<Crypto.SHA384>.authenticationCode(for: message, using: key)))
            row("HMAC-SHA512 key \(keyLength)", Data(Crypto.HMAC<Crypto.SHA512>.authenticationCode(for: message, using: key)))
        }

        for outputLength in [16, 32, 80] {
            let ikm = Crypto.SymmetricKey(data: rng.bytes(32))
            let salt = rng.bytes(16)
            let info = rng.bytes(11)
            row("HKDF-SHA256 out \(outputLength)",
                Crypto.HKDF<Crypto.SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: info, outputByteCount: outputLength).withUnsafeBytes { Data($0) })
            row("HKDF-SHA384 out \(outputLength)",
                Crypto.HKDF<Crypto.SHA384>.deriveKey(inputKeyMaterial: ikm, salt: Data(), info: Data(), outputByteCount: outputLength).withUnsafeBytes { Data($0) })
        }
    }

    for keyLength in [16, 32] {
        let key = Crypto.SymmetricKey(data: rng.bytes(keyLength))
        let nonce = try! Crypto.AES.GCM.Nonce(data: rng.bytes(12))
        let aad = rng.bytes(9)
        let message = rng.bytes(100)
        row("AES-GCM-\(keyLength * 8) seal",
            attempt { try Crypto.AES.GCM.seal(message, using: key, nonce: nonce, authenticating: aad).combined ?? Data() })
        let chachaNonce = try! Crypto.ChaChaPoly.Nonce(data: rng.bytes(12))
        row("ChaChaPoly seal \(keyLength)",
            attempt { try Crypto.ChaChaPoly.seal(message, using: key, nonce: chachaNonce, authenticating: aad).combined })
    }

    let mine = rng.bytes(32)
    let peer = rng.bytes(32)
    row("X25519 public", attempt { try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: mine).publicKey.rawRepresentation })
    row("X25519 shared", attempt {
        let other = try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: peer).publicKey
        return try Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: mine).sharedSecretFromKeyAgreement(with: other).withUnsafeBytes { Data($0) }
    })

    // A scalar the curve rejects is drawn again: the draws are the same on both sides, which is what makes the rows comparable.
    func scalar(_ size: Int, _ valid: (Data) -> Bool) -> Data {
        var candidate = rng.bytes(size)
        while !valid(candidate) { candidate = rng.bytes(size) }
        return candidate
    }
    let p256Mine = scalar(32) { (try? Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    let p256Peer = scalar(32) { (try? Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    row("P256 shared", attempt {
        try Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Mine).sharedSecretFromKeyAgreement(
            with: Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Peer).publicKey).withUnsafeBytes { Data($0) }
    })
    let p384Mine = scalar(48) { (try? Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    let p384Peer = scalar(48) { (try? Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    row("P384 shared", attempt {
        try Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Mine).sharedSecretFromKeyAgreement(
            with: Crypto.P384.KeyAgreement.PrivateKey(rawRepresentation: p384Peer).publicKey).withUnsafeBytes { Data($0) }
    })
    let p521Mine = scalar(66) { (try? Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    let p521Peer = scalar(66) { (try? Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: $0)) != nil }
    row("P521 shared", attempt {
        try Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Mine).sharedSecretFromKeyAgreement(
            with: Crypto.P521.KeyAgreement.PrivateKey(rawRepresentation: p521Peer).publicKey).withUnsafeBytes { Data($0) }
    })

    let kemSeed = rng.bytes(64)
    row("MLKEM768 public from seed", attempt { try Crypto.MLKEM768.PrivateKey(seedRepresentation: kemSeed, publicKey: nil).publicKey.rawRepresentation })

    // ECDSA's DER encoder and decoder (the refused sites of P256, P384 and P521 in ECDSA.swift): a drawn raw signature is
    // encoded, and its DER decoded back to raw, on each side. The raw values are not signatures; both sides encode the same bytes.
    let raw256 = rng.bytes(64)
    row("P256 DER encode", attempt { try Crypto.P256.Signing.ECDSASignature(rawRepresentation: raw256).derRepresentation })
    row("P256 DER round trip", attempt {
        try Crypto.P256.Signing.ECDSASignature(derRepresentation: Crypto.P256.Signing.ECDSASignature(rawRepresentation: raw256).derRepresentation).rawRepresentation
    })
    let raw384 = rng.bytes(96)
    row("P384 DER encode", attempt { try Crypto.P384.Signing.ECDSASignature(rawRepresentation: raw384).derRepresentation })
    row("P384 DER round trip", attempt {
        try Crypto.P384.Signing.ECDSASignature(derRepresentation: Crypto.P384.Signing.ECDSASignature(rawRepresentation: raw384).derRepresentation).rawRepresentation
    })
    let raw521 = rng.bytes(132)
    row("P521 DER encode", attempt { try Crypto.P521.Signing.ECDSASignature(rawRepresentation: raw521).derRepresentation })
    row("P521 DER round trip", attempt {
        try Crypto.P521.Signing.ECDSASignature(derRepresentation: Crypto.P521.Signing.ECDSASignature(rawRepresentation: raw521).derRepresentation).rawRepresentation
    })

    // DH's hkdfDerivedSymmetricKey (the refused site in DH.swift): the X25519 and P-256 shared secrets above, through HKDF.
    // HKDF is HMAC, so the rows run only with the HMAC rows.
    if macs {
        let dhSalt = Data(repeating: 0x5a, count: 16)
        let dhInfo = rng.bytes(13)
        let x25519 = try! Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: mine).sharedSecretFromKeyAgreement(
            with: Crypto.Curve25519.KeyAgreement.PrivateKey(rawRepresentation: peer).publicKey)
        let p256 = try! Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Mine).sharedSecretFromKeyAgreement(
            with: Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: p256Peer).publicKey)
        row("DH-HKDF SHA256 X25519", x25519.hkdfDerivedSymmetricKey(using: Crypto.SHA256.self, salt: dhSalt, sharedInfo: dhInfo, outputByteCount: 32).withUnsafeBytes { Data($0) })
        row("DH-HKDF SHA512 X25519", x25519.hkdfDerivedSymmetricKey(using: Crypto.SHA512.self, salt: Data(), sharedInfo: dhInfo, outputByteCount: 64).withUnsafeBytes { Data($0) })
        row("DH-HKDF SHA384 P256", p256.hkdfDerivedSymmetricKey(using: Crypto.SHA384.self, salt: dhSalt, sharedInfo: Data(), outputByteCount: 48).withUnsafeBytes { Data($0) })
    }
}

// MARK: make and verify

// A record is a line "rec name|field|field..." with every field in hex; the verifier reads the same layout, whichever side made it.
func makeMode() {
    var rng = SplitMix64(state: 7)
    let message = rng.bytes(64)
    let ed = Crypto.Curve25519.Signing.PrivateKey()
    emit("rec ed25519|\(hex(ed.publicKey.rawRepresentation))|\(hex(message))|\(hex(try! ed.signature(for: message)))")

    let ecMessage = rng.bytes(120)
    // Each ECDSA signature is emitted twice: raw, and DER (the decoder of the other side reads the DER one).
    let p256 = Crypto.P256.Signing.PrivateKey()
    let p256Signature = try! p256.signature(for: ecMessage)
    emit("rec ecdsa-p256|\(hex(p256.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p256Signature.rawRepresentation))")
    emit("rec ecdsa-p256-der|\(hex(p256.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p256Signature.derRepresentation))")
    let p384 = Crypto.P384.Signing.PrivateKey()
    let p384Signature = try! p384.signature(for: ecMessage)
    emit("rec ecdsa-p384|\(hex(p384.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p384Signature.rawRepresentation))")
    emit("rec ecdsa-p384-der|\(hex(p384.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p384Signature.derRepresentation))")
    let p521 = Crypto.P521.Signing.PrivateKey()
    let p521Signature = try! p521.signature(for: ecMessage)
    emit("rec ecdsa-p521|\(hex(p521.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p521Signature.rawRepresentation))")
    emit("rec ecdsa-p521-der|\(hex(p521.publicKey.rawRepresentation))|\(hex(ecMessage))|\(hex(p521Signature.derRepresentation))")

    let plain = rng.bytes(100)
    let aad = rng.bytes(9)
    let gcmKey = Crypto.SymmetricKey(size: .bits256)
    let gcmBox = try! Crypto.AES.GCM.seal(plain, using: gcmKey, authenticating: aad)
    emit("rec aesgcm-256|\(hex(gcmKey.withUnsafeBytes { Data($0) }))|\(hex(gcmBox.nonce.withUnsafeBytes { Data($0) }))|\(hex(aad))|\(hex(plain))|\(hex(gcmBox.combined!))")
    let chaKey = Crypto.SymmetricKey(size: .bits256)
    let chaBox = try! Crypto.ChaChaPoly.seal(plain, using: chaKey, authenticating: aad)
    emit("rec chachapoly|\(hex(chaKey.withUnsafeBytes { Data($0) }))|\(hex(chaBox.nonce.withUnsafeBytes { Data($0) }))|\(hex(aad))|\(hex(plain))|\(hex(chaBox.combined))")

    let kemPrivate = try! Crypto.MLKEM768.PrivateKey()
    let capsule = try! kemPrivate.publicKey.encapsulate()
    emit("rec mlkem768|\(hex(kemPrivate.seedRepresentation))|\(hex(capsule.encapsulated))|\(hex(capsule.sharedSecret.withUnsafeBytes { Data($0) }))")
}

func hpkeMode() {
    var rng = SplitMix64(state: 11)
    let hpkeRecipient = Crypto.P256.KeyAgreement.PrivateKey()
    let hpkeInfo = rng.bytes(7)
    let hpkePlain = rng.bytes(40)
    var sender = try! Crypto.HPKE.Sender(recipientKey: hpkeRecipient.publicKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: hpkeInfo)
    let hpkeCipher = try! sender.seal(hpkePlain)
    emit("rec hpke-p256|\(hex(hpkeRecipient.rawRepresentation))|\(hex(hpkeInfo))|\(hex(sender.encapsulatedKey))|\(hex(hpkeCipher))|\(hex(hpkePlain))")
}

func verifyMode(_ text: String) {
    var verified = 0
    var failed = 0
    func verdict(_ name: String, _ ok: Bool) {
        if ok { verified += 1 } else { failed += 1 }
        emit("\(ok ? "verified" : "FAILED") \(name)")
    }
    for line in text.split(separator: "\n") {
        guard line.hasPrefix("rec ") else { continue }
        let fields = line.dropFirst(4).split(separator: "|", omittingEmptySubsequences: false).map { Substring($0) }
        guard fields.count >= 2 else { continue }
        let name = String(fields[0])
        let f = fields.dropFirst().map { unhex($0) }
        switch name {
        case "ed25519":
            let ok = (try? Crypto.Curve25519.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(f[2], for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p256":
            let ok = (try? Crypto.P256.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P256.Signing.ECDSASignature(rawRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p384":
            let ok = (try? Crypto.P384.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P384.Signing.ECDSASignature(rawRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p521":
            let ok = (try? Crypto.P521.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P521.Signing.ECDSASignature(rawRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p256-der":
            let ok = (try? Crypto.P256.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P256.Signing.ECDSASignature(derRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p384-der":
            let ok = (try? Crypto.P384.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P384.Signing.ECDSASignature(derRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "ecdsa-p521-der":
            let ok = (try? Crypto.P521.Signing.PublicKey(rawRepresentation: f[0]).isValidSignature(Crypto.P521.Signing.ECDSASignature(derRepresentation: f[2]), for: f[1])) ?? false
            verdict(name, ok)
        case "aesgcm-256":
            let key = Crypto.SymmetricKey(data: f[0])
            let opened = try? Crypto.AES.GCM.open(Crypto.AES.GCM.SealedBox(combined: f[4]), using: key, authenticating: f[2])
            verdict(name, opened == f[3])
        case "chachapoly":
            let key = Crypto.SymmetricKey(data: f[0])
            let opened = try? Crypto.ChaChaPoly.open(Crypto.ChaChaPoly.SealedBox(combined: f[4]), using: key, authenticating: f[2])
            verdict(name, opened == f[3])
        case "mlkem768":
            let secret = try? Crypto.MLKEM768.PrivateKey(seedRepresentation: f[0], publicKey: nil).decapsulate(f[1])
            verdict(name, secret.map { s in s.withUnsafeBytes { Data($0) } } == f[2])
        case "hpke-p256":
            let ok: Bool
            if let recipientKey = try? Crypto.P256.KeyAgreement.PrivateKey(rawRepresentation: f[0]),
               var recipient = try? Crypto.HPKE.Recipient(privateKey: recipientKey, ciphersuite: .P256_SHA256_AES_GCM_256, info: f[1], encapsulatedKey: f[2]) {
                ok = (try? recipient.open(f[3])) == f[4]
            } else {
                ok = false
            }
            verdict(name, ok)
        default:
            emit("skipped \(name)")
        }
    }
    emit("verify summary verified=\(verified) failed=\(failed)")
}

// MARK: entropy

func entropyMode() {
    let key = Crypto.P256.Signing.PrivateKey()
    emit("entropy p256 \(hex(key.rawRepresentation))")
}

// MARK: main

let arguments = CommandLine.arguments
switch arguments.count > 1 ? arguments[1] : "rows" {
case "rows":
    let seed = arguments.count > 2 ? UInt64(arguments[2]) ?? 1 : 1
    rowsMode(seed: seed, negative: arguments.contains("negative"), macs: !arguments.contains("nohmac"))
case "make":
    makeMode()
case "make-hpke":
    hpkeMode()
case "verify":
    verifyMode(arguments.count > 2 ? String(decoding: unhex(Substring(arguments[2])), as: UTF8.self) : "")
case "entropy":
    entropyMode()
default:
    emit("usage: probe rows [seed] [negative] [nohmac] | make | make-hpke | verify <hex> | entropy")
    exit(2)
}

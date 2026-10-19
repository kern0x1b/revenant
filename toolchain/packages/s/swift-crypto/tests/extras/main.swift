import Crypto
import _CryptoExtras
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

let rsaPEM = """
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDzyHIz4pRJVlWS
5h7Pl5VwiClFB7trWWvaARy81gl2istj9CTurN5JpO24FTqjb+QaHET0dIIzugSY
wK0/scmdog2w9aZk+j41pwroEqQWBYZ7IkFjNfFcCv7w0QaMxVX/1FzVbH0F7ZG+
0zcVIQzf5mvH5Yqriw3lmieGES6KLfzrtmwqls2mvYwt6rUfIlyHmmSL0wkOTHPs
7/ihFoY4BuZgwNsqTEjcqefl0+sitc/5PgWMrXW37za7q+BmGFdVg69vmQRrrJt5
fqW5rfZjna7wggOFO1hOfjRt/sPF9mALao6peQv3yYYgrBuEDsxkWGeY0IMdNCIy
StmpYlVLAgMBAAECggEAcFN6s4eCFeyOz3ny1moc9FX41hLC+6qfNDrw992TTKiV
IMAcyFCkt8AjvH8jnqzuqE1ARHbui1D5zzxwV3ne0SAbON9nRP287lHCh74XFwKC
vXfCMylmxadXYrSdVP2UK6W5BKnRTYrybb+6kKTC3uO348pTQ8l1pMaL0Y1XKVkz
A53ZgBZVrHjRZJinRGzPYsoXjqdHfj0v3nILWcORtN+PEvHcoAIDOriQU5aLwC/B
0UoQqkDGh6bmGEBDZdtJ5qs0SYTs3AphMn+LZiO1fmTqChZ8mdG+ajeIuA5f4CFH
gEI4Jmr6muqHWLmkYZ+0+cpDthwX3kS09h6Ni0qteQKBgQD9mgnN0abLavukZEcV
4/RRzqeehtDSSUAmsAy21ENQYYMMUrntn/kSW+UmYyn8kATxeNAHqg3UnfSHWvmL
nkDeLvJdYpCNBb1EUXgb4lNZaKG+/gICYYKzv2HOzfYni+H7j2k6bpg/ksmsWK8e
Fu8y6z9gwNFyX7IrVt6p5oOQ/wKBgQD2FqMSWzYAmVARiWDJBn++I33WkfOBA0Ba
iK/vW0AebWgfLWlzUaeqVehCjDGbByTtpp9dtKDk8dEhNL7QMotSCPrO9pDCMmfZ
Mj5J1ml6R8v5uNSbDrGYi+gkJaqPRMtK8fLlhfSIwrgGlWBumc72nxNeLW1rWLHl
Ib2O20IvtQKBgGcAO18m+bHA//fi6qRPc5oObzIJ26KtMasE8gUH7VcmY82LhAyp
XsZAILAYsqLr87YHtaaHQRrMFNcs8hHs8rfLJZEcSU2duSOYW0ooAGZeAuPJ0xMY
e7d50cXnDUU+oUhFFR4wcRHREqw3UNjNw9VQiutHJUpo57qGi+VBxMoNAoGAP1Dn
uCtbo5/OqBRuoIpZh7ReBj0bJ9CMWD7e9XjG8I05wvvOK+uQdhUQYz7q7HZUHAlI
67UzyHQnWKHXjn3SttK0pVdvO2f4rDtvJ1RRYzLh2mih2xtWumcU3WgLkD0lCS1j
T4a9ugpPivIYE5zjUTTwqMSLaJkzfD7IJN9pEhkCgYAxnKd6P30gFgZA+5nSLEAS
6eK250kZpxlKCnSIkfiMdjm3OUFhEA7LBWX+qZDh1n8x4psczcyOi9v5Q8KBctNb
ZWrwyonCAr47ZS5nyMwO11py9nOEHkXVouMUwLBkMmxDDpdLJ3qqhj25imZ5Wg41
NjeuZD1U52HWzbCitmx6jw==
-----END PRIVATE KEY-----
"""

func rowsMode(negative: Bool) {
    var rng = SplitMix64(state: 20261014)
    emit("rows\(negative ? " negative" : "")")

    func row(_ name: String, _ value: String) {
        emit("row \(name) \(value)")
    }

    func result(_ name: String, _ body: () throws -> Data) {
        row(name, attempt(body).map { hex($0) } ?? "threw")
    }

    let rsa = try! _RSA.Signing.PrivateKey(pemRepresentation: rsaPEM)
    for length in [0, 1, 300] {
        let message = rng.bytes(length)
        result("RSA-PKCS1v1.5 sign \(length)") {
            try rsa.signature(for: message, padding: .insecurePKCS1v1_5).withUnsafeBytes { Data($0) }
        }
        let signature = try? rsa.signature(for: message, padding: .insecurePKCS1v1_5)
        row("RSA-PKCS1v1.5 verify \(length)", signature.map { rsa.publicKey.isValidSignature($0, for: message, padding: .insecurePKCS1v1_5) ? "valid" : "invalid" } ?? "threw")
    }

    for keyLength in [16, 32] {
        let key = SymmetricKey(data: rng.bytes(keyLength))
        let iv = try! AES._CBC.IV(ivBytes: rng.bytes(16))
        for length in [0, 15, 16, 50] {
            let plain = rng.bytes(length)
            let input = negative && keyLength == 16 && length == 15 ? flipped(plain) : plain
            result("AES-CBC-\(keyLength * 8) encrypt \(length)") {
                try AES._CBC.encrypt(input, using: key, iv: iv)
            }
        }
    }

    for keyLength in [16, 32] {
        let key = SymmetricKey(data: rng.bytes(keyLength))
        let nonce = try! AES._CTR.Nonce(nonceBytes: rng.bytes(12))
        let message = rng.bytes(100)
        result("AES-CTR-\(keyLength * 8) encrypt") {
            try AES._CTR.encrypt(message, using: key, nonce: nonce)
        }
    }

    for keyLength in [16, 32] {
        let key = SymmetricKey(data: rng.bytes(keyLength))
        let nonce = try! AES.GCM._SIV.Nonce(data: rng.bytes(12))
        let aad = rng.bytes(9)
        for length in [0, 33] {
            let message = rng.bytes(length)
            result("AES-GCM-SIV-\(keyLength * 8) seal \(length)") {
                try AES.GCM._SIV.seal(message, using: key, nonce: nonce, authenticating: aad).combined
            }
        }
    }

    let chachaKey = SymmetricKey(data: rng.bytes(32))
    let chachaNonce = try! Insecure.ChaCha20CTR.Nonce(data: rng.bytes(12))
    for offset in [0, 7] {
        let message = rng.bytes(100)
        result("ChaCha20-CTR counter \(offset)") {
            try Insecure.ChaCha20CTR.encrypt(message, using: chachaKey, counter: Insecure.ChaCha20CTR.Counter(offset: UInt32(offset)), nonce: chachaNonce)
        }
    }

    let password = Data("revenant".utf8)
    let salt = rng.bytes(16)
    result("PBKDF2-SHA256 1000 rounds") {
        try KDF.Insecure.PBKDF2.deriveKey(from: password, salt: salt, using: .sha256, outputByteCount: 32, unsafeUncheckedRounds: 1000).withUnsafeBytes { Data($0) }
    }
    result("PBKDF2-SHA512 1000 rounds") {
        try KDF.Insecure.PBKDF2.deriveKey(from: password, salt: salt, using: .sha512, outputByteCount: 48, unsafeUncheckedRounds: 1000).withUnsafeBytes { Data($0) }
    }
    result("PBKDF2 safe API at 1000 rounds") {
        try KDF.Insecure.PBKDF2.deriveKey(from: password, salt: salt, using: .sha256, outputByteCount: 32, rounds: 1000).withUnsafeBytes { Data($0) }
    }
    result("Scrypt N1024 r8 p1") {
        try KDF.Scrypt.deriveKey(from: password, salt: salt, outputByteCount: 32, rounds: 1024, blockSize: 8, parallelism: 1).withUnsafeBytes { Data($0) }
    }
    result("Scrypt N16 r8 p2 64 bytes") {
        try KDF.Scrypt.deriveKey(from: password, salt: salt, outputByteCount: 64, rounds: 16, blockSize: 8, parallelism: 2).withUnsafeBytes { Data($0) }
    }

    let kek = SymmetricKey(data: rng.bytes(16))
    let keyToWrap = SymmetricKey(data: rng.bytes(32))
    result("AES-KW wrap 256 under 128") {
        try AES.KeyWrap.wrap(keyToWrap, using: kek)
    }
    result("AES-KW unwrap") {
        try AES.KeyWrap.unwrap(AES.KeyWrap.wrap(keyToWrap, using: kek), using: kek).withUnsafeBytes { Data($0) }
    }
}

func makeMode() {
    var rng = SplitMix64(state: 7)
    let rsa = try! _RSA.Signing.PrivateKey(pemRepresentation: rsaPEM)
    for length in [0, 300] {
        let message = rng.bytes(length)
        let signature = try! rsa.signature(for: message, padding: .PSS)
        emit("rec rsa-pss|\(hex(message))|\(hex(signature.rawRepresentation))")
    }

    let encryption = try! _RSA.Encryption.PrivateKey(pemRepresentation: rsaPEM)
    for length in [0, 100] {
        let plain = rng.bytes(length)
        let cipher = try! encryption.publicKey.encrypt(plain, padding: .PKCS1_OAEP_SHA256)
        emit("rec rsa-oaep-sha256|\(hex(cipher))|\(hex(plain))")
    }
}

func verifyMode(_ text: String) {
    let rsa = try! _RSA.Signing.PrivateKey(pemRepresentation: rsaPEM)
    let encryption = try! _RSA.Encryption.PrivateKey(pemRepresentation: rsaPEM)
    var verified = 0
    var failed = 0
    func verdict(_ name: String, _ ok: Bool) {
        if ok { verified += 1 } else { failed += 1 }
        emit("\(ok ? "verified" : "FAILED") \(name)")
    }
    for line in text.split(separator: "\n") {
        guard line.hasPrefix("rec ") else { continue }
        let fields = line.dropFirst(4).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count >= 2 else { continue }
        let name = String(fields[0])
        let f = fields.dropFirst().map { unhex($0) }
        guard f.count == 2 else {
            verdict(name, false)
            continue
        }
        switch name {
        case "rsa-pss":
            verdict(name, rsa.publicKey.isValidSignature(_RSA.Signing.RSASignature(rawRepresentation: f[1]), for: f[0], padding: .PSS))
        case "rsa-oaep-sha256":
            verdict(name, (try? encryption.decrypt(f[0], padding: .PKCS1_OAEP_SHA256)) == f[1])
        default:
            emit("skipped \(name)")
        }
    }
    emit("verify summary verified=\(verified) failed=\(failed)")
}

let arguments = CommandLine.arguments
switch arguments.count > 1 ? arguments[1] : "rows" {
case "rows":
    rowsMode(negative: arguments.contains("negative"))
case "make":
    makeMode()
case "verify":
    verifyMode(arguments.count > 2 ? String(decoding: unhex(Substring(arguments[2])), as: UTF8.self) : "")
default:
    emit("usage: probe rows [negative] | make | verify <hex>")
    exit(2)
}

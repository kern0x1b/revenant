import CommonCrypto
import Foundation

public enum CryptoKitError: Error, Equatable, Hashable {
    case incorrectKeySize
    case incorrectParameterSize
    case authenticationFailure
    case underlyingCoreCryptoError(error: Int32)
    case wrapFailure
    case unwrapFailure
    case invalidParameter
}

public enum AES: Sendable {
    public enum GCM: Sendable {
        fileprivate static let nonceByteCount = 12
        fileprivate static let tagByteCount = 16

        public struct Nonce: ContiguousBytes, Sequence, Sendable {
            fileprivate let bytes: [UInt8]

            public init() {
                bytes = revenantRandom(GCM.nonceByteCount)
            }

            fileprivate init(verified bytes: [UInt8]) {
                self.bytes = bytes
            }

            public init<D: DataProtocol>(data: D) throws {
                let values = Array(data)
                guard values.count == GCM.nonceByteCount else {
                    throw CryptoKitError.incorrectParameterSize
                }
                bytes = values
            }

            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try bytes.withUnsafeBytes(body)
            }

            public func makeIterator() -> Array<UInt8>.Iterator {
                bytes.makeIterator()
            }

            public typealias Element = UInt8
            public typealias Iterator = Array<UInt8>.Iterator
        }

        public struct SealedBox: Sendable {
            public let nonce: Nonce
            public let ciphertext: Data
            public let tag: Data

            public var combined: Data? {
                var result = Data(nonce.bytes)
                result.append(ciphertext)
                result.append(tag)
                return result
            }

            public init<C: DataProtocol, T: DataProtocol>(nonce: Nonce, ciphertext: C, tag: T) throws {
                let tagBytes = Data(tag)
                guard tagBytes.count == GCM.tagByteCount else {
                    throw CryptoKitError.incorrectParameterSize
                }
                self.nonce = nonce
                self.ciphertext = Data(ciphertext)
                self.tag = tagBytes
            }

            public init<D: DataProtocol>(combined: D) throws {
                let bytes = Array(combined)
                guard bytes.count >= GCM.nonceByteCount + GCM.tagByteCount else {
                    throw CryptoKitError.incorrectParameterSize
                }
                let split = bytes.count - GCM.tagByteCount
                nonce = Nonce(verified: Array(bytes[0..<GCM.nonceByteCount]))
                ciphertext = Data(bytes[GCM.nonceByteCount..<split])
                tag = Data(bytes[split...])
            }
        }

        public static func seal<Plaintext: DataProtocol, AuthenticatedData: DataProtocol>(_ message: Plaintext, using key: SymmetricKey, nonce: Nonce? = nil, authenticating authenticatedData: AuthenticatedData) throws -> SealedBox {
            let cipher = try AESBlockCipher(key: validatedKey(key))
            let nonceBytes = (nonce ?? Nonce()).bytes
            let subkey = try hashSubkey(cipher)
            let ciphertext = try keystream(cipher, nonceBytes, Array(message))
            let tag = try authenticationTag(cipher, subkey, nonceBytes, Array(authenticatedData), ciphertext)
            return try SealedBox(nonce: Nonce(verified: nonceBytes), ciphertext: ciphertext, tag: tag)
        }

        public static func seal<Plaintext: DataProtocol>(_ message: Plaintext, using key: SymmetricKey, nonce: Nonce? = nil) throws -> SealedBox {
            try seal(message, using: key, nonce: nonce, authenticating: Data())
        }

        public static func open<AuthenticatedData: DataProtocol>(_ sealedBox: SealedBox, using key: SymmetricKey, authenticating authenticatedData: AuthenticatedData) throws -> Data {
            let cipher = try AESBlockCipher(key: validatedKey(key))
            let nonceBytes = sealedBox.nonce.bytes
            let ciphertext = Array(sealedBox.ciphertext)
            let subkey = try hashSubkey(cipher)
            let tag = try authenticationTag(cipher, subkey, nonceBytes, Array(authenticatedData), ciphertext)
            guard revenantEqual(tag, Array(sealedBox.tag)) else {
                throw CryptoKitError.authenticationFailure
            }
            return Data(try keystream(cipher, nonceBytes, ciphertext))
        }

        public static func open(_ sealedBox: SealedBox, using key: SymmetricKey) throws -> Data {
            try open(sealedBox, using: key, authenticating: Data())
        }
    }
}

func revenantRandom(_ count: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    arc4random_buf(&bytes, count)
    return bytes
}

private func validatedKey(_ key: SymmetricKey) throws -> [UInt8] {
    let bytes = key.withUnsafeBytes { Array($0) }
    guard bytes.count == 16 || bytes.count == 24 || bytes.count == 32 else {
        throw CryptoKitError.incorrectKeySize
    }
    return bytes
}

private final class AESBlockCipher {
    private let cryptor: CCCryptorRef

    init(key: [UInt8]) throws {
        var reference: CCCryptorRef?
        let status = key.withUnsafeBytes { keyBytes in
            CCCryptorCreate(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode), keyBytes.baseAddress, key.count, nil, &reference)
        }
        guard status == kCCSuccess, let created = reference else {
            throw CryptoKitError.underlyingCoreCryptoError(error: status)
        }
        cryptor = created
    }

    deinit {
        CCCryptorRelease(cryptor)
    }

    func encrypt(_ block: [UInt8]) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: 16)
        var moved = 0
        let status = CCCryptorUpdate(cryptor, block, block.count, &output, output.count, &moved)
        guard status == kCCSuccess else {
            throw CryptoKitError.underlyingCoreCryptoError(error: status)
        }
        return output
    }
}

private struct GHASHBlock {
    var high: UInt64
    var low: UInt64
}

private func load(_ bytes: [UInt8]) -> GHASHBlock {
    var block = GHASHBlock(high: 0, low: 0)
    for index in 0..<8 {
        block.high = (block.high << 8) | UInt64(bytes[index])
        block.low = (block.low << 8) | UInt64(bytes[index + 8])
    }
    return block
}

private func store(_ block: GHASHBlock) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 16)
    for index in 0..<8 {
        bytes[index] = UInt8(truncatingIfNeeded: block.high >> UInt64(56 - 8 * index))
        bytes[index + 8] = UInt8(truncatingIfNeeded: block.low >> UInt64(56 - 8 * index))
    }
    return bytes
}

private func multiply(_ x: GHASHBlock, _ y: GHASHBlock) -> GHASHBlock {
    var product = GHASHBlock(high: 0, low: 0)
    var v = y
    for bit in 0..<128 {
        let word = bit < 64 ? x.high : x.low
        if (word >> UInt64(63 - bit % 64)) & 1 == 1 {
            product.high ^= v.high
            product.low ^= v.low
        }
        let carry = v.low & 1
        v.low = (v.low >> 1) | (v.high << 63)
        v.high = v.high >> 1
        if carry == 1 {
            v.high ^= 0xE1 << 56
        }
    }
    return product
}

private func ghash(_ h: GHASHBlock, _ aad: [UInt8], _ ciphertext: [UInt8]) -> GHASHBlock {
    var y = GHASHBlock(high: 0, low: 0)
    for data in [aad, ciphertext] {
        var offset = 0
        while offset < data.count {
            var chunk = [UInt8](repeating: 0, count: 16)
            let length = min(16, data.count - offset)
            for index in 0..<length {
                chunk[index] = data[offset + index]
            }
            let x = load(chunk)
            y = multiply(GHASHBlock(high: y.high ^ x.high, low: y.low ^ x.low), h)
            offset += 16
        }
    }
    let lengths = GHASHBlock(high: UInt64(aad.count) * 8, low: UInt64(ciphertext.count) * 8)
    return multiply(GHASHBlock(high: y.high ^ lengths.high, low: y.low ^ lengths.low), h)
}

private func hashSubkey(_ cipher: AESBlockCipher) throws -> GHASHBlock {
    load(try cipher.encrypt([UInt8](repeating: 0, count: 16)))
}

private func counterBlock(_ nonce: [UInt8], _ counter: UInt32) -> [UInt8] {
    nonce + [UInt8(counter >> 24), UInt8((counter >> 16) & 0xff), UInt8((counter >> 8) & 0xff), UInt8(counter & 0xff)]
}

private func keystream(_ cipher: AESBlockCipher, _ nonce: [UInt8], _ input: [UInt8]) throws -> [UInt8] {
    var output = [UInt8]()
    output.reserveCapacity(input.count)
    var counter: UInt32 = 2
    var offset = 0
    while offset < input.count {
        let mask = try cipher.encrypt(counterBlock(nonce, counter))
        let length = min(16, input.count - offset)
        for index in 0..<length {
            output.append(input[offset + index] ^ mask[index])
        }
        offset += length
        counter &+= 1
    }
    return output
}

private func authenticationTag(_ cipher: AESBlockCipher, _ h: GHASHBlock, _ nonce: [UInt8], _ aad: [UInt8], _ ciphertext: [UInt8]) throws -> [UInt8] {
    let digest = store(ghash(h, aad, ciphertext))
    let mask = try cipher.encrypt(counterBlock(nonce, 1))
    return zip(digest, mask).map { $0 ^ $1 }
}

import Foundation

public protocol MessageAuthenticationCode: ContiguousBytes, CustomStringConvertible, Hashable, Sendable, Sequence where Element == UInt8 {
    var byteCount: Int { get }
}

public struct HashedAuthenticationCode<H>: MessageAuthenticationCode, Sendable where H: HashFunction {
    fileprivate let bytes: [UInt8]

    public var byteCount: Int {
        bytes.count
    }

    public var description: String {
        "HMAC with \(String(describing: H.self)): " + revenantHex(bytes)
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }

    public func makeIterator() -> Array<UInt8>.Iterator {
        bytes.makeIterator()
    }

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

extension HashedAuthenticationCode {
    public static func == <D: DataProtocol>(lhs: HashedAuthenticationCode<H>, rhs: D) -> Bool {
        lhs.elementsEqual(rhs)
    }
}

public struct HMAC<H>: Sendable where H: HashFunction {
    public typealias Key = SymmetricKey
    public typealias MAC = HashedAuthenticationCode<H>

    private var inner: H
    private let outerPad: [UInt8]

    public init(key: SymmetricKey) {
        var block = key.withUnsafeBytes { Array($0) }
        if block.count > H.blockByteCount {
            block = Array(H.hash(data: block))
        }
        block += [UInt8](repeating: 0, count: H.blockByteCount - block.count)
        var inner = H()
        inner.update(data: block.map { $0 ^ 0x36 })
        self.inner = inner
        outerPad = block.map { $0 ^ 0x5c }
    }

    public mutating func update<D: DataProtocol>(data: D) {
        inner.update(data: data)
    }

    public func finalize() -> MAC {
        let innerDigest = Array(inner.finalize())
        var outer = H()
        outer.update(data: outerPad)
        outer.update(data: innerDigest)
        return MAC(bytes: Array(outer.finalize()))
    }

    public static func authenticationCode<D: DataProtocol>(for data: D, using key: SymmetricKey) -> MAC {
        var hmac = HMAC<H>(key: key)
        hmac.update(data: data)
        return hmac.finalize()
    }

    public static func isValidAuthenticationCode<D: DataProtocol>(_ authenticationCode: MAC, authenticating authenticatedData: D, using key: SymmetricKey) -> Bool {
        let computed = Array(HMAC<H>.authenticationCode(for: authenticatedData, using: key))
        return revenantEqual(computed, Array(authenticationCode))
    }

    public static func isValidAuthenticationCode(_ mac: MAC, authenticating bufferPointer: UnsafeRawBufferPointer, using key: SymmetricKey) -> Bool {
        isValidAuthenticationCode(mac, authenticating: Data(bufferPointer), using: key)
    }

    public static func isValidAuthenticationCode<C: ContiguousBytes, D: DataProtocol>(_ authenticationCode: C, authenticating authenticatedData: D, using key: SymmetricKey) -> Bool {
        let computed = Array(HMAC<H>.authenticationCode(for: authenticatedData, using: key))
        let given = authenticationCode.withUnsafeBytes { Array($0) }
        return revenantEqual(computed, given)
    }
}

func revenantEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    var difference: UInt8 = 0
    for index in 0..<lhs.count {
        difference |= lhs[index] ^ rhs[index]
    }
    return difference == 0
}

public struct SymmetricKeySize: Sendable {
    public let bitCount: Int

    public static var bits128: SymmetricKeySize {
        SymmetricKeySize(bitCount: 128)
    }

    public static var bits192: SymmetricKeySize {
        SymmetricKeySize(bitCount: 192)
    }

    public static var bits256: SymmetricKeySize {
        SymmetricKeySize(bitCount: 256)
    }

    public init(bitCount: Int) {
        self.bitCount = bitCount
    }
}

public struct SymmetricKey: ContiguousBytes, Sendable, Equatable {
    private let bytes: [UInt8]

    public init(size: SymmetricKeySize) {
        bytes = revenantRandom(size.bitCount / 8)
    }

    public init<D: ContiguousBytes>(data: D) {
        bytes = data.withUnsafeBytes { Array($0) }
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }

    public var bitCount: Int {
        bytes.count * 8
    }
}

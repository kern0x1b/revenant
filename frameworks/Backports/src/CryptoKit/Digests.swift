import CommonCrypto
import Foundation

public protocol HashFunction: Sendable {
    static var blockByteCount: Int { get }
    associatedtype Digest: CryptoKit.Digest
    init()
    mutating func update(bufferPointer: UnsafeRawBufferPointer)
    func finalize() -> Self.Digest
}

extension HashFunction {
    public static func hash<D: DataProtocol>(data: D) -> Self.Digest {
        var hasher = Self()
        hasher.update(data: data)
        return hasher.finalize()
    }

    public mutating func update<D: DataProtocol>(data: D) {
        let bytes = Array(data)
        bytes.withUnsafeBytes { update(bufferPointer: $0) }
    }
}

public protocol Digest: ContiguousBytes, CustomStringConvertible, Hashable, Sendable, Sequence where Element == UInt8 {
    static var byteCount: Int { get }
}

extension Digest {
    public static func == <D: DataProtocol>(lhs: Self, rhs: D) -> Bool {
        lhs.elementsEqual(rhs)
    }
}

private let hexDigits = Array("0123456789abcdef")

func revenantHex(_ bytes: [UInt8]) -> String {
    var text = ""
    for byte in bytes {
        text.append(hexDigits[Int(byte >> 4)])
        text.append(hexDigits[Int(byte & 0x0f)])
    }
    return text
}

private func updateInChunks(_ buffer: UnsafeRawBufferPointer, _ update: (UnsafeRawPointer?, CC_LONG) -> Void) {
    var offset = 0
    while offset < buffer.count {
        let length = min(buffer.count - offset, Int(CC_LONG.max))
        update(buffer.baseAddress.map { $0 + offset }, CC_LONG(length))
        offset += length
    }
}

public struct SHA256Digest: Digest {
    fileprivate let bytes: [UInt8]

    public static var byteCount: Int { 32 }

    public var description: String {
        "SHA256 digest: " + revenantHex(bytes)
    }

    public func makeIterator() -> Array<UInt8>.Iterator {
        bytes.makeIterator()
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

public struct SHA384Digest: Digest {
    fileprivate let bytes: [UInt8]

    public static var byteCount: Int { 48 }

    public var description: String {
        "SHA384 digest: " + revenantHex(bytes)
    }

    public func makeIterator() -> Array<UInt8>.Iterator {
        bytes.makeIterator()
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

public struct SHA512Digest: Digest {
    fileprivate let bytes: [UInt8]

    public static var byteCount: Int { 64 }

    public var description: String {
        "SHA512 digest: " + revenantHex(bytes)
    }

    public func makeIterator() -> Array<UInt8>.Iterator {
        bytes.makeIterator()
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

private struct SHA256State: @unchecked Sendable {
    var context = CC_SHA256_CTX()
}

private struct SHA512State: @unchecked Sendable {
    var context = CC_SHA512_CTX()
}

public struct SHA256: HashFunction, Sendable {
    public static let blockByteCount = 64
    public static let byteCount = 32
    public typealias Digest = SHA256Digest

    private var state = SHA256State()

    public init() {
        CC_SHA256_Init(&state.context)
    }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        updateInChunks(bufferPointer) { CC_SHA256_Update(&state.context, $0, $1) }
    }

    public func finalize() -> SHA256Digest {
        var output = [UInt8](repeating: 0, count: SHA256.byteCount)
        var context = state.context
        CC_SHA256_Final(&output, &context)
        return SHA256Digest(bytes: output)
    }
}

public struct SHA384: HashFunction, Sendable {
    public static let blockByteCount = 128
    public static let byteCount = 48
    public typealias Digest = SHA384Digest

    private var state = SHA512State()

    public init() {
        CC_SHA384_Init(&state.context)
    }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        updateInChunks(bufferPointer) { CC_SHA384_Update(&state.context, $0, $1) }
    }

    public func finalize() -> SHA384Digest {
        var output = [UInt8](repeating: 0, count: SHA384.byteCount)
        var context = state.context
        CC_SHA384_Final(&output, &context)
        return SHA384Digest(bytes: output)
    }
}

public struct SHA512: HashFunction, Sendable {
    public static let blockByteCount = 128
    public static let byteCount = 64
    public typealias Digest = SHA512Digest

    private var state = SHA512State()

    public init() {
        CC_SHA512_Init(&state.context)
    }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        updateInChunks(bufferPointer) { CC_SHA512_Update(&state.context, $0, $1) }
    }

    public func finalize() -> SHA512Digest {
        var output = [UInt8](repeating: 0, count: SHA512.byteCount)
        var context = state.context
        CC_SHA512_Final(&output, &context)
        return SHA512Digest(bytes: output)
    }
}


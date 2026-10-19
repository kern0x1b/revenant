// Codec.swift — the protobuf wire format, written and read by hand.
//
// Apple's `.mlmodel` is a protobuf (proto2, little-endian fixed fields) and the schema is Apple's,
// **BSD-3-Clause**, in `coremltools/mlmodel/format/*.proto`; the copies this package vendors are in
// `packages/c/createml/proto/` with their licence, pinned to a commit in that directory's README. What is here is not a generator and not a
// re-declaration of the schema: it is the **wire format** — varints, the fixed 32- and 64-bit
// doubles, and the length-delimited submessages — plus a reader that walks a message by field number
// and a writer that emits one. Every field name and number used by the model messages is read out of
// the vendored `.proto` and named after it, and the ones this package writes are the ones a Core ML
// model of these estimators needs.
//
// There is no protobuf library in the store for this target, so a hand-written codec is the native
// route rather than a workaround, and it is a small one: six wire types, of which four are used.
//
// **What this file does not do:** it does not validate a schema, resolve a `oneof`, or handle
// extensions. The messages below are read by *field number* and the numbers are in the file next to
// this one, so a reader that met an unknown field skips it by its wire type, which is what a protobuf
// reader is required to do.

import Foundation

/// One field of a message, as it came off the wire.
public enum ProtoField {
    case varint(UInt64)
    case fixed64(UInt64)
    case lengthDelimited([UInt8])
    case fixed32(UInt32)
}

/// A reader over a protobuf message: the whole message is walked, field by field.
public struct ProtoReader {
    private let bytes: [UInt8]
    private var offset: Int

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
        self.offset = 0
    }

    /// The next field, or nil at the end.
    public mutating func next() throws -> (number: Int, field: ProtoField)? {
        guard offset < bytes.count else { return nil }
        let key = try readVarint()
        let number = Int(key >> 3)
        let wire = Int(key & 0x7)
        switch wire {
        case 0: return (number, .varint(try readVarint()))
        case 1:
            let value = try readFixed64()
            return (number, .fixed64(value))
        case 2:
            let length = Int(try readVarint())
            let slice = try readBytes(length)
            return (number, .lengthDelimited(slice))
        case 5:
            let value = try readFixed32()
            return (number, .fixed32(value))
        default:
            throw ProtoError.unsupportedWireType(wire)
        }
    }

    /// Every field of a message, as `(number, field)` pairs, in wire order.
    public static func fields(_ bytes: [UInt8]) throws -> [(Int, ProtoField)] {
        var reader = ProtoReader(bytes)
        var out = [(Int, ProtoField)]()
        while let pair = try reader.next() { out.append(pair) }
        return out
    }

    private mutating func readVarint() throws -> UInt64 {
        var value = UInt64(0)
        var shift = 0
        while true {
            guard offset < bytes.count else { throw ProtoError.truncated }
            let byte = bytes[offset]
            offset += 1
            value |= UInt64(byte & 0x7F) << UInt64(shift)
            if byte & 0x80 == 0 { return value }
            shift += 7
            if shift > 63 { throw ProtoError.varintTooLong }
        }
    }

    private mutating func readFixed64() throws -> UInt64 {
        guard offset + 8 <= bytes.count else { throw ProtoError.truncated }
        var value = UInt64(0)
        for index in 0..<8 { value |= UInt64(bytes[offset + index]) << UInt64(index * 8) }
        offset += 8
        return value
    }

    private mutating func readFixed32() throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw ProtoError.truncated }
        var value = UInt32(0)
        for index in 0..<4 { value |= UInt32(bytes[offset + index]) << UInt32(index * 8) }
        offset += 4
        return value
    }

    private mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard offset + count <= bytes.count, count >= 0 else { throw ProtoError.truncated }
        let slice = Array(bytes[offset..<(offset + count)])
        offset += count
        return slice
    }
}

/// A builder for a protobuf message: fields are appended in number order, as the schema does.
public struct ProtoWriter {
    public private(set) var bytes: [UInt8] = []

    public init() {}

    /// A field carrying a varint: an int32, an int64, a bool or an enum, all of which are varints on
    /// the wire and are written the same way.
    public mutating func varint(_ number: Int, _ value: Int) {
        putVarintKey(number, wire: 0)
        putVarint(UInt64(bitPattern: Int64(value)), into: &bytes)
    }

    public mutating func varint(_ number: Int, _ value: UInt64) {
        putVarintKey(number, wire: 0)
        putVarint(value, into: &bytes)
    }

    public mutating func bool(_ number: Int, _ value: Bool) {
        putVarintKey(number, wire: 0)
        putVarint(value ? 1 : 0, into: &bytes)
    }

    /// A field carrying a `double`, which is wire type 1, little-endian.
    public mutating func double(_ number: Int, _ value: Double) {
        putVarintKey(number, wire: 1)
        let bits = value.bitPattern.littleEndian
        for index in 0..<8 { bytes.append(UInt8((bits >> UInt64(index * 8)) & 0xFF)) }
    }

    /// A field carrying a `repeated float` written **packed**, which is what Core ML's weight blobs
    /// use: a length-delimited run of little-endian 32-bit values, not one field per element.
    public mutating func packedFloat(_ number: Int, _ values: [Float]) {
        var packed = [UInt8]()
        packed.reserveCapacity(values.count * 4)
        for value in values {
            let bits = value.bitPattern.littleEndian
            for index in 0..<4 { packed.append(UInt8((bits >> UInt32(index * 8)) & 0xFF)) }
        }
        putVarintKey(number, wire: 2)
        putVarint(UInt64(packed.count), into: &bytes)
        bytes.append(contentsOf: packed)
    }

    public mutating func packedDouble(_ number: Int, _ values: [Double]) {
        var packed = [UInt8]()
        packed.reserveCapacity(values.count * 8)
        for value in values {
            let bits = value.bitPattern.littleEndian
            for index in 0..<8 { packed.append(UInt8((bits >> UInt64(index * 8)) & 0xFF)) }
        }
        putVarintKey(number, wire: 2)
        putVarint(UInt64(packed.count), into: &bytes)
        bytes.append(contentsOf: packed)
    }

    /// A field carrying a `string`, which is a length-delimited run of UTF-8.
    public mutating func string(_ number: Int, _ value: String) {
        putVarintKey(number, wire: 2)
        putVarint(UInt64(value.utf8.count), into: &bytes)
        bytes.append(contentsOf: Array(value.utf8))
    }

    /// A field carrying a submessage, or a `bytes` one: both are length-delimited.
    public mutating func message(_ number: Int, _ inner: ProtoWriter) {
        putVarintKey(number, wire: 2)
        putVarint(UInt64(inner.bytes.count), into: &bytes)
        bytes.append(contentsOf: inner.bytes)
    }

    /// A repeated `int64` written packed, which is what Core ML's dimensions use.
    public mutating func packedInt64(_ number: Int, _ values: [Int]) {
        var packed = [UInt8]()
        for value in values { putVarint(UInt64(bitPattern: Int64(value)), into: &packed) }
        putVarintKey(number, wire: 2)
        putVarint(UInt64(packed.count), into: &bytes)
        bytes.append(contentsOf: packed)
    }

    private mutating func putVarintKey(_ number: Int, wire: Int) {
        putVarint(UInt64(number) << 3 | UInt64(wire), into: &bytes)
    }

    private func putVarint(_ value: UInt64, into sink: inout [UInt8]) {
        var remaining = value
        while true {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            sink.append(byte)
            if remaining == 0 { return }
        }
    }
}

/// Why a message could not be read.
public enum ProtoError: Error, CustomStringConvertible, Equatable {
    case truncated
    case varintTooLong
    case unsupportedWireType(Int)
    case notAUTF8String

    public var description: String {
        switch self {
        case .truncated: return "the message ends in the middle of a field."
        case .varintTooLong: return "a varint is longer than ten bytes, so it is not one."
        case .unsupportedWireType(let type): return "wire type " + String(type) + " is not in the six the format defines."
        case .notAUTF8String: return "a length-delimited field that must be a string is not UTF-8."
        }
    }
}

extension ProtoField {
    /// A varint field as a signed integer, which is how proto2 spells `int32` and `int64`.
    public var intValue: Int? {
        if case .varint(let value) = self { return Int(Int64(bitPattern: value)) }
        return nil
    }

    public var boolValue: Bool? {
        if case .varint(let value) = self { return value != 0 }
        return nil
    }

    /// A fixed64 field as a `double`.
    public var doubleValue: Double? {
        if case .fixed64(let value) = self { return Double(bitPattern: value) }
        return nil
    }

    /// A length-delimited field as its bytes.
    public var bytesValue: [UInt8]? {
        if case .lengthDelimited(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        guard let bytes = bytesValue else { return nil }
        return String(data: Data(bytes), encoding: .utf8)
    }

    /// A packed repeated float field, read back into its values.
    public var floatValues: [Float]? {
        guard let bytes = bytesValue else { return nil }
        var out = [Float]()
        out.reserveCapacity(bytes.count / 4)
        var index = 0
        while index + 4 <= bytes.count {
            var bits = UInt32(0)
            for byte in 0..<4 { bits |= UInt32(bytes[index + byte]) << UInt32(byte * 8) }
            out.append(Float(bitPattern: bits))
            index += 4
        }
        return out
    }
}

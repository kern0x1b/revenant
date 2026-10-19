import CoreML
import Foundation

public protocol MLShapedArrayScalar {
    static var multiArrayDataType: MLMultiArrayDataType { get }
}

extension Double: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .double }
}

extension Float: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .float32 }
}

extension Int32: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .int32 }
}

public struct MLShapedArray<Scalar: MLShapedArrayScalar>: @unchecked Sendable {
    public private(set) var shape: [Int]
    public private(set) var strides: [Int]
    public private(set) var scalars: [Scalar]

    public var count: Int { scalars.count }

    public var scalarsPerLeadingIndex: Int {
        shape.isEmpty ? 0 : shape.dropFirst().reduce(1, *)
    }

    public func scalarOffset(forLeadingIndex index: Int) -> Int {
        scalarsPerLeadingIndex * index
    }

    public func scalarRange(forLeadingRange range: Range<Int>) -> Range<Int> {
        scalarOffset(forLeadingIndex: range.lowerBound)..<scalarOffset(forLeadingIndex: range.upperBound)
    }

    public static func strides(for shape: [Int]) -> [Int] {
        var strides = [Int](repeating: 1, count: shape.count)
        var running = 1
        var dimension = shape.count - 1
        while dimension >= 0 {
            strides[dimension] = running
            running *= max(0, shape[dimension])
            dimension -= 1
        }
        return strides
    }

    public static func count(of shape: [Int]) -> Int {
        shape.reduce(1) { $0 * max(0, $1) }
    }

    public init(scalar: Scalar, shape: [Int] = [1]) {
        self.shape = shape
        self.strides = MLShapedArray.strides(for: shape)
        self.scalars = [Scalar](repeating: scalar, count: MLShapedArray.count(of: shape))
    }

    public init<S: Sequence>(scalars: S, shape: [Int]) where S.Element == Scalar {
        let values = Array(scalars)
        let expected = MLShapedArray.count(of: shape)
        guard values.count == expected else {
            preconditionFailure("a shape of " + String(describing: shape) + " holds " +
                                String(expected) + " values, not " + String(values.count))
        }
        self.shape = shape
        self.strides = MLShapedArray.strides(for: shape)
        self.scalars = values
    }

    public init(unsafeUninitializedShape shape: [Int], startingWith value: Scalar,
                initializingWith initializer: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> Void) throws {
        self.shape = shape
        self.strides = MLShapedArray.strides(for: shape)
        var values = [Scalar](repeating: value, count: MLShapedArray.count(of: shape))
        let strides = MLShapedArray.strides(for: shape)
        try values.withUnsafeMutableBufferPointer { buffer in
            try initializer(&buffer, shape, strides)
        }
        self.scalars = values
    }

    public subscript(index: Int) -> Scalar {
        get { scalars[index] }
        set { scalars[index] = newValue }
    }

    public subscript(indices indices: Int...) -> Scalar {
        get { scalars[flat(indices)] }
        set { scalars[flat(indices)] = newValue }
    }

    private func flat(_ indices: [Int]) -> Int {
        guard indices.count == shape.count else {
            preconditionFailure("this array is " + String(shape.count) + "-dimensional and was given " +
                                String(indices.count) + " indices")
        }
        var offset = 0
        for (dimension, index) in indices.enumerated() {
            offset += index * strides[dimension]
        }
        return offset
    }

    public func withUnsafeShapedBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeBufferPointer { buffer in try body(buffer, shape, strides) }
    }

    public mutating func withUnsafeMutableShapedBufferPointer<R>(
        _ body: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeMutableBufferPointer { buffer in try body(&buffer, shape, strides) }
    }

    public subscript(slice sliceRange: Range<Int>) -> MLShapedArraySlice<Scalar> {
        MLShapedArraySlice(array: Array(scalars[sliceRange]), shape: [sliceRange.count], strides: [1])
    }

    public subscript(leadingRange range: Range<Int>) -> MLShapedArraySlice<Scalar> {
        let flat = scalarRange(forLeadingRange: range)
        return MLShapedArraySlice(array: Array(scalars[flat]), shape: [flat.count], strides: [1])
    }

    public var rows: [MLShapedArraySlice<Scalar>] {
        guard shape.count == 2 else { return [] }
        return (0..<shape[0]).map { self[leadingRange: $0..<($0 + 1)] }
    }

    public func slice(_ sliceRange: Range<Int>, along dimension: Int) -> MLShapedArraySlice<Scalar> {
        guard dimension < shape.count else {
            preconditionFailure("this array is " + String(shape.count) + "-dimensional")
        }
        guard sliceRange.lowerBound >= 0, sliceRange.upperBound <= shape[dimension] else {
            preconditionFailure(String(describing: sliceRange) + " is outside a dimension of " +
                                String(shape[dimension]))
        }
        let kept = shape.enumerated().map { position, extent in
            position == dimension ? sliceRange.count : extent
        }
        let total = MLShapedArray.count(of: kept)
        var values = [Scalar]()
        values.reserveCapacity(total)
        var offsets = [Int](repeating: 0, count: shape.count)
        for combination in 0..<total {
            var rest = combination
            for position in kept.indices.reversed() {
                let extent = Swift.max(kept[position], 1)
                offsets[position] = rest % extent
                rest /= extent
            }
            offsets[dimension] = sliceRange.lowerBound + offsets[dimension]
            values.append(scalars[flat(offsets)])
        }
        return MLShapedArraySlice(array: values, shape: kept, strides: MLShapedArray.strides(for: kept))
    }
}

public struct MLShapedArraySlice<Scalar: MLShapedArrayScalar>: @unchecked Sendable {
    public let shape: [Int]
    public let strides: [Int]
    public private(set) var scalars: [Scalar]

    public var values: [Scalar] { scalars }

    init(array: [Scalar], shape: [Int], strides: [Int]) {
        self.shape = shape
        self.strides = strides
        self.scalars = array
    }

    public var count: Int { scalars.count }

    public subscript(index: Int) -> Scalar { scalars[index] }

    public var array: MLShapedArray<Scalar> { MLShapedArray(scalars: scalars, shape: shape) }

    public func withUnsafeShapedBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeBufferPointer { buffer in try body(buffer, shape, strides) }
    }
}

extension MLShapedArray: CustomStringConvertible {
    public var description: String {
        "[\(shape)] (\(scalars.count) values)"
    }
}

extension MLShapedArray where Scalar: CustomStringConvertible {
    public var scalarsDescription: String {
        "[" + scalars.map { $0.description }.joined(separator: ", ") + "]"
    }
}


public struct MLModelMetadata: Hashable {
    public var shortDescription: String
    public var author: String
    public var version: String
    public var license: String
    public var description: String

    public init(shortDescription: String = "", author: String = "",
                version: String = "", license: String = "", description: String = "") {
        self.shortDescription = shortDescription
        self.author = author
        self.version = version
        self.license = license
        self.description = description
    }
}

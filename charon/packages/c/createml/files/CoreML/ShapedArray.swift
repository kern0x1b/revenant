// CoreML.swift — the Swift overlay of the shaped arrays, in a module named `CoreML`.
//
// CoreML is absent on the port's release: the class that gives the family its name,
// `MLMultiArray`, is in `registry/CoreML/absent_CoreML.json` and stays absent, and the CoreML
// package's own work is not in this tree. What CreateML cannot do without is one *enumeration* —
// `MLShapedArrayScalar`'s single requirement is `static var multiArrayDataType: MLMultiArrayDataType` —
// and that is header-only, so it is carried by the port's headers (rule R4) and re-declared nowhere.
//
// This file is the overlay of the *shaped array* types over that enumeration, and it is a real
// multi-dimensional array: a shape, strides in elements, and a row-major block of scalars. A tree
// fitted here produces one of these as its feature vector, which is what CreateML's estimators take.
//
// What is NOT here, and is absent rather than stubbed: `MLModel`, `MLMultiArray`, `MLFeatureValue`,
// `MLTensor` and the compute-plan family. Each is a class with methods that the release does not
// have, and an overlay that declared a type the port cannot answer for would be the exact silent fake
// the port's rules forbid. `facts/CoreML/ShapedArray.md` says the same thing from the other side.
//
// The row-major layout is the one the strides describe, and it is what a linear model's weights are
// already in: a design matrix of `rows x columns` has strides `[columns, 1]`, which is what
// `LinearRegressor` hands back, so the arithmetic that fitted it needs no copy on the way out.
//
// ## What is reused, and what is not
//
// The leading-dimension arithmetic below — the scalars an element of a given leading index spans, the
// flat offset of that index, and the flat range a leading range covers — is **taken from** TensorFlow
// swift-apis' `ShapedArray` (`Sources/TensorFlow/Core/ShapedArray.swift`, Apache-2.0,
// https://github.com/tensorflow/swift-apis), which computes exactly these three as
// `scalarCountPerElement`, `scalarIndex(fromIndex:)` and `scalarSubrange(from:)`:
// `shape.isEmpty ? 0 : shape.dropFirst().reduce(1, *)`. It is the part that every strided N-D array
// needs and the part that is easy to get subtly wrong, and it is the whole of what a row slice is.
//
// Three parts of that file are **not** taken, and `facts/CoreML/ShapedArray.md` says why:
// its `TensorBuffer`, which has a second storage mode holding a `TF_Tensor*` — a dependency on
// TensorFlow's C library, a second copy of arithmetic and a dylib this port does not have; its
// several hundred lines of aligned multi-line shape description, where a port needs a shape and a
// count in a log line; and its `RandomAccessCollection, MutableCollection` conformance, which is
// the shape this toolchain rejects and which the port's review just cost a wrong row and a process
// abort over (F3).

import CoreML
import Foundation

/// A scalar a shaped array can hold: a number the arithmetic can be done in.
public protocol MLShapedArrayScalar {
    /// The CoreML element type this scalar is stored as, which is the one thing the framework needs
    /// to know about a scalar to write a model that reads it back.
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

/// A multi-dimensional array of scalars: a shape, strides in elements, and the scalars.
///
/// Row-major, with `strides[dimension]` the distance in *elements* between two neighbours along that
/// dimension: for a two-dimensional `rows x columns` array that is `[columns, 1]`, and for one
/// dimension it is `[1]`. The strides are carried rather than recomputed from the shape because a
/// sub-array of a wider one is a slice with its own base and the same stride, and recomputing would
/// make a view into a copy.
public struct MLShapedArray<Scalar: MLShapedArrayScalar>: @unchecked Sendable {
    public private(set) var shape: [Int]
    public private(set) var strides: [Int]
    public private(set) var scalars: [Scalar]

    /// The number of scalars, which is the product of the shape.
    public var count: Int { scalars.count }

    /// How many scalars one element of the leading dimension spans: the product of everything after
    /// the first, and **zero** for a shape with no dimensions at all.
    ///
    /// Taken from TensorFlow swift-apis' `ShapedArray` (Apache-2.0), which computes this as
    /// `shape.isEmpty ? 0 : shape.dropFirst().reduce(1, *)`. The empty case is the one worth keeping:
    /// a zero-dimensional array holds one scalar and no dimensions, and `dropFirst()` on an empty shape
    /// gives an empty product of `1` — a leading "dimension" of one scalar, which is the right answer
    /// by accident rather than by the `0` the case needs.
    public var scalarsPerLeadingIndex: Int {
        shape.isEmpty ? 0 : shape.dropFirst().reduce(1, *)
    }

    /// The flat offset of an index in the leading dimension.
    public func scalarOffset(forLeadingIndex index: Int) -> Int {
        scalarsPerLeadingIndex * index
    }

    /// The flat range of scalars a range in the leading dimension covers — which is the whole of a
    /// row slice, and is here once so that the slicing code and the buffer code cannot disagree about
    /// what a row is.
    public func scalarRange(forLeadingRange range: Range<Int>) -> Range<Int> {
        scalarOffset(forLeadingIndex: range.lowerBound)..<scalarOffset(forLeadingIndex: range.upperBound)
    }

    /// The strides a shape of this shape has, in elements: the last dimension is 1 and each one
    /// before it is the product of the ones after it.
    public static func strides(for shape: [Int]) -> [Int] {
        // Walking the dimensions backwards, and **past** zero: `stride(from: n-1, to: 0, by: -1)`
        // stops before it reaches 0 and so never sets the outermost dimension's stride, which left
        // every two-dimensional array with strides `[1, 1]` and a row read that was the wrong
        // element. The host differential is what named it, on a 2x3 array.
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

    /// The number of scalars a shape holds, and the shape is what says it.
    public static func count(of shape: [Int]) -> Int {
        shape.reduce(1) { $0 * max(0, $1) }
    }

    /// An array of one scalar, repeated to a shape.
    public init(scalar: Scalar, shape: [Int] = [1]) {
        self.shape = shape
        self.strides = MLShapedArray.strides(for: shape)
        self.scalars = [Scalar](repeating: scalar, count: MLShapedArray.count(of: shape))
    }

    /// An array from its scalars and a shape, and the shape must be the scalars' own count: an
    /// array of a shape that does not hold its values is an array whose shape is a lie, and every
    /// subscript of it would then read the wrong scalar.
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

    /// An array of the given shape, filled by a closure over its buffer, the shape and the strides.
    ///
    /// The buffer starts as the array the initialiser was handed repeated, not as zeroes: a generic
    /// `Scalar` has no zero the protocol can name, and asking every scalar to be `AdditiveArithmetic`
    /// to get one would make `MLShapedArray` unusable for a scalar that is not a number — which is
    /// the whole point of the protocol. A caller that wants zeros passes `scalar: 0`.
    public init(unsafeUninitializedShape shape: [Int], startingWith value: Scalar,
                initializingWith initializer: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> Void) throws {
        self.shape = shape
        self.strides = MLShapedArray.strides(for: shape)
        var values = [Scalar](repeating: value, count: MLShapedArray.count(of: shape))
        let strides = MLShapedArray.strides(for: shape)
        // `withUnsafeMutableBufferPointer` is not `rethrows` in this compiler, so the closure's own
        // throwingness is honoured with an explicit `try` inside a body that is itself `rethrows` —
        // which is the same promise the signature makes and one the caller sees as a `try`.
        try values.withUnsafeMutableBufferPointer { buffer in
            try initializer(&buffer, shape, strides)
        }
        self.scalars = values
    }

    public subscript(index: Int) -> Scalar {
        get { scalars[index] }
        set { scalars[index] = newValue }
    }

    /// The scalar at one index per dimension.
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

    /// The scalars as a buffer, with the shape and strides beside it: the form every kernel wants,
    /// and the reason a fitted model's weights are handed on without a copy.
    public func withUnsafeShapedBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeBufferPointer { buffer in try body(buffer, shape, strides) }
    }

    public mutating func withUnsafeMutableShapedBufferPointer<R>(
        _ body: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeMutableBufferPointer { buffer in try body(&buffer, shape, strides) }
    }

    /// A slice of the scalars in a range, as an array of one dimension — the `rows[start...]` of a
    /// feature matrix.
    public subscript(slice sliceRange: Range<Int>) -> MLShapedArraySlice<Scalar> {
        MLShapedArraySlice(array: Array(scalars[sliceRange]), shape: [sliceRange.count], strides: [1])
    }

    /// **A whole leading-dimension slice** — one row of a design matrix, or one observation — and the
    /// one that *drops* a dimension, which `slice(_:along:)` deliberately does not.
    ///
    /// The two operations are different and the review's F3 is why they are told apart here. A
    /// *partial* slice of a dimension is a sub-block and keeps the dimension with a new extent; a
    /// *whole* leading-dimension slice is a row and is one-dimensional. The flat range is the reused
    /// `scalarRange(forLeadingRange:)`, so a row is computed in one place and the shape it answers is
    /// what a row is: one dimension, of that many scalars.
    public subscript(leadingRange range: Range<Int>) -> MLShapedArraySlice<Scalar> {
        let flat = scalarRange(forLeadingRange: range)
        return MLShapedArraySlice(array: Array(scalars[flat]), shape: [flat.count], strides: [1])
    }

    /// The rows of a two-dimensional array, as an array of rows.
    public var rows: [MLShapedArraySlice<Scalar>] {
        guard shape.count == 2 else { return [] }
        return (0..<shape[0]).map { self[leadingRange: $0..<($0 + 1)] }
    }

    /// A slice **along one dimension**: `array.slice(0..<3, along: 1)` of a `2 x 3` array is the
    /// second *row*, three scalars, shaped `[3]`.
    ///
    /// **A method and not the framework's `subscript(dimension:slice:)`,** and that is this
    /// compiler's doing rather than a preference. A two-parameter subscript here is called with its
    /// leading label *implicit*, and a caller that writes the leading argument without a label gets
    /// it bound to the wrong parameter rather than an error: the review's probe and mine both got
    /// shape `[2, 3]` and eighteen values out of a three-element row, which is the wrong row *and* a
    /// shape that lies about them. Writing the label is refused with "extraneous argument label", so
    /// the subscript form is not reachable at all on this toolchain. A method has one call shape
    /// and one meaning, and the values are now right:
    ///
    ///   - the result's shape is the array's own with **that dimension replaced by the slice's
    ///     extent** — the first version built it from the dimensions the slice *removed*, so a `2 x 3`
    ///     array answered shape `[2]` while holding three scalars;
    ///   - the values are read by walking the *other* dimensions with this one at the slice index,
    ///     stepping it once per element of the result. The first version varied the sliced dimension
    ///     with every other index at zero, so the "second row" answered the first row's values.
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
        // The block is read in **the array's own row-major order**. That is the whole of it, and it
        // is not the same as putting the sliced dimension last or first: for a `2 x 3` array, slicing
        // to two columns must answer `[1, 2, 4, 5]` and slicing to two rows must answer
        // `[1, 2, 3, 4, 5, 6]`, and only walking the *kept* block in its own row-major order and
        // mapping each position into the slice gives both.
        let total = MLShapedArray.count(of: kept)
        var values = [Scalar]()
        values.reserveCapacity(total)
        var offsets = [Int](repeating: 0, count: shape.count)
        for combination in 0..<total {
            // Row-major over the kept shape: the **first** dimension is the most significant, so
            // the *last* is the one that varies fastest. Decoding from the first instead gives a
            // `[2, 2]` block the order `(0,0) (1,0) (0,1) (1,1)`, which is its transpose.
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

/// A slice of a shaped array: the same scalars, a shape of its own and strides of its own, over a
/// range of the array it came from.
public struct MLShapedArraySlice<Scalar: MLShapedArrayScalar>: @unchecked Sendable {
    public let shape: [Int]
    public let strides: [Int]
    public private(set) var scalars: [Scalar]

    /// The slice's scalars, which is what a caller reads it for: the same name the array uses, so
    /// `array[0, slice: ..].values` and `array.values` are the same kind of thing.
    public var values: [Scalar] { scalars }

    init(array: [Scalar], shape: [Int], strides: [Int]) {
        self.shape = shape
        self.strides = strides
        self.scalars = array
    }

    public var count: Int { scalars.count }

    public subscript(index: Int) -> Scalar { scalars[index] }

    /// The slice as a whole array, which is a copy: the slice may be a view into a larger block and
    /// this has no base offset, and a copy that claims to be a view is how a reshaped model goes
    /// wrong silently.
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
    /// The scalars as the text a caller can read: a shaped array's own description is its shape,
    /// because a hundred thousand values is not a description of anything.
    public var scalarsDescription: String {
        "[" + scalars.map { $0.description }.joined(separator: ", ") + "]"
    }
}


/// A model's own description, the metadata a caller attaches when it writes a model out.
///
/// This is Core ML's type, carried here because the exporter takes it: without it `write(to:)`
/// would either invent an author or drop the caller's, and a model file with a fabricated author is
/// worse than one that says nothing.
///
/// **One declaration of it in the package, and this is the one.** The five properties are the ones
/// Core ML declares, so a second copy anywhere in these modules would be a type the same name names
/// twice with a different shape: `import CoreML` would give a caller five settable properties and
/// `import CreateML` a different type of the same name that cannot carry `license` or `description`
/// at all, and which of the two a caller's `write(to:metadata:)` accepted would depend on the
/// imports rather than on the type. A copy with three of the five is not a smaller `MLModelMetadata`,
/// it is a different type wearing its name, so the three-property one is gone rather than merged.
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

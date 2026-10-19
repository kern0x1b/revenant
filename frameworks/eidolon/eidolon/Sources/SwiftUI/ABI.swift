import UIKit
import CoreGraphics

// Types that carry the shape of Apple's SwiftUI interface. Their contents are ours; only the names,
// the argument labels and the order of protocol requirements have to match, because an application
// compiled against Apple's SwiftUI imports exactly these symbols.

public struct _GraphValue<Value> {
    let value: Value
    public init(_ value: Value) { self.value = value }
}

public struct _ViewInputs {
    var environment = EnvironmentValues()
    public init() {}
}

public struct _ViewOutputs {
    var node: Node?
    public init() {}
}

public struct _ViewListInputs {
    var environment = EnvironmentValues()
    public init() {}
}

public struct _ViewListOutputs {
    var nodes: [Node] = []
    public init() {}
}

public struct _ViewListCountInputs {
    public init() {}
}

public protocol _FormatSpecifiable: Equatable {
    associatedtype _Arg: CVarArg
    var _arg: _Arg { get }
    var _specifier: String { get }
}

extension Int: _FormatSpecifiable { public var _arg: Int64 { Int64(self) }; public var _specifier: String { "%lld" } }
extension Int8: _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int16: _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int32: _FormatSpecifiable { public var _arg: Int32 { self }; public var _specifier: String { "%d" } }
extension Int64: _FormatSpecifiable { public var _arg: Int64 { self }; public var _specifier: String { "%lld" } }
extension UInt: _FormatSpecifiable { public var _arg: UInt64 { UInt64(self) }; public var _specifier: String { "%llu" } }
extension UInt8: _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt16: _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt32: _FormatSpecifiable { public var _arg: UInt32 { self }; public var _specifier: String { "%u" } }
extension UInt64: _FormatSpecifiable { public var _arg: UInt64 { self }; public var _specifier: String { "%llu" } }
extension Float: _FormatSpecifiable { public var _arg: Float { self }; public var _specifier: String { "%f" } }
extension Double: _FormatSpecifiable { public var _arg: Double { self }; public var _specifier: String { "%lf" } }
extension CGFloat: _FormatSpecifiable { public var _arg: CGFloat { self }; public var _specifier: String { "%lf" } }

public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation {
    let key: String
    let interpolated: Bool

    var text: String { localized(table: nil, bundle: nil) }

    func localized(table: String?, bundle: Bundle?) -> String {
        guard !interpolated else { return key }
        let translated = (bundle ?? Bundle.main).localizedString(forKey: key, value: nil, table: table)
        return translated.isEmpty ? key : translated
    }

    public init(_ value: String) { key = value; interpolated = false }
    public init(stringLiteral value: String) { key = value; interpolated = false }
    public init(stringInterpolation: StringInterpolation) { key = stringInterpolation.text; interpolated = true }

    public struct StringInterpolation: StringInterpolationProtocol {
        var text = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { text += literal }
        public mutating func appendInterpolation(_ string: String) { text += string }
        @_disfavoredOverload public mutating func appendInterpolation<Subject>(_ subject: Subject) where Subject: CustomStringConvertible {
            text += subject.description
        }
        public mutating func appendInterpolation<T>(_ value: T) where T: _FormatSpecifiable {
            text += value is Double || value is Float || value is CGFloat ? "\(value)" : String(format: value._specifier, value._arg)
        }
        public mutating func appendInterpolation<T>(_ value: T, specifier: String) where T: _FormatSpecifiable {
            text += String(format: specifier, value._arg)
        }
    }
}

public protocol AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat
    static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?)
}

extension AlignmentID {
    // The explicit values of the children are averaged: the n-th value moves the running mean by its share.
    public static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?) {
        if let current = parentValue { parentValue = current + (childValue - current) / CGFloat(n) } else { parentValue = childValue }
    }
}

private enum StandardAlignmentID: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat { 0 }
}

func combineExplicitValues<S: Sequence>(_ values: S, using id: AlignmentID.Type) -> CGFloat? where S.Element == CGFloat? {
    var result: CGFloat?
    var count = 0
    for case let value? in values {
        count += 1
        id._combineExplicit(childValue: value, count, into: &result)
    }
    return result
}

public struct HorizontalAlignment: Equatable {
    let raw: Int
    let id: String
    let custom: ((ViewDimensions) -> CGFloat)?
    let idType: AlignmentID.Type?
    init(raw: Int, id: String) { self.raw = raw; self.id = id; custom = nil; idType = nil }
    public init(_ id: AlignmentID.Type) { raw = 0; self.id = "\(id)"; custom = { id.defaultValue(in: $0) }; idType = id }
    public func combineExplicit<S: Sequence>(_ values: S) -> CGFloat? where S.Element == CGFloat? {
        combineExplicitValues(values, using: idType ?? StandardAlignmentID.self)
    }
    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    public static let leading = HorizontalAlignment(raw: -1, id: "leading")
    public static let center = HorizontalAlignment(raw: 0, id: "center")
    public static let trailing = HorizontalAlignment(raw: 1, id: "trailing")
    public static let listRowSeparatorLeading = HorizontalAlignment(raw: -1, id: "listRowSeparatorLeading")
    public static let listRowSeparatorTrailing = HorizontalAlignment(raw: 1, id: "listRowSeparatorTrailing")
    func defaultValue(_ d: ViewDimensions) -> CGFloat {
        custom?(d) ?? (raw < 0 ? 0 : raw > 0 ? d.width : d.width / 2)
    }
}

public struct VerticalAlignment: Equatable {
    let raw: Int
    let id: String
    let custom: ((ViewDimensions) -> CGFloat)?
    let idType: AlignmentID.Type?
    init(raw: Int, id: String) { self.raw = raw; self.id = id; custom = nil; idType = nil }
    public init(_ id: AlignmentID.Type) { raw = 0; self.id = "\(id)"; custom = { id.defaultValue(in: $0) }; idType = id }
    public func combineExplicit<S: Sequence>(_ values: S) -> CGFloat? where S.Element == CGFloat? {
        combineExplicitValues(values, using: idType ?? StandardAlignmentID.self)
    }
    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    public static let top = VerticalAlignment(raw: -1, id: "top")
    public static let center = VerticalAlignment(raw: 0, id: "center")
    public static let bottom = VerticalAlignment(raw: 1, id: "bottom")
    public static let firstTextBaseline = VerticalAlignment(raw: -1, id: "firstTextBaseline")
    public static let lastTextBaseline = VerticalAlignment(raw: 1, id: "lastTextBaseline")
    func defaultValue(_ d: ViewDimensions) -> CGFloat {
        custom?(d) ?? (raw < 0 ? 0 : raw > 0 ? d.height : d.height / 2)
    }
}

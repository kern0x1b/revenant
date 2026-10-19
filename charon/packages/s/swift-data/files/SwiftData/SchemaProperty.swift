// The four kinds of thing a schema entity can hold: an attribute, a composite of attributes, a
// relationship, and - on iOS 18 and later - an index or a uniqueness constraint over them.
//
// A metatype is not `Encodable`, and a value's type is part of what an attribute says, so a type
// is written by name and read back through the table of the types this process has: a schema
// describes the rows of a store, and the process reading one is the one that knows the models.

import Foundation

public protocol SchemaProperty: Decodable, Encodable, Hashable {
    var name: String { get set }
    var originalName: String { get set }
    var valueType: any Any.Type { get set }
    var isAttribute: Bool { get }
    var isRelationship: Bool { get }
    var isTransient: Bool { get }
    var isOptional: Bool { get }
    var isUnique: Bool { get }
}

extension SchemaProperty {
    public var isAttribute: Bool { false }
    public var isRelationship: Bool { false }
    public var isTransient: Bool { false }
    public var isOptional: Bool { false }
    public var isUnique: Bool { false }
}

/// The property names an index is built over, which is all a store needs of one. A generic
/// `Schema.Index<T>` cannot be tested for with `is` from outside its own generic parameter, so
/// the kinds answer this themselves.
protocol IndexNaming {
    var indexPropertyNames: [[String]] { get }
}

/// The property names each uniqueness constraint names, likewise.
protocol UniqueNaming {
    var uniquePropertyNames: [[String]] { get }
}

/// The type names a written schema carries, and the types this process knows them as. A model type
/// registers itself when it becomes an entity, which is every model type a program opens a
/// container with; a name nothing registered reads back as `Any`, and an attribute of `Any` is
/// transformable, which is the one Core Data type a value of no known type can be stored as.
enum SchemaTypeNames {
    private static var known: [String: any Any.Type] = [:]

    static func register(_ type: any Any.Type) {
        known["\(type)"] = type
    }

    static func resolve(_ name: String) -> any Any.Type {
        known[name] ?? Any.self
    }
}

// MARK: - Attribute

extension Schema {
    public class Attribute: SchemaProperty, CustomDebugStringConvertible {
        /// What an attribute may carry. A struct and not an enum, because two options are
        /// answers to the same question - a transformable is named either by the transformer that
        /// does it or by a name - and Apple's is a struct for the same reason.
        public struct Option: Codable, Hashable, CustomDebugStringConvertible {
            enum Kind: String, Codable {
                case unique, transformable, externalStorage, allowsCloudEncryption
                case preserveValueOnDeletion, ephemeral, spotlight
            }

            let kind: Kind
            /// The transformer's name, for `.transformable` only; empty otherwise, which is what
            /// says the option carries no name.
            let transformer: String

            init(kind: Kind, transformer: String = "") {
                self.kind = kind
                self.transformer = transformer
            }

            public static var unique: Option { Option(kind: .unique) }
            public static var externalStorage: Option { Option(kind: .externalStorage) }
            public static var allowsCloudEncryption: Option { Option(kind: .allowsCloudEncryption) }
            public static var preserveValueOnDeletion: Option { Option(kind: .preserveValueOnDeletion) }
            public static var ephemeral: Option { Option(kind: .ephemeral) }
            public static var spotlight: Option { Option(kind: .spotlight) }

            /// A transformable is named by the transformer's class name, which is the name
            /// `NSValueTransformer`'s own registry is keyed by and therefore the name
            /// `NSAttributeDescription.valueTransformerName` takes.
            public static func transformable(by transformerType: ValueTransformer.Type) -> Option {
                Option(kind: .transformable, transformer: NSStringFromClass(transformerType))
            }

            public static func transformable(by transformerName: String) -> Option {
                Option(kind: .transformable, transformer: transformerName)
            }

            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.kind = try container.decode(Kind.self, forKey: .kind)
                self.transformer = try container.decodeIfPresent(String.self, forKey: .transformer) ?? ""
            }

            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(kind, forKey: .kind)
                if kind == .transformable { try container.encode(transformer, forKey: .transformer) }
            }

            enum CodingKeys: String, CodingKey { case kind, transformer }

            public static func == (lhs: Option, rhs: Option) -> Bool {
                lhs.kind == rhs.kind && lhs.transformer == rhs.transformer
            }

            public func hash(into hasher: inout Hasher) {
                hasher.combine(kind)
                hasher.combine(transformer)
            }

            public var hashValue: Int {
                var hasher = Hasher()
                hash(into: &hasher)
                return hasher.finalize()
            }

            public var debugDescription: String {
                kind == .transformable ? "transformable(\(transformer))" : "\(kind)"
            }
        }

        public var name: String
        public var originalName: String
        public var options: [Option]
        public var valueType: any Any.Type
        public var defaultValue: Any?
        public var isOptional: Bool
        public var hashModifier: String?

        public var isAttribute: Bool { true }
        public var isRelationship: Bool { false }
        public var isTransient: Bool { false }
        public var isUnique: Bool { options.contains(.unique) }
        public var isTransformable: Bool { options.contains { $0.kind == .transformable } }

        /// The name of the transformer this attribute is stored through, or nil when it is not a
        /// transformable. `NSAttributeDescription.valueTransformerName` takes this, and a
        /// transformable with no transformer is stored by `NSCoding`, which is the release's own
        /// default and not the same thing.
        public var transformerName: String? {
            options.first { $0.kind == .transformable }?.transformer
        }

        public init(_ options: Option..., originalName: String? = nil, hashModifier: String? = nil) {
            self.name = ""
            self.originalName = originalName ?? ""
            self.options = options
            self.valueType = Any.self
            self.defaultValue = nil
            self.isOptional = true
            self.hashModifier = hashModifier
        }

        public init(name: String, originalName: String? = nil, options: [Option] = [],
                    valueType: any Any.Type, defaultValue: Any? = nil, hashModifier: String? = nil) {
            self.name = name
            self.originalName = originalName ?? name
            self.options = options
            self.valueType = valueType
            self.defaultValue = defaultValue
            self.isOptional = defaultValue == nil
            self.hashModifier = hashModifier
            SchemaTypeNames.register(valueType)
        }

        private enum CodingKeys: String, CodingKey {
            case name, originalName, options, valueType, defaultValue, isOptional, hashModifier
        }

        public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.originalName = try container.decode(String.self, forKey: .originalName)
            self.options = try container.decode([Option].self, forKey: .options)
            self.valueType = SchemaTypeNames.resolve(try container.decode(String.self, forKey: .valueType))
            self.defaultValue = try container.decodeIfPresent(PropertyValue.self, forKey: .defaultValue)?.value
            self.isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? (defaultValue == nil)
            self.hashModifier = try container.decodeIfPresent(String.self, forKey: .hashModifier)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(originalName, forKey: .originalName)
            try container.encode(options, forKey: .options)
            try container.encode("\(valueType)", forKey: .valueType)
            if let defaultValue { try container.encode(PropertyValue(defaultValue), forKey: .defaultValue) }
            try container.encode(isOptional, forKey: .isOptional)
            try container.encodeIfPresent(hashModifier, forKey: .hashModifier)
        }

        public static func == (lhs: Attribute, rhs: Attribute) -> Bool {
            lhs.name == rhs.name && lhs.originalName == rhs.originalName
                && lhs.options == rhs.options && "\(lhs.valueType)" == "\(rhs.valueType)"
                && String(describing: lhs.defaultValue) == String(describing: rhs.defaultValue)
                && lhs.isOptional == rhs.isOptional && lhs.hashModifier == rhs.hashModifier
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(originalName)
            for option in options { hasher.combine(option) }
            hasher.combine("\(valueType)")
            hasher.combine(hashModifier)
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }

        public var debugDescription: String {
            "Attribute(\(name): \(valueType)\(isOptional ? "?" : ""))"
        }
    }

    /// An attribute whose value is built out of others, iOS 17 and later. The store of the port
    /// has no such type - `NSCompositeAttributeType` is iOS 17.0 and nothing carries it for
    /// iOS 6 - so a composite is stored as the transformable it is, with the properties it is
    /// built from named beside it.
    public final class CompositeAttribute: Attribute {
        public final var properties: [Attribute]

        public override init(name: String, originalName: String? = nil, options: [Option] = [],
                             valueType: any Any.Type, defaultValue: Any? = nil, hashModifier: String? = nil) {
            self.properties = []
            super.init(name: name, originalName: originalName, options: options, valueType: valueType,
                       defaultValue: defaultValue, hashModifier: hashModifier)
            if !options.contains(where: { $0.kind == .transformable }) {
                self.options = [.transformable(by: "NSSecureUnarchiveFromDataTransformerName")]
            }
        }

        public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CompositeKeys.self)
            self.properties = try container.decode([Attribute].self, forKey: .properties)
            try super.init(from: decoder)
        }

        public override func encode(to encoder: any Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CompositeKeys.self)
            try container.encode(properties, forKey: .properties)
        }

        public override var debugDescription: String {
            "CompositeAttribute(\(name): \(properties.map { $0.name }.joined(separator: ", ")))"
        }

        enum CompositeKeys: String, CodingKey { case properties }
    }
}

// MARK: - Relationship

extension Schema {
    public final class Relationship: SchemaProperty, CustomDebugStringConvertible {
        public struct Option: Codable, Hashable, CustomDebugStringConvertible {
            public static var unique: Option { Option(kind: "unique") }
            let kind: String

            init(kind: String) {
                self.kind = kind
            }

            public init(from decoder: any Decoder) throws {
                self.kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
            }

            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(kind, forKey: .kind)
            }

            enum CodingKeys: String, CodingKey { case kind }

            public static func == (a: Option, b: Option) -> Bool { a.kind == b.kind }

            public func hash(into hasher: inout Hasher) { hasher.combine(kind) }

            public var hashValue: Int {
                var hasher = Hasher()
                hash(into: &hasher)
                return hasher.finalize()
            }

            public var debugDescription: String { kind }
        }

        public enum DeleteRule: String, Codable, Equatable, Hashable, Sendable {
            case noAction, nullify, cascade, deny
        }

        public var name: String
        public var originalName: String
        public var keypath: AnyKeyPath?
        public var options: [Option]
        public var valueType: any Any.Type
        public var destination: String
        public var deleteRule: DeleteRule
        public var inverseName: String?
        public var inverseKeyPath: AnyKeyPath?
        public var minimumModelCount: Int?
        public var maximumModelCount: Int?
        public var hashModifier: String?

        public var isAttribute: Bool { false }
        public var isRelationship: Bool { true }
        public var isTransient: Bool { false }
        public var isUnique: Bool { options.contains(.unique) }

        /// A to-one relationship is one whose far end holds at most one row: a maximum of one.
        /// Apple's `maximumModelCount` of nil is "no bound", and no bound is not a to-one.
        public var isToOneRelationship: Bool { maximumModelCount == 1 }

        public init(_ options: Option..., deleteRule: DeleteRule = .nullify, minimumModelCount: Int? = 0,
                    maximumModelCount: Int? = 0, originalName: String? = nil, inverse: AnyKeyPath? = nil,
                    hashModifier: String? = nil) {
            self.name = ""
            self.originalName = originalName ?? ""
            self.keypath = nil
            self.options = options
            self.valueType = Any.self
            self.destination = ""
            self.deleteRule = deleteRule
            self.inverseName = nil
            self.inverseKeyPath = inverse
            self.minimumModelCount = minimumModelCount
            self.maximumModelCount = maximumModelCount
            self.hashModifier = hashModifier
        }

        private enum CodingKeys: String, CodingKey {
            case name, originalName, options, valueType, destination, deleteRule, inverseName
            case minimumModelCount, maximumModelCount, hashModifier, keypath, inverseKeyPath
        }

        public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.originalName = try container.decode(String.self, forKey: .originalName)
            self.options = try container.decode([Option].self, forKey: .options)
            self.valueType = SchemaTypeNames.resolve(try container.decode(String.self, forKey: .valueType))
            self.destination = try container.decode(String.self, forKey: .destination)
            self.deleteRule = try container.decode(DeleteRule.self, forKey: .deleteRule)
            self.inverseName = try container.decodeIfPresent(String.self, forKey: .inverseName)
            self.minimumModelCount = try container.decodeIfPresent(Int.self, forKey: .minimumModelCount)
            self.maximumModelCount = try container.decodeIfPresent(Int.self, forKey: .maximumModelCount)
            self.hashModifier = try container.decodeIfPresent(String.self, forKey: .hashModifier)
            self.keypath = nil
            self.inverseKeyPath = nil
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(originalName, forKey: .originalName)
            try container.encode(options, forKey: .options)
            try container.encode("\(valueType)", forKey: .valueType)
            try container.encode(destination, forKey: .destination)
            try container.encode(deleteRule, forKey: .deleteRule)
            try container.encodeIfPresent(inverseName, forKey: .inverseName)
            try container.encodeIfPresent(minimumModelCount, forKey: .minimumModelCount)
            try container.encodeIfPresent(maximumModelCount, forKey: .maximumModelCount)
            try container.encodeIfPresent(hashModifier, forKey: .hashModifier)
            // A key path is not Encodable, so one is written as the name it reaches its property
            // by and read back as the same name; `inverseName` and `destination` are what a
            // store needs, and they are written beside it.
            if let keypath { try container.encode("\(keypath)", forKey: .keypath) }
            if let inverseKeyPath { try container.encode("\(inverseKeyPath)", forKey: .inverseKeyPath) }
        }

        public static func == (lhs: Relationship, rhs: Relationship) -> Bool {
            lhs.name == rhs.name && lhs.originalName == rhs.originalName && lhs.options == rhs.options
                && "\(lhs.valueType)" == "\(rhs.valueType)" && lhs.destination == rhs.destination
                && lhs.deleteRule == rhs.deleteRule && lhs.inverseName == rhs.inverseName
                && lhs.minimumModelCount == rhs.minimumModelCount
                && lhs.maximumModelCount == rhs.maximumModelCount && lhs.hashModifier == rhs.hashModifier
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(originalName)
            for option in options { hasher.combine(option) }
            hasher.combine("\(valueType)")
            hasher.combine(destination)
            hasher.combine(deleteRule)
            hasher.combine(inverseName)
            hasher.combine(minimumModelCount)
            hasher.combine(maximumModelCount)
            hasher.combine(hashModifier)
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }

        public var debugDescription: String {
            "Relationship(\(name) -> \(destination), \(deleteRule))"
        }
    }
}

// MARK: - Index and uniqueness, iOS 18

extension Schema {
    public final class Index<T>: SchemaProperty, CustomDebugStringConvertible where T: PersistentModel {
        public enum Types<P> where P: PersistentModel {
            case binary([PartialKeyPath<P>])
            case rtree([PartialKeyPath<P>])

            var propertyNames: [String] {
                switch self {
                case .binary(let paths), .rtree(let paths): return paths.map { "\($0)" }
                }
            }
        }

        public enum CodingKeys: String, CodingKey { case indices }

        public let indices: [Types<T>]

        public var name: String = ""
        public var originalName: String = ""
        public var valueType: any Any.Type = Any.self
        public var isUnique: Bool { false }

        public init(indices: [Types<T>]) {
            self.indices = indices
        }

        public convenience init(_ indices: Types<T>...) {
            self.init(indices: indices)
        }

        public convenience init(_ binaryIndices: [PartialKeyPath<T>]...) {
            self.init(indices: binaryIndices.map { Types.binary($0) })
        }

        public required init(from decoder: any Decoder) throws {
            self.indices = []
            _ = try decoder.container(keyedBy: CodingKeys.self).decode([String].self, forKey: .indices)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(indices.flatMap { $0.propertyNames }, forKey: .indices)
        }

        public static func == (lhs: Index<T>, rhs: Index<T>) -> Bool {
            lhs.indices.flatMap { $0.propertyNames } == rhs.indices.flatMap { $0.propertyNames }
        }

        public func hash(into hasher: inout Hasher) {
            for names in indices.flatMap({ [$0.propertyNames] }) { hasher.combine(names) }
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }

        public var debugDescription: String {
            "Index(\(indices.flatMap { $0.propertyNames }.joined(separator: ", ")))"
        }
    }

    public final class Unique<T>: SchemaProperty, CustomDebugStringConvertible where T: PersistentModel {
        public enum CodingKeys: String, CodingKey { case constraints }

        public let constraints: [[PartialKeyPath<T>]]

        public var name: String = ""
        public var originalName: String = ""
        public var valueType: any Any.Type = Any.self
        public var isUnique: Bool { true }

        public init(_ constraints: [PartialKeyPath<T>]...) {
            self.constraints = constraints
        }

        public required init(from decoder: any Decoder) throws {
            self.constraints = []
            _ = try decoder.container(keyedBy: CodingKeys.self).decode([[String]].self, forKey: .constraints)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(constraints.map { $0.map { "\($0)" } }, forKey: .constraints)
        }

        public static func == (lhs: Unique<T>, rhs: Unique<T>) -> Bool {
            lhs.constraints.map { $0.map { "\($0)" } } == rhs.constraints.map { $0.map { "\($0)" } }
        }

        public func hash(into hasher: inout Hasher) {
            for names in constraints.map({ $0.map { "\($0)" } }) { hasher.combine(names) }
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }

        public var debugDescription: String {
            "Unique(\(constraints.map { $0.map { "\($0)" }.joined(separator: "+") }.joined(separator: "|")))"
        }
    }
}

extension Schema.Index: IndexNaming {
    var indexPropertyNames: [[String]] { indices.map { $0.propertyNames } }
}

extension Schema.Unique: UniqueNaming {
    var uniquePropertyNames: [[String]] { constraints.map { $0.map { "\($0)" } } }
}

/// A written index, and a written uniqueness constraint, with no model type behind them: what a
/// decoded schema holds for a property it cannot rebuild, since the key paths of a generic type
/// are not in the file.
struct IndexNames: SchemaProperty, IndexNaming {
    var name: String
    var originalName: String = ""
    var valueType: any Any.Type
    let indices: [String]

    var indexPropertyNames: [[String]] { [indices] }

    private enum CodingKeys: String, CodingKey { case name, indices }

    var isUnique: Bool { false }

    init(name: String, valueType: any Any.Type, indices: [String]) {
        self.name = name
        self.valueType = valueType
        self.indices = indices
    }

    static func == (lhs: IndexNames, rhs: IndexNames) -> Bool {
        lhs.name == rhs.name && lhs.indices == rhs.indices
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(indices)
    }

    var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.indices = try container.decode([String].self, forKey: .indices)
        self.valueType = String.self
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(indices, forKey: .indices)
    }
}

struct UniqueNames: SchemaProperty, UniqueNaming {
    var name: String
    var originalName: String = ""
    var valueType: any Any.Type
    let constraints: [[String]]

    var uniquePropertyNames: [[String]] { constraints }

    private enum CodingKeys: String, CodingKey { case name, constraints }

    init(name: String, valueType: any Any.Type, constraints: [[String]]) {
        self.name = name
        self.valueType = valueType
        self.constraints = constraints
    }

    static func == (lhs: UniqueNames, rhs: UniqueNames) -> Bool {
        lhs.name == rhs.name && lhs.constraints == rhs.constraints
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(constraints)
    }

    var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.constraints = try container.decode([[String]].self, forKey: .constraints)
        self.valueType = [[String]].self
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(constraints, forKey: .constraints)
    }
}

/// A value of any type, written as what `JSONEncoder` can carry. A default value is a literal the
/// source wrote, so it is a string, a number, a boolean, a null or a list of those - and that is
/// what it reads back as, which is what `PropertyMetadata.defaultValue` hands a model that asks.
struct PropertyValue: Codable {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Int64.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else {
            self.value = try container.decode([PropertyValue].self).map { $0.value }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as Bool: try container.encode(value)
        case let value as Int: try container.encode(value)
        case let value as Int64: try container.encode(value)
        case let value as Double: try container.encode(value)
        case let value as String: try container.encode(value)
        case let value as [Any]: try container.encode(value.map { PropertyValue($0) })
        case is NSNull: try container.encodeNil()
        default: try container.encode(String(describing: value))
        }
    }
}

extension Schema.Attribute: @unchecked Sendable {}
extension Schema.Relationship: @unchecked Sendable {}
extension Schema.Index: @unchecked Sendable {}
extension Schema.Unique: @unchecked Sendable {}

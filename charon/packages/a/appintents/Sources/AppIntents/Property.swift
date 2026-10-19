// The property of an entity an intent can be asked about, and the modifiers such a property carries.

import Foundation

/// A property of an entity, which is a parameter of the intent that asks about it. It is a property
/// wrapper of its own: an entity writes `@Parameter(title: "Rating") var rating: Double`, and the
/// query reads the parameter the wrapper holds.
@propertyWrapper
public final class EntityProperty<Value>: @unchecked Sendable where Value: _IntentValue {
    /// The value the property holds. A property the app has not given a value for holds none, and
    /// reading it stops with the property's own name, which is what the framework's own property
    /// wrapper does: a query that needs the value reads it through the getter the app gave.
    public var wrappedValue: Value {
        get {
            guard let held = value else {
                CharonUnset.fatal("the property \(indexingKey) holds no value")
            }
            return held
        }
        set {
            value = newValue
            valueSet = true
        }
    }
    public var projectedValue: EntityProperty<Value> { return self }

    /// The name the property is indexed and searched under.
    public var indexingKey: String
    /// The name the property is shown with.
    public var title: LocalizedStringResource
    /// Whether the property may have no value.
    public var isOptional: Bool
    /// What the property's name is, as the index stores it.
    public var identifier: String
    /// The modifiers the property carries, added in iOS 26.
    public var modifiers: EntityPropertyModifiers
    /// Whether the property is only read and never written by an intent.
    public var isReadOnly: Bool
    /// The getter the property is read with, which a property that is indexed asynchronously uses.
    public var getter: ((EntityProperty<Value>) async -> Value)?
    /// The setter the property is written with.
    public var setter: ((Value) async -> Void)?

    private var value: Value?
    private var valueSet = false

    public init() {
        self.value = nil
        self.indexingKey = ""
        self.title = CharonLocalized.resource("")
        self.isOptional = true
        self.identifier = ""
        self.modifiers = []
        self.isReadOnly = false
        self.getter = nil
        self.setter = nil
    }

    public convenience init(title: LocalizedStringResource) {
        self.init()
        self.title = title
        self.indexingKey = CharonLocalized.string(of: title)
        self.isOptional = false
    }

    /// Whether the property holds a value, which is what an index asks before it reads one.
    public var hasValue: Bool { return value != nil }

    public convenience init(title: LocalizedStringResource, indexingKey: String) {
        self.init(title: title)
        self.indexingKey = indexingKey
    }

    public convenience init(title: LocalizedStringResource, customIndexingKey: String) {
        self.init(title: title)
        self.indexingKey = customIndexingKey
    }


    public convenience init(customIndexingKey: String) {
        self.init()
        self.indexingKey = customIndexingKey
    }

    public convenience init(indexingKey: String) {
        self.init()
        self.indexingKey = indexingKey
    }

    public convenience init(identifier: String) {
        self.init()
        self.identifier = identifier
        self.indexingKey = identifier
    }

    public convenience init(identifier: String, title: LocalizedStringResource) {
        self.init(identifier: identifier)
        self.title = title
    }

    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: String) {
        self.init(identifier: identifier, title: title)
        self.indexingKey = indexingKey
    }

    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: String,
                customIndexingKey: String) {
        self.init(identifier: identifier, title: title)
        self.indexingKey = customIndexingKey
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String) {
        self.init(identifier: identifier, title: title)
        self.indexingKey = customIndexingKey
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String, indexingKey: String) {
        self.init(identifier: identifier, title: title)
        self.indexingKey = indexingKey
    }

    public convenience init(identifier: String, customIndexingKey: String) {
        self.init(identifier: identifier)
        self.indexingKey = customIndexingKey
    }

    public convenience init(identifier: String, indexingKey: String) {
        self.init(identifier: identifier)
        self.indexingKey = indexingKey
    }

    public convenience init(identifier: String, customIndexingKey: String, indexingKey: String) {
        self.init(identifier: identifier)
        self.indexingKey = indexingKey
    }

    public convenience init(identifier: String, getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, title: LocalizedStringResource,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, title: title)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, title: LocalizedStringResource, asyncGetter: Bool) {
        self.init(identifier: identifier, title: title)
        if asyncGetter { self.modifiers = [.async] }
    }

    public convenience init(identifier: String, customIndexingKey: String,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier)
        self.indexingKey = customIndexingKey
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, title: title, customIndexingKey: customIndexingKey)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: String,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, title: title, indexingKey: indexingKey)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String, indexingKey: String,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, title: title, indexingKey: indexingKey)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier)
        self.setter = getSetter
    }

    /// The three combinations the framework names that this had not: the asynchronous getter on its
    /// own, and the indexing key with a getter or with a setter. Each is the same property the
    /// neighbours above build, with the part the argument names: a getter reads the value the index
    /// stores, a setter writes one back, and `indexingKey` is the name the index holds it under --
    /// which is why the key is the second argument rather than a title, and why a property with both
    /// a getter and a setter is one the app may write.
    public convenience init(identifier: String, asyncGetter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier)
        self.getter = asyncGetter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, indexingKey: String, getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier, indexingKey: indexingKey)
        self.setter = getSetter
    }

    public convenience init(identifier: String, indexingKey: String, getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, indexingKey: indexingKey)
        self.getter = getter
        self.modifiers = [.async]
    }

    public convenience init(identifier: String, customIndexingKey: String, getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier)
        self.indexingKey = customIndexingKey
        self.setter = getSetter
    }

    public convenience init(identifier: String, title: LocalizedStringResource, getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier, title: title)
        self.setter = getSetter
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String,
                getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier, title: title, customIndexingKey: customIndexingKey)
        self.setter = getSetter
    }

    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: String,
                getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier, title: title, indexingKey: indexingKey)
        self.setter = getSetter
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String, indexingKey: String,
                getSetter: @escaping (Value) async -> Void) {
        self.init(identifier: identifier, title: title, indexingKey: indexingKey)
        self.setter = getSetter
    }

    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: String,
                getSetter: @escaping (Value) async -> Void,
                getter: @escaping (EntityProperty<Value>) async -> Value) {
        self.init(identifier: identifier, title: title, customIndexingKey: customIndexingKey)
        self.setter = getSetter
        self.getter = getter
    }

    /// What the index stores for a property, which is its name and the value it holds.
    public struct IndexRecord: Codable {
        public let key: String
        public let value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(identifier: try container.decode(String.self, forKey: .identifier))
        if let title = try container.decodeIfPresent(String.self, forKey: .title) { self.title = CharonLocalized.resource(title) }
        if let key = try container.decodeIfPresent(String.self, forKey: .indexingKey) { self.indexingKey = key }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(CharonLocalized.string(of: title), forKey: .title)
        try container.encode(indexingKey, forKey: .indexingKey)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case title
        case indexingKey
    }
}

extension EntityProperty: CustomStringConvertible {
    /// The property's name as the index and a search result show it.
    public var description: String { return CharonLocalized.string(of: title) }
}

/// What a property of an entity may and may not do, added in iOS 26.
public struct EntityPropertyModifiers: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The property is read without the entity being read whole, which is what an entity too large to
    /// index at once needs.
    public static let async = EntityPropertyModifiers(rawValue: 1 << 0)
    /// The property is read and never written by an intent.
    public static let readOnly = EntityPropertyModifiers(rawValue: 1 << 1)
}

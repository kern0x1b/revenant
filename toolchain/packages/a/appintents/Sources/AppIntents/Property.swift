import Foundation

@propertyWrapper
public final class EntityProperty<Value>: @unchecked Sendable where Value: _IntentValue {
    public var wrappedValue: Value {
        get {
            guard let held = value else {
                RevenantUnset.fatal("the property \(indexingKey) holds no value")
            }
            return held
        }
        set {
            value = newValue
            valueSet = true
        }
    }
    public var projectedValue: EntityProperty<Value> { return self }

    public var indexingKey: String
    public var title: LocalizedStringResource
    public var isOptional: Bool
    public var identifier: String
    public var modifiers: EntityPropertyModifiers
    public var isReadOnly: Bool
    public var getter: ((EntityProperty<Value>) async -> Value)?
    public var setter: ((Value) async -> Void)?

    private var value: Value?
    private var valueSet = false

    public init() {
        self.value = nil
        self.indexingKey = ""
        self.title = RevenantLocalized.resource("")
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
        self.indexingKey = RevenantLocalized.string(of: title)
        self.isOptional = false
    }

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
        if let title = try container.decodeIfPresent(String.self, forKey: .title) { self.title = RevenantLocalized.resource(title) }
        if let key = try container.decodeIfPresent(String.self, forKey: .indexingKey) { self.indexingKey = key }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(RevenantLocalized.string(of: title), forKey: .title)
        try container.encode(indexingKey, forKey: .indexingKey)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case title
        case indexingKey
    }
}

extension EntityProperty: CustomStringConvertible {
    public var description: String { return RevenantLocalized.string(of: title) }
}

public struct EntityPropertyModifiers: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let async = EntityPropertyModifiers(rawValue: 1 << 0)
    public static let readOnly = EntityPropertyModifiers(rawValue: 1 << 1)
}

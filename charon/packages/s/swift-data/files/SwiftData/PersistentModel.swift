import Foundation
import CoreData
import Observation

public protocol PersistentModel: AnyObject, Observable, Hashable, Identifiable, SendableMetatype {
    init(backingData: any BackingData<Self>)
    var persistentBackingData: any BackingData<Self> { get set }
    static var schemaMetadata: [Schema.PropertyMetadata] { get }
}

extension PersistentModel {
    public static func createBackingData<P>() -> some BackingData<P> where P: PersistentModel {
        CoreDataBacking<P>(for: P.self)
    }

    public var persistentModelID: PersistentIdentifier {
        persistentBackingData.persistentModelID ?? PersistentIdentifier.unregistered
    }

    public var id: PersistentIdentifier { persistentModelID }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(persistentModelID)
    }

    public var modelContext: ModelContext? { persistentBackingData.modelContext }

    public var isDeleted: Bool { persistentBackingData.isDeleted }

    public var hasChanges: Bool { persistentBackingData.hasChanges }

    @_disfavoredOverload
    public func getValue<Value>(forKey keyPath: KeyPath<Self, Value>) -> Value where Value: Decodable {
        persistentBackingData.getValue(forKey: keyPath)
    }

    public func getValue<Value>(forKey keyPath: KeyPath<Self, Value>) -> Value where Value: PersistentModel {
        persistentBackingData.getValue(forKey: keyPath)
    }

    public func getValue<Value>(forKey keyPath: KeyPath<Self, Value?>) -> Value? where Value: PersistentModel {
        persistentBackingData.getValue(forKey: keyPath)
    }

    public func getValue<Value, OtherModel>(forKey keyPath: KeyPath<Self, Value>) -> Value
    where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        persistentBackingData.getValue(forKey: keyPath)
    }

    public func getValue<Value, OtherModel>(forKey keyPath: KeyPath<Self, Value>) -> Value
    where Value: Decodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        persistentBackingData.getValue(forKey: keyPath)
    }

    public func getTransformableValue<Value>(forKey keyPath: KeyPath<Self, Value>) -> Value {
        persistentBackingData.getTransformableValue(forKey: keyPath)
    }

    @_disfavoredOverload
    public func setValue<Value>(forKey keyPath: KeyPath<Self, Value>, to newValue: Value) where Value: Encodable {
        persistentBackingData.setValue(forKey: keyPath, to: newValue)
    }

    public func setValue<Value>(forKey keyPath: KeyPath<Self, Value>, to newValue: Value) where Value: PersistentModel {
        persistentBackingData.setValue(forKey: keyPath, to: newValue)
    }

    public func setValue<Value>(forKey keyPath: KeyPath<Self, Value?>, to newValue: Value?) where Value: PersistentModel {
        persistentBackingData.setValue(forKey: keyPath, to: newValue)
    }

    public func setValue<Value, OtherModel>(forKey keyPath: KeyPath<Self, Value>, to newValue: Value)
    where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        persistentBackingData.setValue(forKey: keyPath, to: newValue)
    }

    public func setValue<Value, OtherModel>(forKey keyPath: KeyPath<Self, Value>, to newValue: Value)
    where Value: Encodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        persistentBackingData.setValue(forKey: keyPath, to: newValue)
    }

    public func setTransformableValue<Value>(forKey keyPath: KeyPath<Self, Value>, to newValue: Value) {
        persistentBackingData.setTransformableValue(forKey: keyPath, to: newValue)
    }
}

public protocol RelationshipCollection {
    associatedtype PersistentElement: PersistentModel
}

extension Array: RelationshipCollection where Element: PersistentModel {
    public typealias PersistentElement = Element
}

extension Optional: RelationshipCollection where Wrapped: Sequence, Wrapped.Element: PersistentModel {
    public typealias PersistentElement = Wrapped.Element
}

public protocol BackingData<Model> {
    associatedtype Model: PersistentModel
    init(for modelType: Model.Type)
    var persistentModelID: PersistentIdentifier? { get set }
    var metadata: Any { get }

    @_disfavoredOverload func getValue<Value>(forKey: KeyPath<Model, Value>) -> Value where Value: Decodable
    func getValue<Value>(forKey: KeyPath<Model, Value>) -> Value where Value: PersistentModel
    func getValue<Value>(forKey: KeyPath<Model, Value?>) -> Value? where Value: PersistentModel
    func getValue<Value, OtherModel>(forKey: KeyPath<Model, Value>) -> Value
        where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func getValue<Value, OtherModel>(forKey: KeyPath<Model, Value>) -> Value
        where Value: Decodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func getTransformableValue<Value>(forKey: KeyPath<Model, Value>) -> Value
    @_disfavoredOverload func setValue<Value>(forKey: KeyPath<Model, Value>, to newValue: Value) where Value: Encodable
    func setValue<Value>(forKey: KeyPath<Model, Value>, to newValue: Value) where Value: PersistentModel
    func setValue<Value>(forKey: KeyPath<Model, Value?>, to newValue: Value?) where Value: PersistentModel
    func setValue<Value, OtherModel>(forKey: KeyPath<Model, Value>, to newValue: Value)
        where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func setValue<Value, OtherModel>(forKey: KeyPath<Model, Value>, to newValue: Value)
        where Value: Encodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func setTransformableValue<Value>(forKey: KeyPath<Model, Value>, to newValue: Value)

    func _generateCurrentClassBackingData<CurrentClass>() -> any BackingData<CurrentClass> where CurrentClass: PersistentModel
    func _superClassBackingData<SuperClass>(of givenType: any PersistentModel.Type) -> any BackingData<SuperClass> where SuperClass: PersistentModel
}

extension BackingData {
    public var entityName: String { Schema.entityName(for: Model.self) }

    public var modelContext: ModelContext? { nil }
    public var isDeleted: Bool { false }
    public var hasChanges: Bool { false }
}

extension PersistentIdentifier {
    public static let unregistered = PersistentIdentifier(uri: URL(fileURLWithPath: "/dev/null"), entityName: "")
}

struct AnyEncodable: Encodable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: any Encoder) throws {
        if let encodable = value as? any Encodable { try encodable.encode(to: encoder) }
        var container = encoder.singleValueContainer()
        try container.encode(String(describing: value))
    }
}

struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let decoded = try? container.decode(Bool.self) {
            self.value = decoded
        } else if let decoded = try? container.decode(Int64.self) {
            self.value = decoded
        } else if let decoded = try? container.decode(Double.self) {
            self.value = decoded
        } else if let decoded = try? container.decode(String.self) {
            self.value = decoded
        } else {
            self.value = NSNull()
        }
    }

    func typed<T>(as type: T.Type) -> T? { value as? T }
}

enum StoredValue {
    static func box(_ value: Any) -> Any? {
        switch value {
        case let value as String: return value as NSString
        case let value as Int: return NSNumber(value: value)
        case let value as Int64: return NSNumber(value: value)
        case let value as Int32: return NSNumber(value: value)
        case let value as Int16: return NSNumber(value: value)
        case let value as UInt: return NSNumber(value: value)
        case let value as UInt64: return NSNumber(value: value)
        case let value as UInt32: return NSNumber(value: value)
        case let value as Double: return NSNumber(value: value)
        case let value as Float: return NSNumber(value: value)
        case let value as Bool: return NSNumber(value: value)
        case let value as Date: return value as NSDate
        case let value as Data: return value as NSData
        case let value as UUID: return value as NSUUID
        case let value as URL: return value as NSURL
        default: return nil
        }
    }

    static func cast<T>(_ value: Any?, to type: T.Type) -> T? {
        guard let value else { return nil }
        if let typed = value as? T { return typed }
        switch type {
        case is String.Type:
            if let number = value as? NSNumber { return number.stringValue as? T }
            return (value as? NSString) as? T
        case is Bool.Type:
            return (value as? NSNumber)?.boolValue as? T
        case is Int.Type, is Int64.Type, is Int32.Type, is Int16.Type, is UInt.Type, is UInt64.Type:
            return (value as? NSNumber)?.int64Value as? T
        case is Double.Type, is Float.Type:
            return (value as? NSNumber)?.doubleValue as? T
        case is Date.Type:
            return (value as? NSDate) as? T
        case is Data.Type:
            return (value as? NSData) as? T
        case is UUID.Type:
            return (value as? NSUUID) as? T
        case is URL.Type:
            return (value as? NSURL) as? T
        default:
            if let data = value as? Data, let any = try? JSONDecoder().decode(AnyDecodable.self, from: data),
               let decoded = any.typed(as: T.self) {
                return decoded
            }
            return nil
        }
    }

    static func zero<T>(of type: T.Type) -> T? {
        switch type {
        case is String.Type: return "" as? T
        case is Bool.Type: return false as? T
        case is Int.Type, is Int64.Type, is Int32.Type, is Int16.Type,
             is UInt.Type, is UInt64.Type, is UInt32.Type, is UInt16.Type, is UInt8.Type, is Int8.Type:
            return 0 as? T
        case is Double.Type, is Float.Type: return 0 as? T
        case is Date.Type: return Date(timeIntervalSince1970: 0) as? T
        case is Data.Type: return Data() as? T
        case is UUID.Type: return UUID(uuidString: "00000000-0000-0000-0000-000000000000") as? T
        case is URL.Type: return URL(fileURLWithPath: "/") as? T
        default: return nil
        }
    }

    static func store<T>(_ value: T) -> Any {
        if let boxed = box(value as Any) { return boxed }
        if let encoded = try? JSONEncoder().encode(AnyEncodable(value)) { return encoded as NSData }
        return value
    }
}

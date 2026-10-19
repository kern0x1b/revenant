import Foundation
import CoreData

public final class CoreDataBacking<Model: PersistentModel>: BackingData, @unchecked Sendable {
    weak var owner: Model?

    let context: NSManagedObjectContext

    public let object: NSManagedObject

    public var persistentModelID: PersistentIdentifier? {
        get {
            guard !object.objectID.isTemporaryID else { return nil }
            return PersistentIdentifier(object.objectID, entityName: object.entity.name ?? entityName)
        }
        set {
            try? context.obtainPermanentIDs(for: [object])
        }
    }

    public var metadata: Any { entityName }

    public var modelContext: ModelContext? { context.modelContext }

    public var isDeleted: Bool { object.isDeleted }

    public var hasChanges: Bool { object.hasChanges }

    public required init(for modelType: Model.Type) {
        self.context = ModelContext.detachedContext()
        self.object = NSManagedObject()
    }

    init(for modelType: Model.Type, object: NSManagedObject, context: NSManagedObjectContext, owner: Model?) {
        self.context = context
        self.object = object
        self.owner = owner
    }

    public func _generateCurrentClassBackingData<CurrentClass>() -> any BackingData<CurrentClass>
    where CurrentClass: PersistentModel {
        CoreDataBacking<CurrentClass>(for: CurrentClass.self, object: object, context: context, owner: nil)
    }

    public func _superClassBackingData<SuperClass>(of givenType: any PersistentModel.Type) -> any BackingData<SuperClass>
    where SuperClass: PersistentModel {
        CoreDataBacking<SuperClass>(for: SuperClass.self, object: object, context: context,
                                    owner: owner as? SuperClass)
    }

    func raw(_ key: String) -> Any? {
        if let set = object.value(forKey: key) as? Set<NSManagedObject> { return Array(set) }
        return object.value(forKey: key)
    }

    func write(_ key: String, _ value: Any?) {
        object.setValue(value, forKey: key)
    }

    static func propertyName<Value>(of keyPath: KeyPath<Model, Value>) -> String {
        keyPath._kvcKeyPathString ?? "\(keyPath)"
    }

    private func makeRow(_ row: NSManagedObject) -> any PersistentModel? {
        context.modelContext?.model(forObject: row)
    }

    @_disfavoredOverload
    public func getValue<Value>(forKey keyPath: KeyPath<Model, Value>) -> Value where Value: Decodable {
        Model.storedValue(raw(CoreDataBacking.propertyName(of: keyPath)), for: keyPath, entity: entityName)
    }

    public func getValue<Value>(forKey keyPath: KeyPath<Model, Value>) -> Value where Value: PersistentModel {
        guard let row = raw(CoreDataBacking.propertyName(of: keyPath)) as? NSManagedObject,
              let made = makeRow(row), let typed = made as? Value else {
            return Value(backingData: Value.createBackingData())
        }
        return typed
    }

    public func getValue<Value>(forKey keyPath: KeyPath<Model, Value?>) -> Value? where Value: PersistentModel {
        guard let row = raw(CoreDataBacking.propertyName(of: keyPath)) as? NSManagedObject,
              let made = makeRow(row) else { return nil }
        return made as? Value
    }

    public func getValue<Value, OtherModel>(forKey keyPath: KeyPath<Model, Value>) -> Value
    where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        related(raw(CoreDataBacking.propertyName(of: keyPath)), as: Value.self)
    }

    public func getValue<Value, OtherModel>(forKey keyPath: KeyPath<Model, Value>) -> Value
    where Value: Decodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        related(raw(CoreDataBacking.propertyName(of: keyPath)), as: Value.self)
    }

    public func getTransformableValue<Value>(forKey keyPath: KeyPath<Model, Value>) -> Value {
        Model.storedValue(raw(CoreDataBacking.propertyName(of: keyPath)), for: keyPath, entity: entityName)
    }

    @_disfavoredOverload
    public func setValue<Value>(forKey keyPath: KeyPath<Model, Value>, to newValue: Value) where Value: Encodable {
        write(CoreDataBacking.propertyName(of: keyPath), StoredValue.store(newValue))
    }

    public func setValue<Value>(forKey keyPath: KeyPath<Model, Value>, to newValue: Value) where Value: PersistentModel {
        write(CoreDataBacking.propertyName(of: keyPath), newValue.backingObject)
    }

    public func setValue<Value>(forKey keyPath: KeyPath<Model, Value?>, to newValue: Value?) where Value: PersistentModel {
        write(CoreDataBacking.propertyName(of: keyPath), newValue?.backingObject)
    }

    public func setValue<Value, OtherModel>(forKey keyPath: KeyPath<Model, Value>, to newValue: Value)
    where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        write(CoreDataBacking.propertyName(of: keyPath), CoreDataBacking.rows(of: newValue as Any))
    }

    public func setValue<Value, OtherModel>(forKey keyPath: KeyPath<Model, Value>, to newValue: Value)
    where Value: Encodable, Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        write(CoreDataBacking.propertyName(of: keyPath), CoreDataBacking.rows(of: newValue as Any))
    }

    public func setTransformableValue<Value>(forKey keyPath: KeyPath<Model, Value>, to newValue: Value) {
        write(CoreDataBacking.propertyName(of: keyPath), StoredValue.store(newValue))
    }

    private func related<Value: RelationshipCollection>(_ value: Any?, as type: Value.Type) -> Value {
        var rows = [Value.PersistentElement]()
        var wanted = [NSManagedObject]()
        if let one = value as? NSManagedObject { wanted.append(one) }
        wanted.append(contentsOf: (value as? [NSManagedObject]) ?? [])
        for row in wanted {
            if let made = makeRow(row), let typed = made as? Value.PersistentElement { rows.append(typed) }
        }
        guard let array = rows as? Value else {
            preconditionFailure("a relationship of \(entityName) is read as \(Value.self), " +
                                "which is not the Array its RelationshipCollection conformance is for")
        }
        return array
    }

    static func rows(of value: Any) -> [NSManagedObject]? {
        if let one = value as? any PersistentModel { return one.backingObject.map { [$0] } }
        return (value as? any Sequence)?.compactMap { ($0 as? any PersistentModel)?.backingObject }
    }
}

extension PersistentModel {
    var backingObject: NSManagedObject? {
        (persistentBackingData as? CoreDataBacking<Self>)?.object
    }

    static func storedValue<Value>(_ value: Any?, for keyPath: KeyPath<Self, Value>,
                                   entity: String) -> Value {
        if let cast = StoredValue.cast(value, to: Value.self) { return cast }
        let name = keyPath._kvcKeyPathString ?? "\(keyPath)"
        for entry in schemaMetadata where entry.name == name || "\(entry.keypath)" == name {
            if let stored = StoredValue.cast(entry.defaultValue, to: Value.self) { return stored }
        }
        if let zero = StoredValue.zero(of: Value.self) { return zero }
        let given = value.map { "Swift.\(type(of: $0))" } ?? "Swift.Optional<Any>"
        let from = UInt(bitPattern: ObjectIdentifier(MetatypeBox.shared(Value.self)))
        let to = UInt(bitPattern: ObjectIdentifier(MetatypeBox.shared(givenValue(value))))
        preconditionFailure("Could not cast value of type '\(given)' (0x\(String(from, radix: 16))) to "
                            + "'Swift.\(Value.self)' (0x\(String(to, radix: 16))).")
    }
}


enum MetatypeBox {
    final class Box: @unchecked Sendable {
        let value: Any.Type

        init(_ type: Any.Type) { self.value = type }
    }

    static func shared(_ type: Any.Type) -> Box { Box(type) }
}

private func givenValue(_ value: Any?) -> Any.Type {
    value.map { type(of: $0) } ?? Any.self
}

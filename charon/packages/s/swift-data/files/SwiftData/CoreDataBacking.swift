// The Core Data behind a model: the NSManagedObject a context owns, and the two untyped doors
// every typed member of `BackingData` goes through.
//
// One row, one model, and a table in the context that keeps them paired. Every typed member is a
// thin wrapper over `raw(_:)` and `write(_:_:)`, so the conversion between a Swift value and what
// Core Data holds is written once, in `StoredValue`.

import Foundation
import CoreData

public final class CoreDataBacking<Model: PersistentModel>: BackingData, @unchecked Sendable {
    /// The model this storage is for. Weak, because the model holds this and a cycle between them
    /// would keep a deleted row alive for as long as the process is.
    weak var owner: Model?

    let context: NSManagedObjectContext

    /// The row. Public because a model's identity in a store is this object, and a context pairs
    /// models by it.
    public let object: NSManagedObject

    public var persistentModelID: PersistentIdentifier? {
        get {
            guard !object.objectID.isTemporaryID else { return nil }
            return PersistentIdentifier(object.objectID, entityName: object.entity.name ?? entityName)
        }
        set {
            // The port's headers of the release carry no -replaceObject:withObject:, so an
            // identifier cannot re-point a row. What the setter does is make the row's own
            // identity permanent, which is what it is for after a save.
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

    // MARK: The two doors

    func raw(_ key: String) -> Any? {
        if let set = object.value(forKey: key) as? Set<NSManagedObject> { return Array(set) }
        return object.value(forKey: key)
    }

    func write(_ key: String, _ value: Any?) {
        object.setValue(value, forKey: key)
    }

    /// The name of the property a key path names, which is what a Core Data property is called.
    /// The standard library's own `KeyPath._kvcKeyPathString`, unwrapped: on this release it is an
    /// optional, because a key path into a computed property has no name to give.
    static func propertyName<Value>(of keyPath: KeyPath<Model, Value>) -> String {
        keyPath._kvcKeyPathString ?? "\(keyPath)"
    }

    /// The model a row is read by, made now if this context has not made it: a row that arrives
    /// from a fetch has no model until one is asked for, and the same model comes back next time
    /// because the row remembers it.
    private func makeRow(_ row: NSManagedObject) -> any PersistentModel? {
        context.modelContext?.model(forObject: row)
    }

    // MARK: Reading

    @_disfavoredOverload
    public func getValue<Value>(forKey keyPath: KeyPath<Model, Value>) -> Value where Value: Decodable {
        Model.storedValue(raw(CoreDataBacking.propertyName(of: keyPath)), for: keyPath, entity: entityName)
    }

    public func getValue<Value>(forKey keyPath: KeyPath<Model, Value>) -> Value where Value: PersistentModel {
        guard let row = raw(CoreDataBacking.propertyName(of: keyPath)) as? NSManagedObject,
              let made = makeRow(row), let typed = made as? Value else {
            // A to-one relationship that has no row yet: a model of this property's own type with
            // no row behind it, which is what a program reads before it has set one.
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

    // MARK: Writing

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

    // MARK: The two conversions the typed members share

    /// A relationship read as the collection the model asked for. `RelationshipCollection` is
    /// conformed to by `Array` alone, so the collection is that, and the cast at the end says so
    /// out loud rather than quietly returning something else.
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

    /// The rows a collection holds: one for a model, and every one for a collection of them.
    static func rows(of value: Any) -> [NSManagedObject]? {
        if let one = value as? any PersistentModel { return one.backingObject.map { [$0] } }
        return (value as? any Sequence)?.compactMap { ($0 as? any PersistentModel)?.backingObject }
    }
}

extension PersistentModel {
    /// The Core Data object behind a model, or nil for a model that is in no context.
    var backingObject: NSManagedObject? {
        (persistentBackingData as? CoreDataBacking<Self>)?.object
    }

    /// What a property reads when the row has no value for it: the value `@Model` recorded as its
    /// starting one, and for the value types Core Data has a column for, that type's own zero.
    ///
    /// A property with neither is one the model requires and the store's row does not hold - a
    /// migration that added a required column, read through the new schema. Apple's own SwiftData
    /// does not answer that with a value or with an error either: it traps, in the dynamic cast
    /// that would turn the row's absent value into the property's type. Measured on the host with
    /// `.agent-work/probe/model/MissingValue.swift` compiled against Apple's SwiftData and run:
    ///
    ///     Could not cast value of type 'Swift.Optional<Any>' (0x1f3f60950) to 'Swift.Int' (0x1f3f5b2e8).
    ///     exit=134
    ///
    /// so the same trap with the same words is the answer here, and the values the addresses name
    /// are the two types of the cast that fails: what the row gave and what the property is.
    static func storedValue<Value>(_ value: Any?, for keyPath: KeyPath<Self, Value>,
                                   entity: String) -> Value {
        if let cast = StoredValue.cast(value, to: Value.self) { return cast }
        let name = keyPath._kvcKeyPathString ?? "\(keyPath)"
        for entry in schemaMetadata where entry.name == name || "\(entry.keypath)" == name {
            if let stored = StoredValue.cast(entry.defaultValue, to: Value.self) { return stored }
        }
        if let zero = StoredValue.zero(of: Value.self) { return zero }
        // The two things the failing cast names: what the row gave, and what the property is. The
        // addresses are of the type's metadata, which is what the runtime's own message carries
        // and what makes two runs' messages differ in those digits and nowhere else.
        let given = value.map { "Swift.\(type(of: $0))" } ?? "Swift.Optional<Any>"
        let from = UInt(bitPattern: ObjectIdentifier(MetatypeBox.shared(Value.self)))
        let to = UInt(bitPattern: ObjectIdentifier(MetatypeBox.shared(givenValue(value))))
        preconditionFailure("Could not cast value of type '\(given)' (0x\(String(from, radix: 16))) to "
                            + "'Swift.\(Value.self)' (0x\(String(to, radix: 16))).")
    }
}


enum MetatypeBox {
    /// A metatype as a class instance, which is what `ObjectIdentifier` can be built from: the two
    /// addresses in a cast message are the addresses of the two types' metadata. One instance is
    /// enough - what the address stands for is the metatype it carries, not the box.
    final class Box: @unchecked Sendable {
        let value: Any.Type

        init(_ type: Any.Type) { self.value = type }
    }

    static func shared(_ type: Any.Type) -> Box { Box(type) }
}

private func givenValue(_ value: Any?) -> Any.Type {
    value.map { type(of: $0) } ?? Any.self
}

import UIKit
import CoreGraphics

final class StateStorage<Value> {
    var value: Value { didSet { if !bytesEqual(oldValue, value) { node?.invalidate() } } }
    weak var node: CompositeNode?
    init(_ value: Value) { self.value = value }
}

@propertyWrapper
public struct State<Value>: DynamicProperty, DynamicPropertyInstaller {
    let initial: Value
    var storage: StateStorage<Value>?
    public init(wrappedValue value: Value) { initial = value }
    public init(initialValue value: Value) { initial = value }
    public var wrappedValue: Value {
        get { storage?.value ?? initial }
        nonmutating set { storage?.value = newValue }
    }
    public var projectedValue: Binding<Value> {
        let s = storage
        let i = initial
        return Binding(get: { s?.value ?? i }, set: { s?.value = $0 })
    }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: State<Value>.self)
        if let s = node.storages[key] as? StateStorage<Value> {
            p.pointee.storage = s
        } else {
            let s = StateStorage(p.pointee.initial)
            s.node = node
            node.storages[key] = s
            p.pointee.storage = s
        }
    }
}

extension State where Value: ExpressibleByNilLiteral {
    public init() { self.init(wrappedValue: nil) }
}

@propertyWrapper @dynamicMemberLookup
public struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
    public init(projectedValue: Binding<Value>) { self = projectedValue }
    public static func constant(_ value: Value) -> Binding<Value> { Binding(get: { value }, set: { _ in }) }
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(get: { self.get()[keyPath: keyPath] }, set: { var v = self.get(); v[keyPath: keyPath] = $0; self.set(v) })
    }
}

final class ObjectSubscription {
    var cancellable: AnyCancellable?
    var object: AnyObject?
}

@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty, DynamicPropertyInstaller {
    @dynamicMemberLookup
    public struct Wrapper {
        let object: ObjectType
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let object = self.object
            return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
        }
    }
    public var wrappedValue: ObjectType
    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public init(initialValue: ObjectType) { self.wrappedValue = initialValue }
    public var projectedValue: Wrapper { Wrapper(object: wrappedValue) }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let object = pointer.assumingMemoryBound(to: ObservedObject<ObjectType>.self).pointee.wrappedValue
        subscribe(object, node, key)
    }
}

func subscribe<O: ObservableObject>(_ object: O, _ node: CompositeNode, _ key: Int) {
    let sub = node.storages[key] as? ObjectSubscription ?? ObjectSubscription()
    node.storages[key] = sub
    if sub.object !== object {
        sub.object = object
        sub.cancellable = object.objectWillChange.sink { [weak node] _ in node?.invalidate() }
    }
}

final class StateObjectStorage<O: ObservableObject> {
    let object: O
    let subscription = ObjectSubscription()
    init(_ object: O) { self.object = object }
}

@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty, DynamicPropertyInstaller {
    let thunk: () -> ObjectType
    var storage: StateObjectStorage<ObjectType>?
    public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) { self.thunk = thunk }
    public var wrappedValue: ObjectType { storage?.object ?? thunk() }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { ObservedObject<ObjectType>.Wrapper(object: wrappedValue) }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: StateObject<ObjectType>.self)
        let s: StateObjectStorage<ObjectType>
        if let existing = node.storages[key] as? StateObjectStorage<ObjectType> {
            s = existing
        } else {
            s = StateObjectStorage(p.pointee.thunk())
            node.storages[key] = s
            s.subscription.cancellable = s.object.objectWillChange.sink { [weak node] _ in node?.invalidate() }
        }
        p.pointee.storage = s
    }
}

@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty, DynamicPropertyInstaller {
    var object: ObjectType?
    public init() {}
    public var wrappedValue: ObjectType {
        guard let object else { fatalError("No ObservableObject of type \(ObjectType.self) found. A View.environmentObject(_:) for \(ObjectType.self) may be missing as an ancestor of this view.") }
        return object
    }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        guard let object = node.env.objects[ObjectIdentifier(ObjectType.self)] as? ObjectType else { return }
        pointer.assumingMemoryBound(to: EnvironmentObject<ObjectType>.self).pointee.object = object
        subscribe(object, node, key)
    }
}
extension Binding: DynamicProperty {}

func bytesEqual<T>(_ a: T, _ b: T) -> Bool {
    withUnsafeBytes(of: a) { left in withUnsafeBytes(of: b) { right in left.elementsEqual(right) } }
}

#if !REV_NO_FIELD_REFLECTION
import UIKit
import Observation

// @Observable models: a view that reads one is re-rendered when what it read changes (see CompositeNode.trackedBody).

@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable> {
    public var wrappedValue: Value
    public var projectedValue: Bindable<Value> { self }
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(projectedValue: Bindable<Value>) { self = projectedValue }
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}

/// A `Bindable` is the model it wraps, so a list that identifies its rows identifies on the model.
extension Bindable: Identifiable where Value: Identifiable {
    public var id: Value.ID { wrappedValue.id }
}

struct ObservableObjectKey<T: AnyObject & Observable>: EnvironmentKey {
    static var defaultValue: T? { nil }
}

extension Environment {
    public init<T: AnyObject & Observable>(_ objectType: T.Type) where Value == T? {
        self.init(read: { $0[ObservableObjectKey<T>.self] })
    }
}

extension View {
    public func environment<T: AnyObject & Observable>(_ object: T?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0[ObservableObjectKey<T>.self] = object }, onUpdate: nil))
    }
}
#endif

import UIKit

struct LayoutValueModifier: NodeModifier {
    let key: ObjectIdentifier
    let value: Any
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { LayoutValueNode() }
}

final class LayoutValueNode: Node {
    var child: Node?
    var key: ObjectIdentifier?
    var value: Any?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! LayoutValueModifier
        key = modifier.key
        value = modifier.value
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

extension LayoutSubview {
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        var current: Node? = node
        while let candidate = current {
            if let holder = candidate as? LayoutValueNode, holder.key == ObjectIdentifier(key), let value = holder.value as? K.Value {
                return value
            }
            if candidate.parent is LayoutContainer { break }
            current = candidate.parent
        }
        return K.defaultValue
    }
}

protocol LayoutContainer {}

// A container value is written through a key path into these values, so the key that lands in the storage
// is the one that key path's setter uses, and a subview reads it back with that same key.
public protocol ContainerValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct ContainerValues {
    var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<Key: ContainerValueKey>(key: Key.Type) -> Key.Value {
        get { storage[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
    public func tag<V: Hashable>(for type: V.Type) -> V? {
        for value in storage.values {
            if let typed = value as? V { return typed }
        }
        return nil
    }
    public func hasTag<V: Hashable>(_ tag: V) -> Bool { storage.values.contains { ($0 as? V) == tag } }
}

extension ContainerValues {
    /// The values a subview carries for the layout that contains it: every `.containerValue` from the
    /// subview up, stopping at the container layout itself.
    static func collect(from node: LayoutNode) -> ContainerValues {
        var collected = ContainerValues()
        var current: Node? = node
        while let candidate = current {
            if let holder = candidate as? ContainerValueNode, let write = holder.write { write(&collected) }
            if candidate.parent is LayoutContainer { break }
            current = candidate.parent
        }
        return collected
    }
}

struct ContainerValueModifier: NodeModifier {
    let write: (inout ContainerValues) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ContainerValueNode() }
}

final class ContainerValueNode: Node {
    var child: Node?
    var write: ((inout ContainerValues) -> Void)?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        write = (m.modifierValue as! ContainerValueModifier).write
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func containerValue<V>(_ keyPath: WritableKeyPath<ContainerValues, V>, _ value: V) -> some View {
        _ModifiedView(content: self, modifier: ContainerValueModifier(write: { values in values[keyPath: keyPath] = value }))
    }
}

extension View {
    public func layoutValue<K: LayoutValueKey>(key: K.Type, value: K.Value) -> some View {
        _ModifiedView(content: self, modifier: LayoutValueModifier(key: ObjectIdentifier(key), value: value))
    }
    public func buttonBorderShape(_ shape: ButtonBorderShape) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.buttonBorderShape = shape }, onUpdate: nil))
    }
    public func projectionEffect(_ transform: ProjectionTransform) -> some View {
        applyingToViews { view in
            var t = CATransform3DIdentity
            t.m11 = transform.m11; t.m12 = transform.m12; t.m14 = transform.m13
            t.m21 = transform.m21; t.m22 = transform.m22; t.m24 = transform.m23
            t.m41 = transform.m31; t.m42 = transform.m32; t.m44 = transform.m33
            view.layer.transform = t
        }
    }
    public func compositingGroup() -> some View {
        applyingToViews { view in
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
        }
    }
}

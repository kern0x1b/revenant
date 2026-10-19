import UIKit
import CoreGraphics

public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}

extension PreferenceKey where Value: ExpressibleByNilLiteral {
    public static func reduce(value: inout Value, nextValue: () -> Value) { value = nextValue() }
}

struct PreferenceModifier: NodeModifier {
    let id: ObjectIdentifier
    let value: () -> Any
    var anchored: ((UIView?) -> Any)? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PreferenceNode() }
}

struct PreferenceTransformModifier: NodeModifier {
    let id: ObjectIdentifier
    let reduce: ([Any]) -> Any
    let transform: (Any, UIView?) -> Any
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PreferenceTransformNode() }
}

final class PreferenceTransformNode: Node {
    var child: Node?
    var id: ObjectIdentifier?
    var modifier: PreferenceTransformModifier?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        modifier = (m.modifierValue as! PreferenceTransformModifier)
        id = modifier?.id
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    var value: Any? {
        guard let modifier, let child else { return nil }
        let inner = modifier.reduce(collectPreferences(modifier.id, child))
        return modifier.transform(inner, flattened.first?.uiView)
    }
    override func mountContents() { child?.mount() }
}

func collectPreferences(_ id: ObjectIdentifier, _ node: Node) -> [Any] {
    if let transform = node as? PreferenceTransformNode, transform.id == id {
        return transform.value.map { [$0] } ?? []
    }
    var found: [Any] = []
    if let preference = node as? PreferenceNode, preference.id == id, let value = preference.currentValue {
        found.append(value)
    }
    for child in node.childNodes { found += collectPreferences(id, child) }
    return found
}

final class PreferenceNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var id: ObjectIdentifier?
    var value: Any?
    var anchored: ((UIView?) -> Any)?

    var currentValue: Any? { anchored.map { $0(flattened.first?.uiView) } ?? value }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! PreferenceModifier
        id = modifier.id
        anchored = modifier.anchored
        value = anchored == nil ? modifier.value() : nil
        child = adopt(reconcile(child, m.modifiedContent, env))
    }

    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func mountContents() { child?.mount() }
}

struct PreferenceObserverModifier: NodeModifier {
    let id: ObjectIdentifier
    let reduce: ([Any]) -> Any
    let changed: (Any) -> Void
    let same: (Any, Any) -> Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PreferenceObserverNode() }
}

final class PreferenceObserverNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var last: Any?

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! PreferenceObserverModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        let collected = child.map { collectPreferences(modifier.id, $0) } ?? []
        let value = modifier.reduce(collected)
        if last == nil || !modifier.same(last!, value) {
            last = value
            modifier.changed(value)
        }
    }

    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func mountContents() { child?.mount() }
}

extension View {
    public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View {
        _ModifiedView(content: self, modifier: PreferenceModifier(id: ObjectIdentifier(key), value: { value }))
    }

    public func onPreferenceChange<K: PreferenceKey>(_ key: K.Type, perform action: @escaping (K.Value) -> Void) -> some View where K.Value: Equatable {
        _ModifiedView(content: self, modifier: PreferenceObserverModifier(
            id: ObjectIdentifier(key),
            reduce: { values in
                var result = K.defaultValue
                for value in values {
                    guard let typed = value as? K.Value else { continue }
                    K.reduce(value: &result, nextValue: { typed })
                }
                return result
            },
            changed: { value in if let typed = value as? K.Value { action(typed) } },
            same: { left, right in (left as? K.Value) == (right as? K.Value) }))
    }
}

func reducer<K: PreferenceKey>(_ key: K.Type) -> ([Any]) -> Any {
    { values in
        var result = K.defaultValue
        for value in values {
            guard let typed = value as? K.Value else { continue }
            K.reduce(value: &result, nextValue: { typed })
        }
        return result
    }
}

struct PreferenceOverlayModifier: NodeModifier {
    let id: ObjectIdentifier
    let reduce: ([Any]) -> Any
    let make: (Any) -> any View
    let background: Bool
    let alignment: Alignment
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PreferenceOverlayNode() }
}

final class PreferenceOverlayNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    var lastValue: Any?

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! PreferenceOverlayModifier
        func compose(_ value: Any) -> any View {
            let extra = AnyView(modifier.make(value))
            let base = AnyView(m.modifiedContent)
            return modifier.background ? AnyView(base.background(extra, alignment: modifier.alignment)) : AnyView(base.overlay(extra, alignment: modifier.alignment))
        }
        let first = lastValue ?? modifier.reduce([])
        child = adopt(reconcile(child, compose(first), env))
        let now = modifier.reduce(child.map { collectPreferences(modifier.id, $0) } ?? [])
        lastValue = now
        if !valuesMatch(first, now) {
            child = adopt(reconcile(child, compose(now), env))
        }
    }
    override func mountContents() { child?.mount() }
}

func valuesMatch(_ a: Any, _ b: Any) -> Bool {
    if let a = a as? AnyHashable, let b = b as? AnyHashable { return a == b }
    return false
}

extension View {
    public func anchorPreference<A, K: PreferenceKey>(key: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (Anchor<A>) -> K.Value) -> some View {
        _ModifiedView(content: self, modifier: PreferenceModifier(id: ObjectIdentifier(key), value: { K.defaultValue }, anchored: { view in
            transform(Anchor(view: view, measure: value.measure, convert: value.convert))
        }))
    }
    public func transformPreference<K: PreferenceKey>(_ key: K.Type = K.self, _ callback: @escaping (inout K.Value) -> Void) -> some View {
        _ModifiedView(content: self, modifier: PreferenceTransformModifier(id: ObjectIdentifier(key), reduce: reducer(key), transform: { value, _ in
            var typed = (value as? K.Value) ?? K.defaultValue
            callback(&typed)
            return typed
        }))
    }
    public func transformAnchorPreference<A, K: PreferenceKey>(key: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (inout K.Value, Anchor<A>) -> Void) -> some View {
        _ModifiedView(content: self, modifier: PreferenceTransformModifier(id: ObjectIdentifier(key), reduce: reducer(key), transform: { current, view in
            var typed = (current as? K.Value) ?? K.defaultValue
            transform(&typed, Anchor(view: view, measure: value.measure, convert: value.convert))
            return typed
        }))
    }
    public func overlayPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View {
        _ModifiedView(content: self, modifier: PreferenceOverlayModifier(id: ObjectIdentifier(key), reduce: reducer(key), make: { transform(($0 as? K.Value) ?? K.defaultValue) }, background: false, alignment: alignment))
    }
    public func backgroundPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View {
        _ModifiedView(content: self, modifier: PreferenceOverlayModifier(id: ObjectIdentifier(key), reduce: reducer(key), make: { transform(($0 as? K.Value) ?? K.defaultValue) }, background: true, alignment: alignment))
    }
}

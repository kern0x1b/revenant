import UIKit
import CoreGraphics

final class DefaultsStorage<Value> {
    let key: String
    let defaults: UserDefaults
    let fallback: Value
    weak var node: CompositeNode?
    init(key: String, defaults: UserDefaults, fallback: Value) {
        self.key = key; self.defaults = defaults; self.fallback = fallback
    }
    var value: Value {
        get { (defaults.object(forKey: key) as? Value) ?? fallback }
        set {
            defaults.set(newValue, forKey: key)
            defaults.synchronize()
            node?.invalidate()
        }
    }
}

@propertyWrapper
public struct AppStorage<Value>: DynamicProperty, DynamicPropertyInstaller {
    let key: String
    let store: UserDefaults
    let fallback: Value
    var storage: DefaultsStorage<Value>?

    public var wrappedValue: Value {
        get { storage?.value ?? fallback }
        nonmutating set { storage?.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        let storage = self.storage
        let fallback = self.fallback
        return Binding(get: { storage?.value ?? fallback }, set: { storage?.value = $0 })
    }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: AppStorage<Value>.self)
        if let existing = node.storages[key] as? DefaultsStorage<Value> {
            p.pointee.storage = existing
        } else {
            let storage = DefaultsStorage(key: p.pointee.key, defaults: p.pointee.store === UserDefaults.standard ? node.env.defaults : p.pointee.store, fallback: p.pointee.fallback)
            storage.node = node
            node.storages[key] = storage
            p.pointee.storage = storage
        }
    }
}

extension AppStorage {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {
        self.init(key: key, store: store ?? .standard, fallback: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {
        self.init(key: key, store: store ?? .standard, fallback: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {
        self.init(key: key, store: store ?? .standard, fallback: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {
        self.init(key: key, store: store ?? .standard, fallback: wrappedValue)
    }
}

final class ChangeWatcher {
    var last: Any?
    var cancellable: AnyCancellable?
}

struct ChangeModifier: NodeModifier {
    let value: () -> Any
    let equals: (Any?, Any) -> Bool
    let action: (Any) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ChangeNode() }
}

final class ChangeNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    let watcher = ChangeWatcher()
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! ChangeModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        let value = modifier.value()
        if watcher.last == nil {
            watcher.last = value
        } else if !modifier.equals(watcher.last, value) {
            watcher.last = value
            modifier.action(value)
        }
    }
    override func mountContents() { child?.mount() }
}

struct ReceiveModifier: NodeModifier {
    let subscribe: (@escaping (Any) -> Void) -> AnyCancellable
    let action: (Any) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ReceiveNode() }
}

final class ReceiveNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var cancellable: AnyCancellable?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! ReceiveModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        if cancellable == nil {
            cancellable = modifier.subscribe { modifier.action($0) }
        }
    }
    override func mountContents() { child?.mount() }
}

struct IdentityModifier: NodeModifier {
    let id: AnyHashable
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { IdentityNode() }
}

final class IdentityNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var id: AnyHashable?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let next = (m.modifierValue as! IdentityModifier).id
        if id != next {
            id = next
            child?.dispose()
            child = adopt(makeNode(m.modifiedContent, env))
        } else {
            child = adopt(reconcile(child, m.modifiedContent, env))
        }
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        _ModifiedView(content: self, modifier: ChangeModifier(
            value: { value },
            equals: { old, new in (old as? V) == (new as? V) },
            action: { if let typed = $0 as? V { action(typed) } }))
    }

    public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P.Failure == Never {
        _ModifiedView(content: self, modifier: ReceiveModifier(
            subscribe: { sink in publisher.sink { value in sink(value) } },
            action: { if let typed = $0 as? P.Output { action(typed) } }))
    }

    public func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        _ModifiedView(content: self, modifier: AppearModifier(action: nil, disappear: action))
    }

    public func id<ID: Hashable>(_ id: ID) -> some View {
        _ModifiedView(content: self, modifier: IdentityModifier(id: AnyHashable(id)))
    }

    public func zIndex(_ value: Double) -> some View {
        applyingToViews { $0.layer.zPosition = CGFloat(value) }
    }

    public func accessibilityLabel(_ label: Text) -> some View {
        applyingToViews { $0.accessibilityLabel = label.content }
    }

    public func accessibilityHidden(_ hidden: Bool) -> some View {
        applyingToViews { $0.accessibilityElementsHidden = hidden }
    }
}

extension RangeReplaceableCollection where Self: MutableCollection {
    public mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.reversed() {
            remove(at: index(startIndex, offsetBy: offset))
        }
    }
}

extension MutableCollection {
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[index(startIndex, offsetBy: $0)] }
        var rest: [Element] = []
        var insertAt = destination
        for (offset, element) in enumerated() {
            if source.contains(offset) {
                if offset < destination { insertAt -= 1 }
            } else {
                rest.append(element)
            }
        }
        rest.insert(contentsOf: moving, at: insertAt)
        var position = startIndex
        for element in rest {
            self[position] = element
            formIndex(after: &position)
        }
    }
}

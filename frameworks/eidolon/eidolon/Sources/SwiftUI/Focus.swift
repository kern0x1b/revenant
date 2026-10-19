import UIKit
import CoreGraphics

final class FocusStorage<Value: Hashable> {
    var value: Value
    weak var node: CompositeNode?
    init(_ value: Value) { self.value = value }
}

@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty, DynamicPropertyInstaller {
    public struct Binding {
        let storage: FocusStorage<Value>
        public var wrappedValue: Value {
            get { storage.value }
            nonmutating set {
                storage.value = newValue
                storage.node?.invalidate()
            }
        }
        public var projectedValue: Binding { self }
    }

    let initial: Value
    var storage: FocusStorage<Value>?

    public init() where Value == Bool { initial = false }
    public init<Wrapped: Hashable>() where Value == Wrapped? { initial = nil }

    public var wrappedValue: Value {
        get { storage?.value ?? initial }
        nonmutating set {
            storage?.value = newValue
            storage?.node?.invalidate()
        }
    }

    public var projectedValue: Binding { Binding(storage: storage ?? FocusStorage(initial)) }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: FocusState<Value>.self)
        if let existing = node.storages[key] as? FocusStorage<Value> {
            p.pointee.storage = existing
        } else {
            let storage = FocusStorage(p.pointee.initial)
            storage.node = node
            node.storages[key] = storage
            p.pointee.storage = storage
        }
    }
}

struct FocusModifier<Value: Hashable>: NodeModifier {
    let binding: FocusState<Value>.Binding
    let match: Value
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { FocusNode<Value>() }
}

final class FocusNode<Value: Hashable>: ContainerNode {
    var applied: Value?

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! FocusModifier<Value>
        content = adopt(reconcile(content, m.modifiedContent, env))
        let wanted = modifier.binding.wrappedValue
        guard wanted != applied else { return }
        applied = wanted
        let responder = firstResponderCandidate()
        if wanted == modifier.match {
            responder?.becomeFirstResponder()
        } else if responder?.isFirstResponder == true {
            responder?.resignFirstResponder()
        }
    }

    func firstResponderCandidate() -> UIView? {
        func walk(_ view: UIView) -> UIView? {
            if view is UITextField || view is UITextView || view is UISearchBar { return view }
            for subview in view.subviews { if let found = walk(subview) { return found } }
            return nil
        }
        for kid in children { if let found = walk(kid.uiView) { return found } }
        return nil
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

extension View {
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        _ModifiedView(content: self, modifier: FocusModifier(binding: condition, match: true))
    }

    public func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> some View {
        _ModifiedView(content: self, modifier: FocusModifier(binding: binding, match: Optional(value)))
    }
}

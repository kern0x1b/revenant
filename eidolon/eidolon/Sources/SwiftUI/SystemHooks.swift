import UIKit

final class OpenURLHandlers {
    nonisolated(unsafe) static var handlers: [ObjectIdentifier: (URL) -> Void] = [:]
    static func deliver(_ url: URL) -> Bool {
        handlers.values.forEach { $0(url) }
        return !handlers.isEmpty
    }
}

struct OpenURLModifier: NodeModifier {
    let action: (URL) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { OpenURLNode() }
}

final class OpenURLNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        OpenURLHandlers.handlers[ObjectIdentifier(self)] = (m.modifierValue as! OpenURLModifier).action
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func dispose() {
        OpenURLHandlers.handlers.removeValue(forKey: ObjectIdentifier(self))
        super.dispose()
    }
    override func mountContents() { child?.mount() }
}

struct StatusBarModifier: NodeModifier {
    let hidden: Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { StatusBarNode() }
}

final class StatusBarNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let hidden = (m.modifierValue as! StatusBarModifier).hidden
        if UIApplication.shared.isStatusBarHidden != hidden {
            UIApplication.shared.setStatusBarHidden(hidden, with: .fade)
        }
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func dispose() {
        if UIApplication.shared.isStatusBarHidden { UIApplication.shared.setStatusBarHidden(false, with: .fade) }
        super.dispose()
    }
    override func mountContents() { child?.mount() }
}

extension SubmitLabel {
    var returnKey: UIReturnKeyType {
        switch self {
        case .done: return .done
        case .go: return .go
        case .send: return .send
        case .join: return .join
        case .route: return .route
        case .search: return .search
        case .next: return .next
        case .return, .continue: return .default
        }
    }
}

extension View {
    public func onOpenURL(perform action: @escaping (URL) -> Void) -> some View {
        _ModifiedView(content: self, modifier: OpenURLModifier(action: action))
    }
    public func statusBarHidden(_ hidden: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: StatusBarModifier(hidden: hidden))
    }
    public func submitLabel(_ label: SubmitLabel) -> some View {
        if label == .continue {
            _Unsupported.note("submitLabel(.continue)", "the keyboard of iOS 6 has no Continue key; the Return key is shown")
        }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.returnKey = label.returnKey }, onUpdate: nil))
    }
    public func help(_ text: Text) -> some View { accessibilityHint(text) }
    public func help<S: StringProtocol>(_ text: S) -> some View { accessibilityHint(text) }
    public func help(_ key: LocalizedStringKey) -> some View { accessibilityHint(Text(key)) }
    public func accessibility(label: Text) -> some View { accessibilityLabel(label) }
    public func accessibility(hint: Text) -> some View { accessibilityHint(hint) }
    public func accessibility(value: Text) -> some View { accessibilityValue(value) }
    public func accessibility(hidden: Bool) -> some View { accessibilityHidden(hidden) }
    public func accessibility(identifier: String) -> some View { accessibilityIdentifier(identifier) }
    public func accessibility(addTraits traits: AccessibilityTraits) -> some View { accessibilityAddTraits(traits) }
    public func accessibility(removeTraits traits: AccessibilityTraits) -> some View { accessibilityRemoveTraits(traits) }
    public func scrollContentBackground(_ visibility: Visibility) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scrollBackgroundHidden = visibility == .hidden }, onUpdate: nil))
    }
    public func badge(_ count: Int) -> some View {
        _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.badge = count == 0 ? nil : String(count) }, badge: count == 0 ? nil : String(count)))
    }
    public func badge(_ label: Text?) -> some View {
        let text = label?.content
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.badge = text }, badge: text))
    }
    public func badge<S: StringProtocol>(_ label: S?) -> some View {
        let text = label.map { String($0) }
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.badge = text }, badge: text))
    }
    public func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some View {
        applyingToViews { view in
            var transform = CATransform3DIdentity
            transform.m34 = -perspective / 500
            view.layer.transform = CATransform3DRotate(transform, CGFloat(angle.radians), axis.x, axis.y, axis.z)
        }
    }
}

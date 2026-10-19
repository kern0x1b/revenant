import UIKit
import CoreGraphics

public struct ToolbarItemPlacement: Hashable, Sendable {
    enum Slot { case leading, trailing, principal, bottom, status, keyboard }
    let slot: Slot
    let name: String

    public static let automatic = ToolbarItemPlacement(slot: .trailing, name: "automatic")
    public static let principal = ToolbarItemPlacement(slot: .principal, name: "principal")
    public static let navigation = ToolbarItemPlacement(slot: .leading, name: "navigation")
    public static let primaryAction = ToolbarItemPlacement(slot: .trailing, name: "primaryAction")
    public static let secondaryAction = ToolbarItemPlacement(slot: .trailing, name: "secondaryAction")
    public static let status = ToolbarItemPlacement(slot: .status, name: "status")
    public static let confirmationAction = ToolbarItemPlacement(slot: .trailing, name: "confirmationAction")
    public static let cancellationAction = ToolbarItemPlacement(slot: .leading, name: "cancellationAction")
    public static let destructiveAction = ToolbarItemPlacement(slot: .trailing, name: "destructiveAction")
    public static let keyboard = ToolbarItemPlacement(slot: .keyboard, name: "keyboard")
    public static let navigationBarLeading = ToolbarItemPlacement(slot: .leading, name: "navigationBarLeading")
    public static let navigationBarTrailing = ToolbarItemPlacement(slot: .trailing, name: "navigationBarTrailing")
    public static let bottomBar = ToolbarItemPlacement(slot: .bottom, name: "bottomBar")
}

public struct ToolbarItem<ID, Content: View>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let placement: ToolbarItemPlacement
    let showsByDefault: Bool
    let content: Content
    var childViews: [any View] { [content] }
}

extension ToolbarItem where ID == Void {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement; self.showsByDefault = true; self.content = content()
    }
}

extension ToolbarItem where ID == String {
    public init(id: String, placement: ToolbarItemPlacement = .automatic, showsByDefault: Bool = true, @ViewBuilder content: () -> Content) {
        self.placement = placement; self.showsByDefault = showsByDefault; self.content = content()
    }
}

public struct ToolbarItemGroup<Content: View>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let placement: ToolbarItemPlacement
    let content: Content
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement; self.content = content()
    }
    var childViews: [any View] { [content] }
}

struct BarEntry {
    let placement: ToolbarItemPlacement
    let view: any View
}

// A view builder's result is a tree of tuples, groups and conditionals; a bar item is each leaf of it.
func barLeaves(_ view: any View) -> [any View] {
    if view is EmptyView { return [] }
    if let group = view as? GroupView, !(view is EnvironmentGroupView), !(view is ToolbarItemLikeView) {
        return group.childViews.flatMap(barLeaves)
    }
    return [view]
}

protocol ToolbarItemLikeView {}
extension ToolbarItem: ToolbarItemLikeView {}
extension ToolbarItemGroup: ToolbarItemLikeView {}

func barEntries(_ view: any View, _ fallback: ToolbarItemPlacement) -> [BarEntry] {
    var out: [BarEntry] = []
    func walk(_ value: any View) {
        if value is EmptyView { return }
        if let item = value as? ToolbarItemDescription {
            guard item.showsByDefaultItem else { return }
            let leaves = item.isGroupItem ? barLeaves(item.contentView) : [item.contentView]
            out += leaves.map { BarEntry(placement: item.placementValue, view: $0) }
            return
        }
        if let group = value as? GroupView, !(value is EnvironmentGroupView) { group.childViews.forEach(walk); return }
        out.append(BarEntry(placement: fallback, view: value))
    }
    walk(view)
    return out
}

protocol ToolbarItemDescription {
    var placementValue: ToolbarItemPlacement { get }
    var contentView: any View { get }
    var isGroupItem: Bool { get }
    var showsByDefaultItem: Bool { get }
}

extension ToolbarItem: ToolbarItemDescription {
    var placementValue: ToolbarItemPlacement { placement }
    var contentView: any View { content }
    var isGroupItem: Bool { false }
    var showsByDefaultItem: Bool { showsByDefault }
}

extension ToolbarItemGroup: ToolbarItemDescription {
    var placementValue: ToolbarItemPlacement { placement }
    var contentView: any View { content }
    var isGroupItem: Bool { true }
    var showsByDefaultItem: Bool { true }
}

final class BarButtonTarget: NSObject {
    var action: () -> Void = {}
    @objc func fire() { action() }
}

// A bar item that is not a plain text button is a small hosting controller of its own, sized to its content.
final class BarItemHost: _HostingViewController {
    override func loadView() {
        let v = _HostRootView(frame: .zero)
        v.backgroundColor = .clear
        view = v
    }

    func fitContent() {
        guard isViewLoaded, let node = items.first else { return }
        let size = node.sizeThatFits(ProposedSize(width: nil, height: 44))
        if view.bounds.size != size { view.frame = CGRect(origin: view.frame.origin, size: size) }
    }

    override func viewWillLayoutSubviews() {
        fitContent()
        super.viewWillLayoutSubviews()
    }
}

final class BarSlot {
    let target = BarButtonTarget()
    var host: BarItemHost?
    var item: UIBarButtonItem?
    var title: String?
}

struct BarItemsModifier: NodeModifier {
    let entries: () -> [BarEntry]
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { BarItemsNode() }
}

final class BarItemsNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var slots: [String: BarSlot] = [:]
    var hadBottom = false
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func mountContents() { child?.mount() }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! BarItemsModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        guard let host = env.host else { return }
        apply(modifier.entries(), host, env)
    }

    func apply(_ entries: [BarEntry], _ host: UIViewController, _ env: EnvironmentValues) {
        var left: [UIBarButtonItem] = [], right: [UIBarButtonItem] = [], bottom: [UIBarButtonItem] = [], status: [UIBarButtonItem] = []
        var title: UIView?
        var used: Set<String> = []
        for (index, entry) in entries.enumerated() {
            let key = "\(entry.placement.name)#\(index)"
            if entry.placement.slot == .keyboard {
                _Unsupported.note("ToolbarItemPlacement.keyboard", "iOS 6 has no keyboard toolbar; the item is not shown")
                continue
            }
            used.insert(key)
            let slot = slots[key] ?? BarSlot()
            slots[key] = slot
            let item = makeItem(entry.view, slot, env)
            switch entry.placement.slot {
            case .leading: left.append(item)
            case .trailing: right.append(item)
            case .bottom: bottom.append(item)
            case .status: status.append(item)
            case .principal: title = title ?? item.customView
            case .keyboard: break
            }
        }
        slots = slots.filter { used.contains($0.key) }
        let flexible = { UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) }
        if !status.isEmpty { bottom += [flexible()] + status + [flexible()] }
        let navigation = host.navigationItem
        // UIKit numbers right items from the edge inwards; SwiftUI lists them from left to right.
        let rightOrdered = Array(right.reversed())
        if (navigation.leftBarButtonItems ?? []) != left { navigation.leftBarButtonItems = left.isEmpty ? nil : left }
        navigation.leftItemsSupplementBackButton = true
        if (navigation.rightBarButtonItems ?? []) != rightOrdered { navigation.rightBarButtonItems = rightOrdered.isEmpty ? nil : rightOrdered }
        if navigation.titleView !== title, title != nil || navigation.titleView is _HostRootView { navigation.titleView = title }
        if !bottom.isEmpty || hadBottom {
            host.toolbarItems = bottom.isEmpty ? nil : bottom
            host.navigationController?.setToolbarHidden(bottom.isEmpty, animated: false)
            hadBottom = !bottom.isEmpty
        }
    }

    func textItem(_ title: String, _ action: @escaping () -> Void, _ slot: BarSlot) -> UIBarButtonItem {
        slot.target.action = action
        if slot.host == nil, let item = slot.item, slot.title == title { return item }
        slot.host = nil
        slot.title = title
        let item = UIBarButtonItem(title: title, style: .plain, target: slot.target, action: #selector(BarButtonTarget.fire))
        slot.item = item
        return item
    }

    func makeItem(_ original: any View, _ slot: BarSlot, _ env: EnvironmentValues) -> UIBarButtonItem {
        // .disabled on a plain button is the bar item's own isEnabled, so the button keeps the look of a bar button
        var view = original
        var enabled = true
        while let modified = view as? ModifiedViewLike, let effect = modified.modifierValue as? EffectModifier, effect.effect.onlyInteraction {
            if effect.effect.interaction == false { enabled = false }
            view = modified.modifiedContent
        }
        let item = makeBarItem(view, original, slot, env)
        if item.isEnabled != enabled { item.isEnabled = enabled }
        return item
    }

    func makeBarItem(_ view: any View, _ original: any View, _ slot: BarSlot, _ env: EnvironmentValues) -> UIBarButtonItem {
        if view is Spacer {
            let item = slot.item ?? UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            slot.item = item
            return item
        }
        if view is EditButton {
            if env.editMode == nil, let host = env.host { return host.editButtonItem }
            if let access = editingAccess(env) {
                return textItem(access.get() ? "Done" : "Edit", { access.set(!access.get()) }, slot)
            }
        }
        if let button = view as? ButtonLike, let text = button.buttonLabel as? Text, !text.content.isEmpty {
            return textItem(text.content, button.buttonAction, slot)
        }
        let host = slot.host ?? BarItemHost(rootView: original)
        if slot.host == nil {
            slot.host = host
            slot.title = nil
            slot.item = nil
        }
        // the bars of iOS 6 are dark, so what is drawn on them is white unless it says otherwise
        var barEnv = env
        barEnv.foregroundColor = .white
        barEnv.tint = .white
        host.setRootView(AnyView(HStack { AnyView(original) }), env: barEnv)
        _ = host.view
        host.fitContent()
        host.view.layoutIfNeeded()
        if slot.item == nil { slot.item = UIBarButtonItem(customView: host.view) }
        return slot.item!
    }
}

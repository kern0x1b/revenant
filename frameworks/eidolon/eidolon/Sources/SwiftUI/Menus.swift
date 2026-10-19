import UIKit
import CoreGraphics

public struct Menu<Label: View, Content: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let content: Content
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label()
    }
    var childViews: [any View] { [_MenuButton(label: label, content: content)] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        guard let style = env.menuStyle else { return childViews }
        let configuration = MenuStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: content))
        return [withEnvironment(style(configuration)) { $0.menuStyle = nil }]
    }
}

extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
    public init(_ configuration: MenuStyleConfiguration) {
        self.init(content: { configuration.content }, label: { configuration.label })
    }
}

struct _MenuButton: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let label: any View
    let content: any View
    func makeNode(_ env: EnvironmentValues) -> Node {
        // a plain text label is the titled button of iOS 6; anything else (an icon, a Label) is drawn as it is
        if label is Text { let n = MenuNode(borderless: env.menuBorderless); n.update(self, env); return n }
        let n = MenuLabelNode(); n.update(self, env); return n
    }
}

extension Menu where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
}

protocol MenuLike {
    var menuLabel: any View { get }
    var menuItems: [(String, () -> Void)] { get }
    var menuItemsWithRoles: [(title: String, action: () -> Void, destructive: Bool)] { get }
}

extension _MenuButton: MenuLike {
    var menuLabel: any View { label }
    var menuItems: [(String, () -> Void)] { menuEntries(content) }
    var menuItemsWithRoles: [(title: String, action: () -> Void, destructive: Bool)] { SwiftUI.menuItemsWithRoles(content) }
}

func menuEntries(_ view: any View) -> [(String, () -> Void)] { menuItemsWithRoles(view).map { ($0.title, $0.action) } }

func menuItemsWithRoles(_ view: any View) -> [(title: String, action: () -> Void, destructive: Bool)] {
    var found: [(title: String, action: () -> Void, destructive: Bool)] = []
    func walk(_ value: any View) {
        if let button = value as? ButtonLike {
            found.append((findText(button.buttonLabel)?.content ?? "", button.buttonAction, (value as? RoleButtonLike)?.buttonRole == .destructive))
            return
        }
        if let group = value as? GroupView { group.childViews.forEach(walk) }
        if let modified = value as? ModifiedViewLike { walk(modified.modifiedContent) }
        if let wrapper = value as? WrappedView { walk(wrapper.wrapped) }
    }
    walk(view)
    return found
}

// The action sheet a menu opens; a destructive item is the red one, as in a confirmation dialog.
func presentMenu(_ items: [(title: String, action: () -> Void, destructive: Bool)], _ delegate: SheetDelegate, in host: UIViewController?) {
    guard let host else { return }
    let sheet = UIActionSheet()
    sheet.delegate = delegate
    delegate.actions = items.map { $0.action }
    delegate.dismissed = {}
    for item in items { sheet.addButton(withTitle: item.title) }
    sheet.addButton(withTitle: "Cancel")
    sheet.cancelButtonIndex = items.count
    if let destructive = items.firstIndex(where: { $0.destructive }) { sheet.destructiveButtonIndex = destructive }
    sheet.show(in: host.view)
}

final class MenuLabelNode: ContainerNode {
    let hit = UIButton(type: .custom)
    let target = ControlTarget()
    let delegate = SheetDelegate()
    var items: [(title: String, action: () -> Void, destructive: Bool)] = []
    weak var host: UIViewController?

    override init() {
        super.init()
        hit.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
        target.action = { [weak self] in
            guard let self else { return }
            presentMenu(self.items, self.delegate, in: self.host)
        }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let menu = view as? _MenuButton else { return }
        host = env.host
        items = menuItemsWithRoles(menu.content)
        let accent = Color(env.foregroundColor ?? env.tint ?? UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1))
        content = adopt(reconcile(content, AnyView(menu.label).foregroundColor(accent), env))
    }

    override func mountContents() { super.mountContents(); uiView.addSubview(hit) }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        hit.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
}

final class MenuNode: LayoutNode {
    let target = ControlTarget()
    let delegate = SheetDelegate()
    var items: [(title: String, action: () -> Void, destructive: Bool)] = []
    weak var host: UIViewController?
    var button: UIButton { uiView as! UIButton }

    init(borderless: Bool = false) {
        let control = UIButton(type: borderless ? .custom : .roundedRect)
        if borderless {
            control.setTitleColor(UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1), for: .normal)
            control.setTitleColor(UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 0.4), for: .highlighted)
        }
        super.init(view: control)
        control.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
        target.action = { [weak self] in self?.present() }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let menu = view as? MenuLike else { return }
        host = env.host
        items = menu.menuItemsWithRoles
        let title = findText(menu.menuLabel)?.content ?? ""
        if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
    }

    func present() { presentMenu(items, delegate, in: host) }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let wanted = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(max(wanted.width + 24, 72), p.width ?? infinity), height: max(wanted.height, 37))
    }
}

public struct DisclosureGroup<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let expanded: Binding<Bool>?

    public init(isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label(); expanded = isExpanded
    }

    public var body: some View {
        _DisclosureBody(label: label, content: content, external: expanded)
    }
}

extension DisclosureGroup where Label == DisclosureGroupStyleConfiguration.Label, Content == DisclosureGroupStyleConfiguration.Content {
    public init(_ configuration: DisclosureGroupStyleConfiguration) {
        self.init(isExpanded: configuration.$isExpanded, content: { configuration.content }, label: { configuration.label })
    }
}

extension DisclosureGroup where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(isExpanded: isExpanded, content: content, label: { Text(titleKey) })
    }
}

struct _DisclosureBody<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let external: Binding<Bool>?
    @State private var internalExpanded = false
    @Environment(\.disclosureGroupStyle) var style

    var body: some View {
        let isExpanded = external ?? $internalExpanded
        if let style {
            let nested = withEnvironment(content) { $0.disclosureGroupStyle = style }
            let configuration = DisclosureGroupStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: nested), isExpanded: isExpanded)
            return AnyView(withEnvironment(style(configuration)) { $0.disclosureGroupStyle = nil })
        }
        return AnyView(_DisclosureChrome(label: label, content: content, isExpanded: isExpanded))
    }
}

struct _DisclosureChrome<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let isExpanded: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label
                Spacer()
                Text(isExpanded.wrappedValue ? "▾" : "▸").foregroundColor(.gray)
            }
            .onTapGesture { isExpanded.wrappedValue.toggle() }
            if isExpanded.wrappedValue {
                content
            }
        }
    }
}

extension View {
    public func contextMenu<Content: View>(@ViewBuilder menuItems: @escaping () -> Content) -> some View {
        let items = menuEntries(menuItems())
        return onLongPressGesture {
            showReleaseMenu(items, in: UIApplication.shared.keyWindow?.rootViewController?.view)
        }
    }
}

// What a view can be copied or cut as: the pasteboard of this release holds a string, a URL or an image, and a payload of
// any type is written as its description, which is what a sheet of a custom view can offer.
func copyToPasteboard<T>(_ payload: [T]) {
    if let url = payload.compactMap({ $0 as? URL }).first {
        UIPasteboard.general.url = url
    } else if let image = payload.compactMap({ $0 as? UIImage }).first {
        UIPasteboard.general.image = image
    } else {
        UIPasteboard.general.string = pasteboardText(payload)
    }
}

// What a payload is copied as: the pasteboard of this release takes a string, a URL or an image, and a payload of any
// other type is written as its own description, one item per line.
func pasteboardText<T>(_ payload: [T]) -> String { payload.map { "\($0)" }.joined(separator: "\n") }

// What the share sheet of the release is given: its items are what an activity of this release can take - a string, a
// URL, an image - and a payload of any other type is offered as its own description, the way the pasteboard takes one.
func activityItems<T>(_ payload: [T]) -> [Any] {
    payload.map { value -> Any in
        if value is String || value is URL || value is UIImage { return value }
        return "\(value)"
    }
}

func clearPasteboard() {
    UIPasteboard.general.items = []
}

// A menu of this release is an action sheet, and the sheet the release shows is the one this function puts up: the
// titles and what each of them does, kept where a test can read them.
func showReleaseMenu(_ entries: [(String, () -> Void)], in view: UIView?) {
    guard !entries.isEmpty else { return }
    let keeper = ContextMenuKeeper.shared
    keeper.delegate.actions = entries.map { $0.1 }
    ContextMenuKeeper.shown = entries.map { $0.0 }
    // the menu is what the engine did even where there is no window to put the sheet in front of
    guard let view else { return }
    let sheet = UIActionSheet()
    sheet.delegate = keeper.delegate
    for entry in entries { sheet.addButton(withTitle: entry.0) }
    sheet.addButton(withTitle: "Cancel")
    sheet.cancelButtonIndex = entries.count
    sheet.show(in: view)
}

final class ContextMenuKeeper {
    static let shared = ContextMenuKeeper()
    static nonisolated(unsafe) var shown: [String] = []
    let delegate = SheetDelegate()
}

import UIKit
import CoreGraphics

extension View {
    public func navigationBarTitle(_ titleKey: LocalizedStringKey, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(titleKey).navigationBarTitleDisplayMode(displayMode)
    }
    public func navigationBarTitle<S: StringProtocol>(_ title: S, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(displayMode)
    }
    public func navigationBarTitle(_ title: Text, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(title.content).navigationBarTitleDisplayMode(displayMode)
    }

    public func lineLimit(_ limit: Int, reservesSpace: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.lineLimit = limit; $0.reservesLines = reservesSpace }, onUpdate: nil))
    }

    public func contentShape<S: Shape>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View {
        if kind.contains(.interaction) { return AnyView(contentShape(shape, eoFill: eoFill)) }
        _Unsupported.note("contentShape(kind)", "iOS 6 has no drag preview, context-menu preview or hover effect to shape")
        return AnyView(self)
    }

    public func navigationDestination<V: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> V) -> some View {
        background(NavigationLink(isActive: isPresented, destination: destination) { EmptyView() })
    }

    public func mask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        _ModifiedView(content: self, modifier: MaskModifier(mask: mask(), alignment: alignment))
    }
    public func mask<Mask: View>(_ mask: Mask) -> some View {
        _ModifiedView(content: self, modifier: MaskModifier(mask: mask, alignment: .center))
    }

    public func task<ID: Equatable>(id: ID, priority: TaskPriority = .userInitiated, _ action: @escaping () async -> Void) -> some View {
        _ModifiedView(content: self, modifier: TaskModifier(id: id, same: { ($0 as? ID) == ($1 as? ID) }, priority: priority, action: action))
    }
    public func task(priority: TaskPriority = .userInitiated, _ action: @escaping () async -> Void) -> some View {
        _ModifiedView(content: self, modifier: TaskModifier(id: 0, same: { _, _ in true }, priority: priority, action: action))
    }

    public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            let hidden = visibility == .hidden
            for bar in bars {
                switch bar.name {
                case "navigationBar": env.host?.navigationController?.setNavigationBarHidden(hidden, animated: false)
                case "bottomBar": env.host?.navigationController?.setToolbarHidden(hidden, animated: false)
                case "tabBar": _Unsupported.note("toolbar(_:for: .tabBar)", "the tab bar of iOS 6 cannot be hidden for one screen")
                default: env.host?.navigationController?.setNavigationBarHidden(hidden, animated: false)
                }
            }
        }))
    }

    public func accessibility(sortPriority: Double) -> some View { accessibilitySortPriority(sortPriority) }
    public func accessibility(activationPoint: CGPoint) -> some View { accessibilityActivationPoint(activationPoint) }
    public func accessibility(activationPoint: UnitPoint) -> some View { accessibilityActivationPoint(activationPoint) }
    public func accessibility(inputLabels: [Text]) -> some View {
        _Unsupported.note("accessibility(inputLabels:)", "input labels are for Voice Control, which iOS 6 does not have")
        return self
    }
    public func accessibility(selectionIdentifier: AnyHashable) -> some View {
        _Unsupported.note("accessibility(selectionIdentifier:)", "selection identifiers belong to accessibility rotors, which iOS 6 does not have")
        return self
    }
    public func accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> some View {
        ignored(self, "accessibilityAction", "a custom action is UIAccessibilityCustomAction, iOS 8; the accessibility of this release answers activation, increment, decrement and scroll, and VoiceOver of iOS 6 double-taps the view itself")
    }
    public func accessibilityAction<Label: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        ignored(self, "accessibilityAction", "a custom action is UIAccessibilityCustomAction, iOS 8; the accessibility of this release answers activation, increment, decrement and scroll, and VoiceOver of iOS 6 double-taps the view itself")
    }
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> some View {
        if pattern != .solid { _Unsupported.note("Text.LineStyle.Pattern", "iOS 6 draws only solid underlines and strikethroughs") }
        return underline(isActive, color: color)
    }
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> some View {
        if pattern != .solid { _Unsupported.note("Text.LineStyle.Pattern", "iOS 6 draws only solid underlines and strikethroughs") }
        return strikethrough(isActive, color: color)
    }
}

// The work of task(id:) runs while the view is on screen: it ends when the view goes away and starts again when the id changes.
final class TaskBox {
    var task: Task<Void, Never>?
    func run(_ priority: TaskPriority, _ action: @escaping () async -> Void) {
        task?.cancel()
        task = Task(priority: priority) { @MainActor in await action() }
    }
    func cancel() { task?.cancel(); task = nil }
    deinit { task?.cancel() }
}

struct TaskModifier: NodeModifier {
    let id: Any
    let same: (Any, Any) -> Bool
    let priority: TaskPriority
    let action: () async -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { TaskNode() }
}

final class TaskNode: Node {
    var child: Node?
    var lastID: Any?
    let box = TaskBox()
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! TaskModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        if let last = lastID, modifier.same(last, modifier.id) { return }
        lastID = modifier.id
        box.run(modifier.priority, modifier.action)
    }

    override func dispose() {
        box.cancel()
        super.dispose()
    }

    override func mountContents() { child?.mount() }
}

struct MaskModifier: NodeModifier {
    let mask: any View
    let alignment: Alignment
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { MaskNode() }
}

// The mask is laid out like an overlay, but its views are not shown: their alpha becomes the alpha of the content.
final class MaskNode: ContainerNode {
    var maskNode: Node?
    var alignment = Alignment.center
    let maskHost = UIView()

    override var disposableChildren: [Node] { [content, maskNode].compactMap { $0 } }
    override var children: [LayoutNode] { content?.flattened ?? [] }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! MaskModifier
        alignment = modifier.alignment
        content = adopt(reconcile(content, m.modifiedContent, env))
        maskNode = adopt(reconcile(maskNode, modifier.mask, env))
        maskHost.backgroundColor = .clear
        uiView.layer.mask = maskHost.layer
    }

    override func mountContents() {
        syncSubviews(uiView, children)
        content?.mount()
        syncSubviews(maskHost, maskNode?.flattened ?? [])
        maskNode?.mount()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { content?.flattened.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        let box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        content?.flattened.first?.place(box)
        maskHost.frame = box
        for node in maskNode?.flattened ?? [] {
            let wanted = node.sizeThatFits(ProposedSize(width: size.width, height: size.height))
            let x = alignment.horizontal.raw < 0 ? 0 : alignment.horizontal.raw > 0 ? size.width - wanted.width : (size.width - wanted.width) / 2
            let y = alignment.vertical.raw < 0 ? 0 : alignment.vertical.raw > 0 ? size.height - wanted.height : (size.height - wanted.height) / 2
            node.place(CGRect(x: x, y: y, width: wanted.width, height: wanted.height))
        }
    }
}

// A UIImage from a bundle other than the main one: UIImage(named:) only reads the main bundle on iOS 6.
func bundleImage(_ name: String, _ bundle: Bundle?) -> UIImage? {
    guard let bundle, bundle != Bundle.main else { return UIImage(named: name) }
    let scale = Int(UIScreen.main.scale)
    let stem = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension.isEmpty ? "png" : (name as NSString).pathExtension
    var candidates: [(String, CGFloat)] = []
    if scale >= 2 { candidates.append((stem + "@\(scale)x", CGFloat(scale))) }
    candidates.append((stem, 1))
    for (file, fileScale) in candidates {
        if let path = bundle.path(forResource: file, ofType: ext), let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let image = UIImage(data: data, scale: fileScale) { return image }
    }
    return nil
}

extension Image {
    public init(_ name: String, bundle: Bundle?) {
        self.init(name)
        stored = bundleImage(name, bundle)
    }
    public init(_ name: String, bundle: Bundle? = nil, label: Text) {
        self.init(name, bundle: bundle)
        accessibilityLabelText = label.content
    }
    public init(decorative name: String, bundle: Bundle? = nil) {
        self.init(name, bundle: bundle)
        decorative = true
    }
    public init(decorative cgImage: CGImage, scale: CGFloat, orientation: Image.Orientation = .up) {
        self.init(cgImage, scale: scale, orientation: orientation, label: Text(verbatim: ""))
        accessibilityLabelText = nil
        decorative = true
    }
    public init(systemName: String, variableValue: Double?) {
        self.init(systemName: systemName)
        if variableValue != nil { _Unsupported.note("Image(variableValue:)", "variable symbols are SF Symbols, which iOS 6 does not have; the image is drawn whole") }
    }
}

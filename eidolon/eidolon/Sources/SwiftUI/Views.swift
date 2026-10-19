import UIKit
import CoreGraphics

public struct Text: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: String
    var font: Font?
    var color: Color?
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var isStruck = false
    var textCase: Text.Case?
    var kern: CGFloat?
    var accessibilityLabelText: String?
    var accessibilityHeader = false
    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {
        content = key.localized(table: tableName, bundle: bundle)
    }
    public init<S: StringProtocol>(_ content: S) { self.content = String(content) }
    public init(verbatim content: String) { self.content = content }
    public func font(_ font: Font?) -> Text { var t = self; t.font = font; return t }
    public func foregroundColor(_ color: Color?) -> Text { var t = self; t.color = color; return t }
    public func bold(_ isActive: Bool = true) -> Text { var t = self; t.isBold = isActive; return t }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TextNode(); n.update(self, env); return n }
}

final class TextNode: LayoutNode {
    var label: UILabel { uiView as! UILabel }
    init() {
        let l = UILabel()
        l.numberOfLines = 0
        l.backgroundColor = .clear
        super.init(view: l)
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let t = view as! Text
        var font = env.scaled(t.font?.uiFont ?? env.fontValue ?? UIFont.systemFont(ofSize: 17))
        if t.isBold || env.textBold { font = UIFont.boldSystemFont(ofSize: font.pointSize) }
        // a secondary run is the release's own smaller label: caption 1 against body
        if env.textScale == .secondary { font = UIFont.systemFont(ofSize: font.pointSize * Text.Scale.secondaryRatio) }
        let color = t.color?.uiColor ?? env.foregroundColor ?? .black
        let underlined = t.isUnderlined || env.textUnderline
        let struck = t.isStruck || env.textStrikethrough
        let italic = t.isItalic || env.textItalic
        let kern = t.kern ?? env.kerning
        label.textAlignment = env.textAlignment
        label.accessibilityLabel = t.accessibilityLabelText
        if t.accessibilityHeader { label.accessibilityTraits.insert(.header) }
        label.numberOfLines = env.lineLimit ?? 0
        if underlined || struck || italic || kern != nil || env.lineSpacingOverride != nil {
            var attributes: [NSAttributedString.Key: Any] = [.font: italic ? (UIFont.italicSystemFont(ofSize: font.pointSize)) : font, .foregroundColor: color]
            if underlined { attributes[.underlineStyle] = NSNumber(value: 1) }
            if struck { attributes[.strikethroughStyle] = NSNumber(value: 1) }
            if let kern { attributes[.kern] = NSNumber(value: Double(kern)) }
            if let spacing = env.lineSpacingOverride {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = spacing
                paragraph.alignment = env.textAlignment
                attributes[.paragraphStyle] = paragraph
            }
            label.attributedText = NSAttributedString(string: t.resolved(env.textCase), attributes: attributes)
        } else {
            let resolved = t.resolved(env.textCase)
            if label.attributedText != nil && label.text == resolved { label.text = nil }
            if label.text != resolved {
                if env.contentTransition.kind == .fade, label.text != nil, let animation = Updates.animationForFlush ?? env.animation {
                    let fade = CATransition()
                    fade.type = CATransitionType.fade
                    fade.duration = animation.playedDuration
                    label.layer.add(fade, forKey: "contentTransition")
                }
                label.text = resolved
            }
            label.font = font
            label.textColor = color
        }
        if env.redactedDrawing {
            label.textColor = .clear
            if label.attributedText != nil { label.attributedText = NSAttributedString(string: t.resolved(env.textCase), attributes: [.font: font, .foregroundColor: UIColor.clear]) }
            label.backgroundColor = UIColor(white: 0.85, alpha: 1)
            label.layer.cornerRadius = 3
            label.clipsToBounds = true
        } else if label.layer.cornerRadius == 3 {
            label.backgroundColor = .clear
            label.layer.cornerRadius = 0
        }
        if label.responds(to: NSSelectorFromString("setAdjustsLetterSpacingToFitWidth:")) {
            label.setValue(env.allowsTightening, forKey: "adjustsLetterSpacingToFitWidth")
        }
        if let truncation = env.truncation { label.lineBreakMode = truncation }
        if let factor = env.scaleFactorOverride {
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = factor
        }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let s = label.sizeThatFits(CGSize(width: p.width ?? infinity, height: infinity))
        var height = ceil(s.height)
        if env.reservesLines, let lines = env.lineLimit, lines > 0 {
            height = max(height, ceil(label.font.lineHeight * CGFloat(lines) + (env.lineSpacingOverride ?? 0) * CGFloat(lines - 1)))
        }
        return CGSize(width: ceil(min(s.width, p.width ?? s.width)), height: height)
    }
}

public struct Font {
    let uiFont: UIFont
    public static let largeTitle = Font(uiFont: .boldSystemFont(ofSize: 30))
    public static let title = Font(uiFont: .boldSystemFont(ofSize: 24))
    public static let headline = Font(uiFont: .boldSystemFont(ofSize: 17))
    public static let body = Font(uiFont: .systemFont(ofSize: 17))
    public static let subheadline = Font(uiFont: .systemFont(ofSize: 15))
    public static let footnote = Font(uiFont: .systemFont(ofSize: 13))
    public static let caption = Font(uiFont: .systemFont(ofSize: 12))
    public static func system(size: CGFloat) -> Font { Font(uiFont: .systemFont(ofSize: size)) }
}

public struct Color: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let uiColor: UIColor
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        uiColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))
    }
    public init(_ uiColor: UIColor) { self.uiColor = uiColor }
    // the system colours of SwiftUI in a light appearance, not the pure primaries of UIColor
    public static let red = Color(red: 1.0, green: 0.231, blue: 0.188), green = Color(red: 0.204, green: 0.780, blue: 0.349)
    public static let blue = Color(red: 0.0, green: 0.478, blue: 1.0), black = Color(.black)
    public static let white = Color(.white), gray = Color(red: 0.557, green: 0.557, blue: 0.576)
    public static let orange = Color(red: 1.0, green: 0.584, blue: 0.0), yellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    public static let clear = Color(.clear), secondary = Color(.darkGray), primary = Color(.black)
    public static let purple = Color(red: 0.686, green: 0.322, blue: 0.871), pink = Color(red: 1, green: 0.176, blue: 0.333)
    public static let brown = Color(red: 0.635, green: 0.518, blue: 0.369), cyan = Color(red: 0.196, green: 0.678, blue: 0.902)
    public static let indigo = Color(red: 0.345, green: 0.337, blue: 0.839), mint = Color(red: 0, green: 0.78, blue: 0.745)
    public static let teal = Color(red: 0.188, green: 0.69, blue: 0.78)
    public static var accentColor: Color { Color(red: 0.2, green: 0.45, blue: 0.85) }
    public func opacity(_ opacity: Double) -> Color { Color(uiColor.withAlphaComponent(CGFloat(opacity))) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ColorNode(view: UIView()); n.update(self, env); return n }
}

final class ColorNode: LayoutNode {
    override func update(_ view: any View, _ env: EnvironmentValues) { super.update(view, env); uiView.backgroundColor = (view as! Color).uiColor }
    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
}

public struct Divider: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    func makeNode(_ env: EnvironmentValues) -> Node { let n = DividerNode(view: UIView()); n.uiView.backgroundColor = UIColor(white: 0.78, alpha: 1); return n }
}

final class DividerNode: LayoutNode {
    override func computeSize(_ p: ProposedSize) -> CGSize {
        stackAxis == .horizontal ? CGSize(width: 1, height: p.height ?? 1) : CGSize(width: p.width ?? 1, height: 1)
    }
}

public struct Image: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let name: String
    let system: Bool
    var isResizable = false
    var contentMode: ContentMode?
    var stored: UIImage?
    var template = false
    var nearest = false
    var capInsets = EdgeInsets()
    var tiles = false
    var accessibilityLabelText: String?
    var decorative = false
    public init(_ name: String) { self.name = name; system = false }
    public init(systemName: String) {
        name = systemName
        system = true
        if SymbolGlyphs.resolve(systemName) == nil {
            _Unsupported.note("Image(systemName:)", "iOS 6 has no SF Symbols and this name is not in the set drawn here; the bundle is searched for it, then an outlined square is shown")
        }
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ImageNode(view: UIImageView()); n.update(self, env); return n }
}

final class ImageNode: LayoutNode {
    var placeholderSize: CGSize?
    var resizable = false
    var mode = ContentMode.fit
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let image = view as! Image
        resizable = image.isResizable
        mode = image.contentMode ?? .fit
        let imageView = uiView as! UIImageView
        var picture = image.stored ?? UIImage(named: image.name)
        var template = image.template
        if picture == nil, image.system {
            let scale: CGFloat = env.imageScale == .small ? 0.8 : env.imageScale == .large ? 1.3 : 1
            let points = image.isResizable ? 64 : ceil(env.scaledSize((env.fontValue?.pointSize ?? 17) * scale))
            picture = SymbolGlyphs.image(named: image.name, points: points, bold: env.textBold) ?? SymbolGlyphs.placeholder(points: points)
            if let base = picture { picture = templated(base, env.foregroundColor ?? .black) }
            template = false
        }
        if let base = picture, template {
            picture = templated(base, env.foregroundColor ?? env.tint ?? UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1))
        }
        if let base = picture, image.capInsets != EdgeInsets() || image.tiles {
            let insets = UIEdgeInsets(top: image.capInsets.top, left: image.capInsets.leading, bottom: image.capInsets.bottom, right: image.capInsets.trailing)
            picture = base.resizableImage(withCapInsets: insets, resizingMode: image.tiles ? .tile : .stretch)
        }
        imageView.layer.magnificationFilter = image.nearest ? CALayerContentsFilter.nearest : CALayerContentsFilter.linear
        imageView.image = env.redactedDrawing ? nil : picture
        imageView.backgroundColor = env.redactedDrawing ? UIColor(white: 0.85, alpha: 1) : .clear
        placeholderSize = env.redactedDrawing ? picture?.size : nil
        imageView.contentMode = resizable ? (mode == .fill ? .scaleAspectFill : .scaleAspectFit) : .center
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = !image.decorative && image.accessibilityLabelText != nil
        imageView.accessibilityLabel = image.accessibilityLabelText
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let natural = placeholderSize ?? (uiView as! UIImageView).image?.size ?? .zero
        guard resizable else { return natural }
        return CGSize(width: p.width ?? natural.width, height: p.height ?? natural.height)
    }
}

final class ControlTarget: NSObject {
    var action: () -> Void = {}
    var valueChanged: (UIControl) -> Void = { _ in }
    @objc func fire() { action() }
    @objc func changed(_ sender: UIControl) { valueChanged(sender) }
}

public struct Button<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let action: () -> Void
    let label: Label
    var role: ButtonRole?
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) { self.action = action; self.label = label() }
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action; self.label = label(); self.role = role
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ButtonNode(plainText: Label.self == Text.self); n.update(self, env); return n }
}

extension Button: RoleButtonLike { var buttonRole: ButtonRole? { role } }

extension Button where Label == PrimitiveButtonStyleConfiguration.Label {
    public init(_ configuration: PrimitiveButtonStyleConfiguration) {
        self.init(role: configuration.role, action: configuration.action) { configuration.label }
    }
}

extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(titleKey) }
    }
    public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.init(action: action) { Text(titleKey) }
    }
    public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {
        self.init(action: action) { Text(title) }
    }
}

protocol ButtonLike {
    var buttonAction: () -> Void { get }
    var buttonLabel: any View { get }
}

extension Button: ButtonLike {
    var buttonAction: () -> Void { action }
    var buttonLabel: any View { label }
}

protocol LabelParts { var labelTitle: any View { get }; var labelIcon: any View { get } }
extension Label: LabelParts { var labelTitle: any View { title }; var labelIcon: any View { icon } }
typealias LabelTitled = LabelParts

func findText(_ view: any View) -> Text? {
    if let t = view as? Text { return t }
    if let label = view as? LabelParts { return findText(label.labelTitle) }
    if let g = view as? GroupView { for c in g.childViews { if let t = findText(c) { return t } } }
    if let w = view as? WrappedView { return findText(w.wrapped) }
    return nil
}

final class ButtonNode: LayoutNode {
    let target = ControlTarget()
    let pressTarget = ControlTarget()
    var button: UIButton { uiView as! UIButton }
    var styleBody: ((ButtonStyleConfiguration) -> any View)?
    /// Apple's configuration carries no `isPressed`, so a primitive style that wants the press adopts the
    /// port's `PressedButtonStyle`; the node keeps the body either way, and hands the press to it.
    var primitiveBody: ((PrimitiveButtonStyleConfiguration, Bool) -> any View)?
    var label: (any View)?
    /// What `configuration.trigger()` of a primitive style performs, and the role it reads.
    var primitiveAction: () -> Void = {}
    var primitiveRole: ButtonRole?
    var styled: Node?
    var pressed = false
    var primitive = false

    override var disposableChildren: [Node] { styled.map { [$0] } ?? [] }

    let plainText: Bool

    // A label that is not one Text is drawn as it is, without the chrome iOS 6 puts on a titled button.
    init(plainText: Bool) {
        self.plainText = plainText
        let b = UIButton(type: plainText ? .roundedRect : .custom)
        super.init(view: b)
        b.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
        b.addTarget(pressTarget, action: #selector(ControlTarget.changed(_:)), for: .touchDown)
        b.addTarget(pressTarget, action: #selector(ControlTarget.changed(_:)), for: .touchUpInside)
        b.addTarget(pressTarget, action: #selector(ControlTarget.changed(_:)), for: .touchUpOutside)
        b.addTarget(pressTarget, action: #selector(ControlTarget.changed(_:)), for: .touchCancel)
        pressTarget.valueChanged = { [weak self] control in
            // the primitive path keeps its body in `primitiveBody`, so a press is worth following on
            // either path: a guard on `styleBody` alone would skip every primitive style
            guard let self, self.styleBody != nil || self.primitiveBody != nil else { return }
            self.pressed = (control as! UIButton).isHighlighted
            self.rebuildStyled()
        }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let b = view as! ButtonLike
        label = b.buttonLabel
        if let style = env.primitiveButtonStyle {
            primitive = true
            styleBody = nil
            // a style of the port draws the label and nothing else, so the tap is the node's; a style of an app owns its
            // trigger (it calls `configuration.trigger()` from a Button or a gesture), and a tap that also fired would fire twice
            target.action = env.primitiveTriggersOnTap ? b.buttonAction : {}
            primitiveAction = b.buttonAction
            primitiveRole = (view as? RoleButtonLike)?.buttonRole
            button.setTitle(nil, for: .normal)
            primitiveBody = env.primitiveButtonStyle
            rebuildStyled()
            return
        }
        primitive = false
        primitiveBody = nil
        target.action = b.buttonAction
        styleBody = env.buttonStyle
        if styleBody == nil && !plainText {
            // a button's label takes the tint (or the foreground colour set outside), as in SwiftUI
            let accent = Color(env.foregroundColor ?? env.tint ?? UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1))
            styleBody = { AnyView($0.label.foregroundColor(accent).opacity($0.isPressed ? 0.4 : 1)) }
        }
        if styleBody == nil {
            styled?.dispose()
            styled = nil
            let title = findText(b.buttonLabel)?.content ?? ""
            if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
            button.titleLabel?.font = env.scaled(env.fontValue ?? UIFont.boldSystemFont(ofSize: 15))
        } else {
            button.setTitle(nil, for: .normal)
            rebuildStyled()
        }
    }

    func rebuildStyled() {
        guard let label else { return }
        var inner = env
        let body: any View
        if let primitiveBody {
            let configuration = PrimitiveButtonStyleConfiguration(label: PrimitiveButtonStyleConfiguration.Label(content: label),
                                                                  role: primitiveRole, action: primitiveAction)
            inner.primitiveButtonStyle = nil
            inner.isPressed = pressed
            body = primitiveBody(configuration, pressed)
        } else if let styleBody {
            let configuration = ButtonStyleConfiguration(label: ButtonStyleConfiguration.Label(content: label), isPressed: pressed)
            inner.buttonStyle = nil
            body = styleBody(configuration)
        } else {
            return
        }
        styled = adopt(reconcile(styled, body, inner))
        mount()
        if let root = styled?.flattened.first {
            let size = root.sizeThatFits(ProposedSize(width: uiView.bounds.size.width, height: uiView.bounds.size.height))
            root.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }

    override func mountContents() {
        guard let styled else { return }
        let views = styled.flattened
        views.forEach { $0.uiView.isUserInteractionEnabled = primitive }
        syncSubviews(uiView, views)
        styled.mount()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        if styleBody != nil || primitive, let root = styled?.flattened.first { return root.sizeThatFits(p) }
        let s = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(max(s.width + 24, 72), p.width ?? infinity), height: max(s.height, 37))
    }

    override func layoutContents(_ size: CGSize) {
        guard styleBody != nil || primitive, let root = styled?.flattened.first else { return }
        root.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

public struct Toggle<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let isOn: Binding<Bool>
    let label: Label
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) { self.isOn = isOn; self.label = label() }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ToggleNode(); n.update(self, env); return n }
}

extension Toggle where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) { self.init(isOn: isOn) { Text(titleKey) } }
    public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) { self.init(isOn: isOn) { Text(title) } }
}

protocol ToggleLike { var toggleBinding: Binding<Bool> { get }; var toggleLabel: any View { get } }
extension Toggle: ToggleLike { var toggleBinding: Binding<Bool> { isOn }; var toggleLabel: any View { label } }

final class ToggleNode: ContainerNode {
    let control = UISwitch()
    let target = ControlTarget()
    var styleBody: ((ToggleStyleConfiguration) -> any View)?
    var styled: Node?
    override init() {
        super.init()
        control.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }
    override var children: [LayoutNode] { content?.flattened ?? [] }
    override func mountContents() { super.mountContents(); uiView.addSubview(control) }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let t = view as! ToggleLike
        let binding = t.toggleBinding
        target.valueChanged = { binding.wrappedValue = ($0 as! UISwitch).isOn }
        styleBody = env.toggleStyle
        if let styleBody {
            control.isHidden = true
            let configuration = ToggleStyleConfiguration(label: ToggleStyleConfiguration.Label(content: t.toggleLabel), isOn: binding.wrappedValue)
            var inner = env
            inner.toggleStyle = nil
            let body = AnyView(styleBody(configuration)).onTapGesture { binding.wrappedValue.toggle() }
            content = adopt(reconcile(content, body, inner))
            return
        }
        control.isHidden = false
        if control.isOn != binding.wrappedValue { control.setOn(binding.wrappedValue, animated: true) }
        content = adopt(reconcile(content, env.labelsHidden ? EmptyView() : t.toggleLabel, env))
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        if styleBody != nil { return children.first?.sizeThatFits(p) ?? .zero }
        let sw = control.sizeThatFits(.zero)
        let l = children.first?.sizeThatFits(ProposedSize(width: (p.width ?? infinity) - sw.width - 8, height: nil)) ?? .zero
        return CGSize(width: p.width ?? (l.width + 8 + sw.width), height: max(l.height, sw.height))
    }
    override func layoutContents(_ size: CGSize) {
        if styleBody != nil {
            children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            return
        }
        let sw = control.sizeThatFits(.zero)
        control.frame = CGRect(x: size.width - sw.width, y: (size.height - sw.height) / 2, width: sw.width, height: sw.height)
        if let l = children.first {
            let s = l.sizeThatFits(ProposedSize(width: size.width - sw.width - 8, height: nil))
            l.place(CGRect(x: 0, y: (size.height - s.height) / 2, width: s.width, height: s.height))
        }
    }
}

public struct ForEach<Data, ID, Content> where Data: RandomAccessCollection, ID: Hashable {
    public var data: Data
    let id: KeyPath<Data.Element, ID>
    public var content: (Data.Element) -> Content
}

extension ForEach: View, PrimitiveView, ForEachLike where Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    @_disfavoredOverload
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data: data, id: id, content: content)
    }
    var identifiedViews: [(AnyHashable, any View)] {
        data.map { (AnyHashable($0[keyPath: id]), content($0) as any View) }
    }
    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = ForEachNode()
        node.update(self, env)
        return node
    }
}

protocol ForEachLike {
    var identifiedViews: [(AnyHashable, any View)] { get }
}

final class ForEachNode: Node {
    var children: [(AnyHashable, Node)] = []
    var source: (any View)?
    override var disposableChildren: [Node] { children.map { $0.1 } }
    override var flattened: [LayoutNode] { children.flatMap { $0.1.flattened } }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        self.source = view
        guard let source = view as? ForEachLike else { return }
        let previousOrder = children.map { $0.0 }
        var previous: [AnyHashable: Node] = [:]
        for (id, node) in children { previous[id] = node }
        var structureChanged = previous.count != source.identifiedViews.count
        children = source.identifiedViews.map { id, child in
            let old = previous.removeValue(forKey: id)
            if old == nil || old!.viewType != type(of: child) { structureChanged = true }
            return (id, adopt(reconcile(old, child, env)))
        }
        if !previous.isEmpty { structureChanged = true }
        previous.values.forEach { $0.dispose() }
        if structureChanged || previousOrder != children.map({ $0.0 }) { invalidateLayout() }
    }
    override func mountContents() { children.forEach { $0.1.mount() } }
}

extension ForEach where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {
    @_disfavoredOverload
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.init(data, id: \.id, content: content) }
}

extension ForEach where Data == Range<Int>, ID == Int, Content: View {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) { self.init(data, id: \.self, content: content) }
}

func templated(_ image: UIImage, _ color: UIColor) -> UIImage {
    guard let mask = image.cgImage else { return image }
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    defer { UIGraphicsEndImageContext() }
    guard let context = UIGraphicsGetCurrentContext() else { return image }
    let box = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    context.translateBy(x: 0, y: image.size.height)
    context.scaleBy(x: 1, y: -1)
    context.clip(to: box, mask: mask)
    color.setFill()
    context.fill(box)
    return UIGraphicsGetImageFromCurrentImageContext() ?? image
}

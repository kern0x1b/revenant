import UIKit
import CoreGraphics

extension Font {
    public struct Weight: Equatable {
        let value: CGFloat
        public static let ultraLight = Weight(value: -0.8)
        public static let thin = Weight(value: -0.6)
        public static let light = Weight(value: -0.4)
        public static let regular = Weight(value: 0)
        public static let medium = Weight(value: 0.23)
        public static let semibold = Weight(value: 0.3)
        public static let bold = Weight(value: 0.4)
        public static let heavy = Weight(value: 0.56)
        public static let black = Weight(value: 0.62)
    }

    public enum Design: Equatable { case `default`, serif, rounded, monospaced }

    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font {
        let bold = weight.value >= 0.3
        switch design {
        case .monospaced:
            return Font(uiFont: UIFont(name: bold ? "Courier-Bold" : "Courier", size: size) ?? .systemFont(ofSize: size))
        case .serif:
            return Font(uiFont: UIFont(name: bold ? "Georgia-Bold" : "Georgia", size: size) ?? .systemFont(ofSize: size))
        case .rounded:
            _Unsupported.note("Font.Design.rounded", "iOS 6 has no rounded system font; the regular one is used")
            return Font(uiFont: bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size))
        case .default:
            return Font(uiFont: bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size))
        }
    }

    func design(_ design: Design) -> Font {
        let bold = uiFont.fontName.contains("Bold")
        return Font.system(size: uiFont.pointSize, weight: bold ? .bold : .regular, design: design)
    }

    public func weight(_ weight: Weight) -> Font {
        Font(uiFont: weight.value >= 0.3 ? .boldSystemFont(ofSize: uiFont.pointSize) : .systemFont(ofSize: uiFont.pointSize))
    }

    public func bold() -> Font { weight(.bold) }
    public func italic() -> Font {
        let bold = uiFont.fontName.contains("Bold")
        let size = uiFont.pointSize
        return Font(uiFont: bold ? (UIFont(name: "Helvetica-BoldOblique", size: size) ?? .italicSystemFont(ofSize: size)) : .italicSystemFont(ofSize: size))
    }
    public static func custom(_ name: String, size: CGFloat) -> Font {
        Font(uiFont: UIFont(name: name, size: size) ?? .systemFont(ofSize: size))
    }
    public static let title2 = Font(uiFont: .boldSystemFont(ofSize: 22))
    public static let title3 = Font(uiFont: .boldSystemFont(ofSize: 20))
    public static let callout = Font(uiFont: .systemFont(ofSize: 16))
    public static let caption2 = Font(uiFont: .systemFont(ofSize: 11))
}

extension Text {
    public func italic(_ isActive: Bool = true) -> Text { var copy = self; copy.isItalic = isActive; return copy }
    public func monospaced(_ isActive: Bool = true) -> Text {
        guard isActive else { return self }
        var copy = self
        copy.font = Font(uiFont: UIFont(name: "Courier", size: (font?.uiFont.pointSize ?? 17)) ?? .systemFont(ofSize: 17))
        return copy
    }
    public func baselineOffset(_ baselineOffset: CGFloat) -> Text {
        _Unsupported.note("Text.baselineOffset", "attributed text of iOS 6 has no baseline offset; the text stays on its baseline")
        return self
    }
    public func accessibilityLabel(_ label: Text) -> Text { var copy = self; copy.accessibilityLabelText = label.content; return copy }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> Text { accessibilityLabel(Text(labelKey)) }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> Text { accessibilityLabel(Text(label)) }
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Text {
        var copy = self
        copy.accessibilityHeader = level != .unspecified
        return copy
    }
    public init<Subject: ReferenceConvertible>(_ subject: Subject, formatter: Formatter) {
        let bridged: Any = subject._bridgeToObjectiveC()
        self.init(verbatim: formatter.string(for: bridged) ?? "")
    }
    public init<Subject: NSObject>(_ subject: Subject, formatter: Formatter) {
        self.init(verbatim: formatter.string(for: subject) ?? "")
    }
    public func kerning(_ kerning: CGFloat) -> Text { var copy = self; copy.kern = kerning; return copy }
    public func tracking(_ tracking: CGFloat) -> Text { var copy = self; copy.kern = tracking; return copy }
    public func monospacedDigit() -> Text { self }
    public func underline(_ active: Bool = true, color: Color? = nil) -> Text {
        if color != nil { _Unsupported.note("underline(color:)", "a line under text of iOS 6 has the colour of the text") }
        var copy = self; copy.isUnderlined = active; return copy
    }
    public func strikethrough(_ active: Bool = true, color: Color? = nil) -> Text {
        if color != nil { _Unsupported.note("strikethrough(color:)", "a line through text of iOS 6 has the colour of the text") }
        var copy = self; copy.isStruck = active; return copy
    }
    public func fontWeight(_ weight: Font.Weight?) -> Text {
        var copy = self
        if let weight, weight.value >= 0.3 { copy.isBold = true }
        return copy
    }
    public func textCase(_ textCase: Text.Case?) -> Text {
        var copy = self
        copy.textCase = textCase
        return copy
    }
    public enum Case { case uppercase, lowercase }

    public static func + (left: Text, right: Text) -> Text {
        var joined = Text(verbatim: left.resolvedContent + right.resolvedContent)
        joined.font = left.font
        joined.color = left.color
        joined.isBold = left.isBold
        return joined
    }

    var resolvedContent: String { resolved(nil) }

    func resolved(_ environmentCase: Text.Case?) -> String {
        switch textCase ?? environmentCase {
        case .uppercase: return content.uppercased()
        case .lowercase: return content.lowercased()
        case nil: return content
        }
    }
}

extension View {
    public func lineLimit(_ number: Int?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.lineLimit = number }, onUpdate: nil))
    }
    public func minimumScaleFactor(_ factor: CGFloat) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scaleFactorOverride = factor }, onUpdate: nil))
    }
    public func textCase(_ textCase: Text.Case?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textCase = textCase }, onUpdate: nil))
    }
    public func tint(_ color: Color?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.tint = color?.uiColor }, onUpdate: nil))
    }
    public func accentColor(_ color: Color?) -> some View { tint(color) }
    public func foregroundStyle(_ color: Color) -> some View { foregroundColor(color) }
    @_disfavoredOverload
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        if style._gradientPaint != nil { _Unsupported.note("foregroundStyle(gradient)", "text of iOS 6 is drawn in one colour; the first colour of the gradient is used") }
        return foregroundColor(style._uiColor.map { Color($0) })
    }
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View {
        foregroundColor(primary._uiColor.map { Color($0) })
    }
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View {
        foregroundColor(primary._uiColor.map { Color($0) })
    }
}

extension Image {
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image {
        var copy = self
        copy.isResizable = true
        copy.capInsets = capInsets
        copy.tiles = resizingMode == .tile
        return copy
    }
    public func renderingMode(_ mode: TemplateRenderingMode?) -> Image {
        var copy = self
        copy.template = mode == .template
        return copy
    }
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> Image {
        var copy = self
        copy.contentMode = contentMode
        return copy
    }
    public func scaledToFit() -> Image { aspectRatio(contentMode: .fit) }
    public func scaledToFill() -> Image { aspectRatio(contentMode: .fill) }
    public enum ResizingMode { case tile, stretch }
    public enum TemplateRenderingMode { case original, template }
}

public enum ContentMode { case fit, fill }

extension View {
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> some View {
        _ModifiedView(content: self, modifier: AspectRatioModifier(ratio: ratio, mode: contentMode))
    }
    public func scaledToFit() -> some View { aspectRatio(contentMode: .fit) }
    public func scaledToFill() -> some View { aspectRatio(contentMode: .fill) }
}

struct AspectRatioModifier: NodeModifier {
    let ratio: CGFloat?
    let mode: ContentMode
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AspectRatioNode() }
}

final class AspectRatioNode: ContainerNode {
    var ratio: CGFloat?
    var mode = ContentMode.fit

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AspectRatioModifier
        ratio = modifier.ratio
        mode = modifier.mode
        content = adopt(reconcile(content, m.modifiedContent, env))
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let natural = children.first?.sizeThatFits(p) ?? .zero
        let wanted = ratio ?? (natural.height > 0 ? natural.width / natural.height : 1)
        guard wanted > 0 else { return natural }
        // one side proposed: the other follows from the ratio, whatever the child would have chosen
        if let width = p.width, p.height == nil { return CGSize(width: width, height: width / wanted) }
        if let height = p.height, p.width == nil { return CGSize(width: height * wanted, height: height) }
        let box = CGSize(width: p.width ?? natural.width, height: p.height ?? natural.height)
        let byWidth = CGSize(width: box.width, height: box.width / wanted)
        let byHeight = CGSize(width: box.height * wanted, height: box.height)
        if mode == .fit {
            return byWidth.height <= box.height ? byWidth : byHeight
        }
        return byWidth.height >= box.height ? byWidth : byHeight
    }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

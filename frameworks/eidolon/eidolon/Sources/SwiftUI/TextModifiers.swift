import UIKit
import CoreGraphics

extension View {
    public func bold(_ isActive: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textBold = isActive }, onUpdate: nil))
    }
    public func italic(_ isActive: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textItalic = isActive }, onUpdate: nil))
    }
    public func underline(_ isActive: Bool = true, color: Color? = nil) -> some View {
        if color != nil { _Unsupported.note("underline(color:)", "a line under text of iOS 6 has the colour of the text") }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textUnderline = isActive }, onUpdate: nil))
    }
    public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> some View {
        if color != nil { _Unsupported.note("strikethrough(color:)", "a line through text of iOS 6 has the colour of the text") }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textStrikethrough = isActive }, onUpdate: nil))
    }
    public func fontWeight(_ weight: Font.Weight?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if let weight, weight.value >= 0.3 { environment.textBold = true }
        }, onUpdate: nil))
    }
    public func monospaced(_ isActive: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            guard isActive else { return }
            let size = environment.fontValue?.pointSize ?? 17
            environment.fontValue = UIFont(name: "Courier", size: size) ?? .systemFont(ofSize: size)
        }, onUpdate: nil))
    }
    public func monospacedDigit() -> some View {
        self
    }
    public func kerning(_ kerning: CGFloat) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.kerning = kerning }, onUpdate: nil))
    }
    public func tracking(_ tracking: CGFloat) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.kerning = tracking }, onUpdate: nil))
    }
    public func fontDesign(_ design: Font.Design?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            guard design == .monospaced else { return }
            let size = environment.fontValue?.pointSize ?? 17
            environment.fontValue = UIFont(name: "Courier", size: size) ?? .systemFont(ofSize: size)
        }, onUpdate: nil))
    }
    public func fontWidth(_ width: Double?) -> some View {
        ignored(self, "fontWidth", "the system font of this release has no width axis: Helvetica Neue carries four faces on iOS 6.1.3 — Regular, Italic, Bold, Bold Italic — and Avenir Next Condensed is a family of its own, so a width of it would be a different typeface")
    }
    public func imageScale(_ scale: Image.Scale) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.imageScale = scale }, onUpdate: nil))
    }
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        _ModifiedView(content: self, modifier: PositionModifier(point: CGPoint(x: x, y: y)))
    }
    public func position(_ position: CGPoint) -> some View {
        _ModifiedView(content: self, modifier: PositionModifier(point: position))
    }
    public func transformEffect(_ transform: CGAffineTransform) -> some View {
        applyingToViews { $0.transform = transform }
    }
    public func scenePadding(_ edges: Edge.Set = .all) -> some View { padding(edges, 16) }
    public func safeAreaInset<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> V) -> some View {
        VStack(spacing: spacing ?? 0) {
            if edge == .top { content() }
            self
            if edge == .bottom { content() }
        }
    }
    public func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View {
        applyingToViews { view in
            guard let scroller = view as? UIScrollView else { return }
            if #available(iOS 7.0, *) {
                scroller.keyboardDismissMode = mode == .immediately ? .onDrag : .none
            } else if mode != .automatic {
                _Unsupported.note("scrollDismissesKeyboard", "UIScrollView of iOS 6 does not dismiss the keyboard on scroll")
            }
        }
    }
    public func scrollBounceBehavior(_ behavior: ScrollBounceBehavior, axes: Axis.Set = .vertical) -> some View {
        applyingToViews { view in
            guard let scroller = view as? UIScrollView else { return }
            scroller.bounces = behavior != .basedOnSize
        }
    }
    public func navigationSubtitle<S: StringProtocol>(_ subtitle: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { environment in
            environment.host?.navigationItem.prompt = String(subtitle)
        }))
    }
    public func toolbarBackground(_ color: Color, for bars: ToolbarPlacement = .automatic) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { environment in
            environment.host?.navigationController?.navigationBar.tintColor = color.uiColor
        }))
    }
    public func defaultAppStorage(_ store: UserDefaults) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.defaults = store }, onUpdate: nil))
    }
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View {
        var transaction = Transaction()
        transform(&transaction)
        return _ModifiedView(content: self, modifier: AnimationModifier(animation: transaction.animation))
    }
    public func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            transform(&environment[keyPath: keyPath])
        }, onUpdate: nil))
    }
    public func popover<Content: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, content: content)
    }
}

public enum VerticalEdge { case top, bottom }
public enum ScrollDismissesKeyboardMode { case automatic, immediately, interactively, never }
public enum ScrollBounceBehavior { case automatic, always, basedOnSize }
public struct ToolbarPlacement: Equatable {
    let name: String
    public static let automatic = ToolbarPlacement(name: "automatic")
    public static let navigationBar = ToolbarPlacement(name: "navigationBar")
    public static let tabBar = ToolbarPlacement(name: "tabBar")
    public static let bottomBar = ToolbarPlacement(name: "bottomBar")
}
public enum PopoverAttachmentAnchor { case rect(Anchor<CGRect>.Source), point(UnitPoint) }
public struct Anchor<Value> {
    weak var view: UIView?
    let measure: (CGRect) -> Value
    let convert: (Value, UIView, UIView) -> Value

    public struct Source {
        let measure: (CGRect) -> Value
        let convert: (Value, UIView, UIView) -> Value
    }

}

extension Anchor.Source {
    /// What a source reads out of a view of that rectangle: how a geometry proxy answers an anchor.
    @_spi(Probe) public func measuring(_ bounds: CGRect) -> Value { measure(bounds) }

    /// The anchor of a whole array: each element is measured the way its own source says.
    public init<T>(_ array: [Anchor<T>.Source]) where Value == [T] {
        self.init(measure: { bounds in array.map { $0.measure(bounds) } },
                  convert: { value, from, to in array.indices.map { array[$0].convert(value[$0], from, to) } })
    }

    /// The anchor of an optional: nothing to measure when there is nothing there.
    public init<T>(_ anchor: Anchor<T>.Source?) where Value == T? {
        self.init(measure: { bounds in anchor?.measure(bounds) },
                  convert: { value, from, to in value.map { anchor?.convert($0, from, to) ?? $0 } ?? nil })
    }
}

extension Anchor: Equatable where Value: Equatable {
    /// Two anchors are the same when they read the same value out of the same view: the view is
    /// the anchor's own, and the reading is what the source measures in a unit rectangle.
    public static func == (a: Anchor<Value>, b: Anchor<Value>) -> Bool {
        a.view === b.view && a.measure(unitRect) == b.measure(unitRect)
    }
}

extension Anchor: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(measure(unitRect)) }
}

private let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

extension Anchor.Source where Value == CGRect {
    public static var bounds: Anchor<CGRect>.Source {
        Anchor<CGRect>.Source(measure: { $0 }, convert: { value, from, to in from.convert(value, to: to) })
    }
    public static func rect(_ r: CGRect) -> Anchor<CGRect>.Source {
        Anchor<CGRect>.Source(measure: { _ in r }, convert: { value, from, to in from.convert(value, to: to) })
    }
}

extension Anchor.Source where Value == CGPoint {
    public static func point(_ p: CGPoint) -> Anchor<CGPoint>.Source {
        Anchor<CGPoint>.Source(measure: { _ in p }, convert: { value, from, to in from.convert(value, to: to) })
    }
    public static func unitPoint(_ p: UnitPoint) -> Anchor<CGPoint>.Source {
        Anchor<CGPoint>.Source(measure: { b in CGPoint(x: b.origin.x + b.size.width * p.x, y: b.origin.y + b.size.height * p.y) },
                               convert: { value, from, to in from.convert(value, to: to) })
    }
    public static var topLeading: Anchor<CGPoint>.Source { unitPoint(.topLeading) }
    public static var top: Anchor<CGPoint>.Source { unitPoint(.top) }
    public static var topTrailing: Anchor<CGPoint>.Source { unitPoint(.topTrailing) }
    public static var leading: Anchor<CGPoint>.Source { unitPoint(.leading) }
    public static var center: Anchor<CGPoint>.Source { unitPoint(.center) }
    public static var trailing: Anchor<CGPoint>.Source { unitPoint(.trailing) }
    public static var bottomLeading: Anchor<CGPoint>.Source { unitPoint(.bottomLeading) }
    public static var bottom: Anchor<CGPoint>.Source { unitPoint(.bottom) }
    public static var bottomTrailing: Anchor<CGPoint>.Source { unitPoint(.bottomTrailing) }
}

extension GeometryProxy {
    public subscript<T>(anchor: Anchor<T>) -> T {
        guard let source = anchor.view, let target = node?.uiView else { return anchor.measure(.zero) }
        return anchor.convert(anchor.measure(source.bounds), source, target)
    }
}

extension Image {
    public enum Scale { case small, medium, large }
}

struct PositionModifier: NodeModifier {
    let point: CGPoint
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PositionNode() }
}

final class PositionNode: ContainerNode {
    var point = CGPoint.zero
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        point = (m.modifierValue as! PositionModifier).point
        content = adopt(reconcile(content, m.modifiedContent, env))
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 0, height: p.height ?? 0)
    }
    override func layoutContents(_ size: CGSize) {
        guard let kid = children.first else { return }
        let wanted = kid.sizeThatFits(ProposedSize(width: nil, height: nil))
        kid.place(CGRect(x: point.x - wanted.width / 2, y: point.y - wanted.height / 2, width: wanted.width, height: wanted.height))
    }
}

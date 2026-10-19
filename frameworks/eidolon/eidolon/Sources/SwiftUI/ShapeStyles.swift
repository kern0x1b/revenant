import UIKit
import CoreGraphics

public protocol ShapeStyle {
    var _uiColor: UIColor? { get }
}

extension Color: ShapeStyle {
    public var _uiColor: UIColor? { uiColor }
}

extension LinearGradient: ShapeStyle {
    public var _uiColor: UIColor? { gradient.stops.first?.color.uiColor }
}

public struct ForegroundStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { nil }
}

public struct BackgroundStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { .white }
}

extension ShapeStyle where Self == Color {
    public static var red: Color { .red }
    public static var green: Color { .green }
    public static var blue: Color { .blue }
    public static var black: Color { .black }
    public static var white: Color { .white }
    public static var gray: Color { .gray }
    public static var orange: Color { .orange }
    public static var yellow: Color { .yellow }
    public static var clear: Color { .clear }
    public static var primary: Color { .primary }
    public static var secondary: Color { .secondary }
}

extension Shape {
    public func fill<S: ShapeStyle>(_ style: S) -> some View {
        var view = _ShapeView(shape: self, fill: style._uiColor.map { Color($0) } ?? Color.black, stroke: nil, style: StrokeStyle(lineWidth: 0))
        view.fillPaint = style._gradientPaint
        view.shadow = style._shadowStyle
        return view
    }
    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: CGFloat = 1) -> some View {
        stroke(style, style: StrokeStyle(lineWidth: lineWidth))
    }
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle) -> some View {
        var view = _ShapeView(shape: self, fill: Color.clear, stroke: content._uiColor.map { Color($0) } ?? Color.black, style: style)
        view.strokePaint = content._gradientPaint
        return view
    }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetShape<Self> {
        OffsetShape(shape: self, offset: CGSize(width: x, height: y))
    }
    public func scale(_ amount: CGFloat, anchor: UnitPoint = .center) -> ScaledShape<Self> {
        ScaledShape(shape: self, scale: CGSize(width: amount, height: amount), anchor: anchor)
    }
    public func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> RotatedShape<Self> {
        RotatedShape(shape: self, angle: angle, anchor: anchor)
    }
    public func transform(_ transform: CGAffineTransform) -> TransformedShape<Self> {
        TransformedShape(shape: self, transform: transform)
    }
}

public struct OffsetShape<Content: Shape>: Shape, PrimitiveView {
    public var shape: Content
    public var offset: CGSize
    public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(shape.animatableData, AnimatablePair(offset.width, offset.height)) }
        set { shape.animatableData = newValue.first; offset = CGSize(width: newValue.second.first, height: newValue.second.second) }
    }
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).offsetBy(dx: offset.width, dy: offset.height) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct ScaledShape<Content: Shape>: Shape, PrimitiveView {
    public var shape: Content
    public var scale: CGSize
    public var anchor: UnitPoint
    public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(shape.animatableData, AnimatablePair(scale.width, scale.height)) }
        set { shape.animatableData = newValue.first; scale = CGSize(width: newValue.second.first, height: newValue.second.second) }
    }
    public func path(in rect: CGRect) -> Path {
        shape.path(in: rect).applying(CGAffineTransformMakeScale(scale.width, scale.height))
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct RotatedShape<Content: Shape>: Shape, PrimitiveView {
    public var shape: Content
    public var angle: Angle
    public var anchor: UnitPoint
    public var animatableData: AnimatablePair<Content.AnimatableData, Double> {
        get { AnimatablePair(shape.animatableData, angle.radians) }
        set { shape.animatableData = newValue.first; angle = Angle(radians: newValue.second) }
    }
    public func path(in rect: CGRect) -> Path {
        shape.path(in: rect).applying(CGAffineTransformMakeRotation(CGFloat(angle.radians)))
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct TransformedShape<Content: Shape>: Shape, PrimitiveView {
    public var shape: Content
    public var transform: CGAffineTransform
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).applying(transform) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct AnyShape: Shape, PrimitiveView {
    let base: any Shape
    public init<S: Shape>(_ shape: S) { base = shape }
    public func path(in rect: CGRect) -> Path { base.path(in: rect) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct ContainerRelativeShape: Shape, PrimitiveView, InsettableShape {
    public typealias Body = Never
    var insetAmount: CGFloat = 0
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(roundedRect: insetRect(rect, insetAmount), cornerRadius: max(0, 8 - insetAmount)) }
    public func inset(by amount: CGFloat) -> ContainerRelativeShape { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct Transaction {
    public var animation: Animation?
    public var disablesAnimations: Bool = false
    public var isContinuous: Bool = false
    /// Whether an interactive dismissal follows the finger's speed when it ends.
    public var tracksVelocity: Bool = false
    /// The closures added by `addAnimationCompletion(criteria:_:)`; a copy of the transaction holds the same list, so a
    /// closure added through one copy is the other's, and one that has run has run for every copy.
    var completionList: CompletionList?
    public init() {}
    public init(animation: Animation?) { self.animation = animation }
}

public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result {
    let previous = Updates.pendingCompletions
    Updates.pendingCompletions = transaction.completionList?.tokens ?? []
    defer { Updates.pendingCompletions = previous }
    return try withAnimation(transaction.disablesAnimations ? nil : transaction.animation, body)
}

extension Binding {
    public func animation(_ animation: Animation? = .default) -> Binding<Value> {
        Binding(get: get, set: { newValue in withAnimation(animation) { self.set(newValue) } })
    }
    public func transaction(_ transaction: Transaction) -> Binding<Value> {
        Binding(get: get, set: { newValue in withTransaction(transaction) { self.set(newValue) } })
    }
}

public struct EquatableView<Content: View & Equatable>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var content: Content
    public init(content: Content) { self.content = content }
    var childViews: [any View] { [content] }
}

extension View where Self: Equatable {
    public func equatable() -> EquatableView<Self> { EquatableView(content: self) }
}

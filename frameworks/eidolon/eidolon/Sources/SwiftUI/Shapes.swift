import UIKit
import CoreGraphics

public struct Angle: Hashable, Comparable {
    public var radians: Double
    public var degrees: Double {
        get { radians * 180 / .pi }
        set { radians = newValue * .pi / 180 }
    }
    public init() { radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { radians = degrees * .pi / 180 }
    public static func radians(_ radians: Double) -> Angle { Angle(radians: radians) }
    public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
    public static func < (a: Angle, b: Angle) -> Bool { a.radians < b.radians }
    public static let zero = Angle()
}

public struct UnitPoint: Hashable {
    public var x: CGFloat
    public var y: CGFloat
    public init() { x = 0; y = 0 }
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public static let zero = UnitPoint(x: 0, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

public struct StrokeStyle: Equatable {
    public var lineWidth: CGFloat
    public var lineCap: CGLineCap
    public var lineJoin: CGLineJoin
    public var dash: [CGFloat]
    public var miterLimit: CGFloat
    public var dashPhase: CGFloat
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [], dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin; self.dash = dash
        self.miterLimit = miterLimit; self.dashPhase = dashPhase
    }
}

public struct Path: Equatable {
    var storage = CGMutablePath()

    public init() {}
    public init(_ rect: CGRect) { storage.addRect(rect) }
    public init(_ path: CGPath) { storage = path.mutableCopy() ?? CGMutablePath() }
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {
        RoundedRectangle.noteContinuous(style)
        roundedRectangle(storage, rect, CGSize(width: cornerRadius, height: cornerRadius))
    }
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .circular) {
        RoundedRectangle.noteContinuous(style)
        roundedRectangle(storage, rect, cornerSize)
    }
    public init(ellipseIn rect: CGRect) { storage.addEllipse(in: rect) }
    public init(_ callback: (inout Path) -> Void) {
        var path = Path()
        callback(&path)
        self.storage = path.storage
    }

    public var cgPath: CGPath { storage }
    public var isEmpty: Bool { storage.isEmpty }
    public var boundingRect: CGRect { storage.boundingBoxOfPath }

    // A path is a value: a copy that is changed must not change the original, though both hold the same CGPath until then.
    mutating func unique() {
        if !isKnownUniquelyReferenced(&storage) { storage = storage.mutableCopy() ?? CGMutablePath() }
    }

    public var currentPoint: CGPoint? { storage.isEmpty ? nil : storage.currentPoint }
    public func contains(_ p: CGPoint, eoFill: Bool = false) -> Bool { storage.contains(p, using: eoFill ? .evenOdd : .winding) }

    public mutating func move(to point: CGPoint) { unique(); storage.move(to: point) }
    public mutating func addLine(to point: CGPoint) { unique(); storage.addLine(to: point) }
    public mutating func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) { unique(); storage.addRect(rect, transform: transform) }
    public mutating func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) { unique(); storage.addEllipse(in: rect, transform: transform) }
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .circular, transform: CGAffineTransform = .identity) {
        RoundedRectangle.noteContinuous(style)
        var rounded = Path()
        roundedRectangle(rounded.storage, rect, cornerSize)
        addPath(rounded, transform: transform)
    }
    public mutating func addQuadCurve(to point: CGPoint, control: CGPoint) { unique(); storage.addQuadCurve(to: point, control: control) }
    public mutating func addCurve(to point: CGPoint, control1: CGPoint, control2: CGPoint) {
        unique()
        storage.addCurve(to: point, control1: control1, control2: control2)
    }
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {
        unique()
        storage.addArc(center: center, radius: radius, startAngle: CGFloat(startAngle.radians), endAngle: CGFloat(endAngle.radians), clockwise: clockwise, transform: transform)
    }
    public mutating func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {
        unique()
        storage.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius, transform: transform)
    }
    public mutating func addPath(_ other: Path, transform: CGAffineTransform = .identity) { unique(); storage.addPath(other.storage, transform: transform) }
    public mutating func closeSubpath() { unique(); storage.closeSubpath() }
    public func applying(_ transform: CGAffineTransform) -> Path {
        var copy = transform
        return Path(storage.copy(using: &copy) ?? storage)
    }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { applying(CGAffineTransformMakeTranslation(dx, dy)) }
    public static func == (a: Path, b: Path) -> Bool { a.storage == b.storage }
}

extension Path: Shape, PrimitiveView {
    public func path(in rect: CGRect) -> Path { self }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public protocol Shape: View, Animatable {
    func path(in rect: CGRect) -> Path
    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}

extension Shape {
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { proposal.replacingUnspecifiedDimensions() }
}

public protocol InsettableShape: Shape {
    associatedtype InsetShape: InsettableShape
    func inset(by amount: CGFloat) -> InsetShape
}

extension Shape {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    public func fill(_ color: Color) -> some View { _ShapeView(shape: self, fill: color, stroke: nil, style: StrokeStyle(lineWidth: 0)) }
    public func fill() -> some View { _ShapeView(shape: self, fill: nil, stroke: nil, style: StrokeStyle(lineWidth: 0)) }
    public func stroke(_ color: Color, lineWidth: CGFloat = 1) -> some View {
        _ShapeView(shape: self, fill: Color.clear, stroke: color, style: StrokeStyle(lineWidth: lineWidth))
    }
    public func stroke(_ color: Color, style: StrokeStyle) -> some View {
        _ShapeView(shape: self, fill: Color.clear, stroke: color, style: style)
    }
    public func strokeBorder(_ color: Color, lineWidth: CGFloat = 1) -> some View {
        _ShapeView(shape: self, fill: Color.clear, stroke: color, style: StrokeStyle(lineWidth: lineWidth), inside: true)
    }
    public func strokeBorder(_ color: Color, style: StrokeStyle) -> some View {
        _ShapeView(shape: self, fill: Color.clear, stroke: color, style: style, inside: true)
    }
}

public struct _ShapeView<Content: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let shape: Content
    let fill: Color?
    let stroke: Color?
    let style: StrokeStyle
    var inside = false
    var fillPaint: _GradientPaint?
    var strokePaint: _GradientPaint?
    var shadow: ShadowStyle?
    var lineWidth: CGFloat { style.lineWidth }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

protocol ShapeViewLike {
    var shapeValue: any Shape { get }
    var fillColor: Color? { get }
    var strokeColor: Color? { get }
    var strokeWidth: CGFloat { get }
    var strokeStyle: StrokeStyle { get }
    var strokeInside: Bool { get }
    var paints: (_GradientPaint?, _GradientPaint?) { get }
    var shapeShadow: ShadowStyle? { get }
}

extension _ShapeView: ShapeViewLike {
    var shapeValue: any Shape { shape }
    var fillColor: Color? { fill }
    var strokeColor: Color? { stroke }
    var strokeWidth: CGFloat { lineWidth }
    var strokeStyle: StrokeStyle { style }
    var strokeInside: Bool { inside }
    var paints: (_GradientPaint?, _GradientPaint?) { (fillPaint, strokePaint) }
    var shapeShadow: ShadowStyle? { shadow }
}

final class ShapeNode: LayoutNode {
    var shape: (any Shape)? { journey.shown?.shape }
    var fill: UIColor?
    var stroke: UIColor?
    var lineWidth: CGFloat = 0
    var inside = false
    var shapeLayer: CAShapeLayer { uiView.layer as! CAShapeLayer }

    init() {
        super.init(view: ShapeBackedView())
        uiView.backgroundColor = .clear
    }

    var lastSize = CGSize.zero
    lazy var journey = Journey<AnimatedShape>(compatible: AnimatedShape.isOneKind) { [unowned self] in self.layoutContents(self.lastSize) }

    // The shape on screen is `shape`; while an animation runs it is the shape on the way to the last one it was given.
    func retarget(_ new: any Shape, animation: Animation?) {
        journey.retarget(AnimatedShape(shape: new), animation: animation, animates: lastSize != .zero)
    }

    override func dispose() {
        journey.dispose()
        super.dispose()
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let animation = Updates.animationForFlush ?? env.animation
        if let described = view as? ShapeViewLike {
            retarget(described.shapeValue is ContainerRelativeShape ? (env.containerShapeValue ?? described.shapeValue) : described.shapeValue, animation: animation)
            fill = described.fillColor?.uiColor
            stroke = described.strokeColor?.uiColor
            lineWidth = described.strokeWidth
        } else if let plain = view as? any Shape {
            retarget(plain is ContainerRelativeShape ? (env.containerShapeValue ?? plain) : plain, animation: animation)
            fill = env.foregroundColor ?? .black
            stroke = nil
            lineWidth = 0
        }
        shapeLayer.fillColor = fill?.cgColor
        shapeLayer.strokeColor = stroke?.cgColor
        shapeLayer.lineWidth = lineWidth
        let style = (view as? ShapeViewLike)?.strokeStyle ?? StrokeStyle(lineWidth: lineWidth)
        inside = (view as? ShapeViewLike)?.strokeInside ?? false
        switch style.lineCap {
        case .round: shapeLayer.lineCap = CAShapeLayerLineCap.round
        case .square: shapeLayer.lineCap = CAShapeLayerLineCap.square
        default: shapeLayer.lineCap = CAShapeLayerLineCap.butt
        }
        switch style.lineJoin {
        case .round: shapeLayer.lineJoin = CAShapeLayerLineJoin.round
        case .bevel: shapeLayer.lineJoin = CAShapeLayerLineJoin.bevel
        default: shapeLayer.lineJoin = CAShapeLayerLineJoin.miter
        }
        shapeLayer.miterLimit = style.miterLimit
        shapeLayer.lineDashPattern = style.dash.isEmpty ? nil : style.dash.map { NSNumber(value: Double($0)) }
        shapeLayer.lineDashPhase = style.dashPhase
        if let shadow = (view as? ShapeViewLike)?.shapeShadow {
            if shadow.inner { _Unsupported.note("ShadowStyle.inner", "CoreAnimation of iOS 6 has no inner shadows; nothing is drawn for it") }
            shapeLayer.shadowColor = shadow.inner ? nil : shadow.color.uiColor.cgColor
            shapeLayer.shadowOpacity = shadow.inner ? 0 : 1
            shapeLayer.shadowRadius = shadow.radius
            shapeLayer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
        } else {
            shapeLayer.shadowOpacity = 0
        }
        let paints = (view as? ShapeViewLike)?.paints ?? (nil, nil)
        fillPaint = paints.0
        strokePaint = paints.1
        strokeStyle = style
        if fillPaint != nil { shapeLayer.fillColor = nil }
        if strokePaint != nil { shapeLayer.strokeColor = nil }
        if fillPaint == nil && strokePaint == nil {
            paintLayer?.removeFromSuperlayer()
            paintLayer = nil
        }
    }

    var fillPaint: _GradientPaint?
    var strokePaint: _GradientPaint?
    var strokeStyle = StrokeStyle(lineWidth: 0)
    var paintLayer: PaintLayer?

    func updatePaint(_ path: CGPath, _ size: CGSize) {
        guard let paint = fillPaint ?? strokePaint else { return }
        let layer = paintLayer ?? PaintLayer()
        if paintLayer == nil {
            layer.contentsScale = UIScreen.main.scale
            shapeLayer.addSublayer(layer)
            paintLayer = layer
        }
        layer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        layer.paint = paint
        if fillPaint != nil {
            layer.clip = path
        } else {
            layer.clip = path.copy(strokingWithWidth: strokeStyle.lineWidth, lineCap: strokeStyle.lineCap, lineJoin: strokeStyle.lineJoin, miterLimit: strokeStyle.miterLimit)
        }
        layer.setNeedsDisplay()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let proposal = ProposedViewSize(width: p.width, height: p.height)
        return shape?.sizeThatFits(proposal) ?? proposal.replacingUnspecifiedDimensions()
    }

    override func layoutContents(_ size: CGSize) {
        lastSize = size
        guard let shape else { return }
        let inset = inside ? lineWidth / 2 : 0
        let rect = CGRect(x: inset, y: inset, width: max(0, size.width - 2 * inset), height: max(0, size.height - 2 * inset))
        let path = shape.path(in: rect).cgPath
        shapeLayer.path = path
        updatePaint(path, size)
    }
}

final class ShapeBackedView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
}

public struct Rectangle: Shape, PrimitiveView, InsettableShape {
    var insetAmount: CGFloat = 0
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(insetRect(rect, insetAmount)) }
    public func inset(by amount: CGFloat) -> Rectangle { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct RoundedRectangle: Shape, PrimitiveView, InsettableShape {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    var insetAmount: CGFloat = 0
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {
        cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
        self.style = style
        Self.noteContinuous(style)
    }
    public init(cornerSize: CGSize, style: RoundedCornerStyle = .circular) {
        self.cornerSize = cornerSize
        self.style = style
        Self.noteContinuous(style)
    }
    static func noteContinuous(_ style: RoundedCornerStyle) {
        if style == .continuous { _Unsupported.note("RoundedCornerStyle.continuous", "continuous corners are a curve iOS 6 has no path for; circular corners are drawn") }
    }
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerSize.width, cornerSize.height) }
        set { cornerSize = CGSize(width: newValue.first, height: newValue.second) }
    }
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: insetRect(rect, insetAmount), cornerSize: CGSize(width: max(0, cornerSize.width - insetAmount), height: max(0, cornerSize.height - insetAmount)))
        return path
    }
    public func inset(by amount: CGFloat) -> RoundedRectangle { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct Circle: Shape, PrimitiveView, InsettableShape {
    var insetAmount: CGFloat = 0
    public init() {}
    public func path(in whole: CGRect) -> Path {
        let rect = insetRect(whole, insetAmount)
        let side = min(rect.size.width, rect.size.height)
        let box = CGRect(x: rect.origin.x + (rect.size.width - side) / 2, y: rect.origin.y + (rect.size.height - side) / 2, width: side, height: side)
        return Path(ellipseIn: box)
    }
    public func inset(by amount: CGFloat) -> Circle { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

extension Circle {
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        let side: CGFloat
        switch (proposal.width, proposal.height) {
        case (let width?, let height?): side = min(width, height)
        case (let width?, nil): side = width
        case (nil, let height?): side = height
        default: side = 10
        }
        return CGSize(width: side, height: side)
    }
}

public struct Ellipse: Shape, PrimitiveView, InsettableShape {
    var insetAmount: CGFloat = 0
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(ellipseIn: insetRect(rect, insetAmount)) }
    public func inset(by amount: CGFloat) -> Ellipse { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct Capsule: Shape, PrimitiveView, InsettableShape {
    var insetAmount: CGFloat = 0
    public var style: RoundedCornerStyle
    public init(style: RoundedCornerStyle = .circular) { self.style = style }
    public func path(in whole: CGRect) -> Path {
        let rect = insetRect(whole, insetAmount)
        return Path(roundedRect: rect, cornerRadius: min(rect.size.width, rect.size.height) / 2)
    }
    public func inset(by amount: CGFloat) -> Capsule { var copy = self; copy.insetAmount += amount; return copy }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public enum RoundedCornerStyle: Equatable { case circular, continuous }

public struct Gradient {
    public struct Stop {
        public var color: Color
        public var location: CGFloat
        public init(color: Color, location: CGFloat) { self.color = color; self.location = location }
    }
    public var stops: [Stop]
    public init(stops: [Stop]) { self.stops = stops }
    public init(colors: [Color]) {
        stops = colors.enumerated().map { index, color in
            Stop(color: color, location: colors.count > 1 ? CGFloat(index) / CGFloat(colors.count - 1) : 0)
        }
    }
}

public struct LinearGradient: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let gradient: Gradient
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = gradient; self.startPoint = startPoint; self.endPoint = endPoint
    }
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
    }
    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(stops: stops), startPoint: startPoint, endPoint: endPoint)
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GradientNode(); n.update(self, env); return n }
}

final class GradientBackedView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}

final class GradientNode: LayoutNode {
    var gradientLayer: CAGradientLayer { uiView.layer as! CAGradientLayer }
    init() { super.init(view: GradientBackedView()) }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let g = view as? LinearGradient else { return }
        gradientLayer.colors = g.gradient.stops.map { $0.color.uiColor.cgColor }
        gradientLayer.locations = g.gradient.stops.map { NSNumber(value: Double($0.location)) }
        gradientLayer.startPoint = CGPoint(x: g.startPoint.x, y: g.startPoint.y)
        gradientLayer.endPoint = CGPoint(x: g.endPoint.x, y: g.endPoint.y)
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
}

func insetRect(_ rect: CGRect, _ amount: CGFloat) -> CGRect {
    guard amount != 0 else { return rect }
    return CGRect(x: rect.origin.x + amount, y: rect.origin.y + amount,
                  width: max(0, rect.size.width - 2 * amount), height: max(0, rect.size.height - 2 * amount))
}

func roundedRectangle(_ path: CGMutablePath, _ rect: CGRect, _ corner: CGSize) {
    let rx = min(max(corner.width, 0), rect.size.width / 2), ry = min(max(corner.height, 0), rect.size.height / 2)
    guard rx > 0, ry > 0 else { path.addRect(rect); return }
    let minX = rect.origin.x, minY = rect.origin.y, maxX = minX + rect.size.width, maxY = minY + rect.size.height
    let k: CGFloat = 0.5522847498
    path.move(to: CGPoint(x: minX + rx, y: minY))
    path.addLine(to: CGPoint(x: maxX - rx, y: minY))
    path.addCurve(to: CGPoint(x: maxX, y: minY + ry), control1: CGPoint(x: maxX - rx + rx * k, y: minY), control2: CGPoint(x: maxX, y: minY + ry - ry * k))
    path.addLine(to: CGPoint(x: maxX, y: maxY - ry))
    path.addCurve(to: CGPoint(x: maxX - rx, y: maxY), control1: CGPoint(x: maxX, y: maxY - ry + ry * k), control2: CGPoint(x: maxX - rx + rx * k, y: maxY))
    path.addLine(to: CGPoint(x: minX + rx, y: maxY))
    path.addCurve(to: CGPoint(x: minX, y: maxY - ry), control1: CGPoint(x: minX + rx - rx * k, y: maxY), control2: CGPoint(x: minX, y: maxY - ry + ry * k))
    path.addLine(to: CGPoint(x: minX, y: minY + ry))
    path.addCurve(to: CGPoint(x: minX + rx, y: minY), control1: CGPoint(x: minX, y: minY + ry - ry * k), control2: CGPoint(x: minX + rx - rx * k, y: minY))
    path.closeSubpath()
}

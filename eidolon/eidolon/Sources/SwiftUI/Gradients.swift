import UIKit
import CoreGraphics

public struct _GradientPaint {
    enum Kind {
        case linear(UnitPoint, UnitPoint)
        case radial(UnitPoint, CGFloat, CGFloat)
        case elliptical(UnitPoint, CGFloat, CGFloat)
        case angular(UnitPoint, Angle, Angle)
    }
    let kind: Kind
    let stops: [Gradient.Stop]

    func cgGradient() -> CGGradient? {
        let space = CGColorSpaceCreateDeviceRGB()
        var components: [CGFloat] = []
        var locations: [CGFloat] = []
        for stop in stops {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if !stop.color.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
                var white: CGFloat = 0
                stop.color.uiColor.getWhite(&white, alpha: &a)
                r = white; g = white; b = white
            }
            components += [r, g, b, a]
            locations.append(stop.location)
        }
        return CGGradient(colorSpace: space, colorComponents: components, locations: locations, count: stops.count)
    }

    func color(at fraction: CGFloat) -> UIColor {
        guard let first = stops.first else { return .clear }
        if fraction <= first.location { return first.color.uiColor }
        for (index, stop) in stops.enumerated().dropFirst() where fraction <= stop.location {
            let previous = stops[index - 1]
            let t = (fraction - previous.location) / max(stop.location - previous.location, 0.0001)
            var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            previous.color.uiColor.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
            stop.color.uiColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            return UIColor(red: r0 + (r1 - r0) * t, green: g0 + (g1 - g0) * t, blue: b0 + (b1 - b0) * t, alpha: a0 + (a1 - a0) * t)
        }
        return stops.last!.color.uiColor
    }

    func draw(_ context: CGContext, _ rect: CGRect) {
        func point(_ p: UnitPoint) -> CGPoint { CGPoint(x: rect.origin.x + rect.size.width * p.x, y: rect.origin.y + rect.size.height * p.y) }
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        switch kind {
        case .linear(let start, let end):
            guard let gradient = cgGradient() else { return }
            context.drawLinearGradient(gradient, start: point(start), end: point(end), options: options)
        case .radial(let center, let startRadius, let endRadius):
            guard let gradient = cgGradient() else { return }
            context.drawRadialGradient(gradient, startCenter: point(center), startRadius: startRadius, endCenter: point(center), endRadius: endRadius, options: options)
        case .elliptical(let center, let startFraction, let endFraction):
            guard let gradient = cgGradient(), rect.size.width > 0, rect.size.height > 0 else { return }
            context.saveGState()
            let c = point(center)
            context.translateBy(x: c.x, y: c.y)
            context.scaleBy(x: rect.size.width / 2, y: rect.size.height / 2)
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: startFraction, endCenter: .zero, endRadius: endFraction, options: options)
            context.restoreGState()
        case .angular(let center, let start, let end):
            let c = point(center)
            let radius = hypot(rect.size.width, rect.size.height)
            let sweep = end.radians - start.radians
            let steps = 180
            for step in 0..<steps {
                let a0 = start.radians + sweep * Double(step) / Double(steps)
                let a1 = start.radians + sweep * Double(step + 1) / Double(steps)
                context.setFillColor(color(at: CGFloat(step) / CGFloat(steps - 1)).cgColor)
                context.move(to: c)
                context.addLine(to: CGPoint(x: c.x + radius * CGFloat(cos(a0)), y: c.y + radius * CGFloat(sin(a0))))
                context.addLine(to: CGPoint(x: c.x + radius * CGFloat(cos(a1 + 0.004)), y: c.y + radius * CGFloat(sin(a1 + 0.004))))
                context.closePath()
                context.fillPath()
            }
        }
    }
}

extension ShapeStyle {
    public var _gradientPaint: _GradientPaint? { (self as? _GradientStyle)?.paint ?? (self as? OptionalPaintStyle)?.optionalPaint }
}

protocol _GradientStyle { var paint: _GradientPaint { get } }

extension LinearGradient: _GradientStyle {
    var paint: _GradientPaint { _GradientPaint(kind: .linear(startPoint, endPoint), stops: gradient.stops) }
}

final class PaintView: UIView {
    var paint: _GradientPaint? { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard let paint, let context = UIGraphicsGetCurrentContext() else { return }
        paint.draw(context, bounds)
    }
}

final class PaintNode: LayoutNode {
    init() { super.init(view: PaintView()) }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        (uiView as! PaintView).paint = (view as? _GradientStyle)?.paint
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
}

final class PaintLayer: CALayer {
    var paint: _GradientPaint?
    var clip: CGPath?
    override func draw(in context: CGContext) {
        guard let paint, let clip else { return }
        context.addPath(clip)
        context.clip()
        paint.draw(context, bounds)
    }
}

public struct RadialGradient: View, PrimitiveView, ShapeStyle, _GradientStyle {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let gradient: Gradient
    let center: UnitPoint
    let startRadius: CGFloat
    let endRadius: CGFloat
    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = gradient; self.center = center; self.startRadius = startRadius; self.endRadius = endRadius
    }
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadius: startRadius, endRadius: endRadius)
    }
    public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(stops: stops), center: center, startRadius: startRadius, endRadius: endRadius)
    }
    public var _uiColor: UIColor? { gradient.stops.first?.color.uiColor }
    var paint: _GradientPaint { _GradientPaint(kind: .radial(center, startRadius, endRadius), stops: gradient.stops) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PaintNode(); n.update(self, env); return n }
}

public struct EllipticalGradient: View, PrimitiveView, ShapeStyle, _GradientStyle {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let gradient: Gradient
    let center: UnitPoint
    let startFraction: CGFloat
    let endFraction: CGFloat
    public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.gradient = gradient; self.center = center; startFraction = startRadiusFraction * 2; endFraction = endRadiusFraction * 2
    }
    public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public var _uiColor: UIColor? { gradient.stops.first?.color.uiColor }
    var paint: _GradientPaint { _GradientPaint(kind: .elliptical(center, startFraction, endFraction), stops: gradient.stops) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PaintNode(); n.update(self, env); return n }
}

public struct AngularGradient: View, PrimitiveView, ShapeStyle, _GradientStyle {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let gradient: Gradient
    let center: UnitPoint
    let startAngle: Angle
    let endAngle: Angle
    public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {
        self.gradient = gradient; self.center = center; self.startAngle = startAngle
        self.endAngle = endAngle == startAngle ? Angle(radians: startAngle.radians + 2 * Double.pi) : endAngle
    }
    public init(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) {
        self.init(gradient: Gradient(colors: colors), center: center, startAngle: startAngle, endAngle: endAngle)
    }
    public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {
        self.init(gradient: gradient, center: center, startAngle: angle, endAngle: Angle(radians: angle.radians + 2 * Double.pi))
    }
    public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) {
        self.init(gradient: Gradient(colors: colors), center: center, angle: angle)
    }
    public var _uiColor: UIColor? { gradient.stops.first?.color.uiColor }
    var paint: _GradientPaint { _GradientPaint(kind: .angular(center, startAngle, endAngle), stops: gradient.stops) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PaintNode(); n.update(self, env); return n }
}

public struct AnyGradient: ShapeStyle, _GradientStyle {
    let gradient: Gradient
    public init(_ gradient: Gradient) { self.gradient = gradient }
    public var _uiColor: UIColor? { gradient.stops.first?.color.uiColor }
    var paint: _GradientPaint { _GradientPaint(kind: .linear(.top, .bottom), stops: gradient.stops) }
}

extension Gradient: ShapeStyle, _GradientStyle {
    public var _uiColor: UIColor? { stops.first?.color.uiColor }
    var paint: _GradientPaint { _GradientPaint(kind: .linear(.top, .bottom), stops: stops) }
}

extension Color {
    public var gradient: AnyGradient {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let light = Color(UIColor(red: min(1, r + 0.12), green: min(1, g + 0.12), blue: min(1, b + 0.12), alpha: a))
        return AnyGradient(Gradient(colors: [light, self]))
    }
}

public struct ShadowStyle: Equatable {
    let inner: Bool
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    public static func drop(color: Color = Color(white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle {
        ShadowStyle(inner: false, color: color, radius: radius, x: x, y: y)
    }
    public static func inner(color: Color = Color(white: 0, opacity: 0.55), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle {
        ShadowStyle(inner: true, color: color, radius: radius, x: x, y: y)
    }
    public static func == (a: Self, b: Self) -> Bool { a.inner == b.inner && a.radius == b.radius && a.x == b.x && a.y == b.y }
}

public struct _ShadowedStyle<Base: ShapeStyle>: ShapeStyle, _ShadowCarrier {
    let base: Base
    let shadow: ShadowStyle
    public var _uiColor: UIColor? { base._uiColor }
    var carriedShadow: ShadowStyle { shadow }
}

protocol _ShadowCarrier { var carriedShadow: ShadowStyle { get } }

extension ShapeStyle {
    public func shadow(_ style: ShadowStyle) -> _ShadowedStyle<Self> { _ShadowedStyle(base: self, shadow: style) }
    var _shadowStyle: ShadowStyle? { (self as? _ShadowCarrier)?.carriedShadow }
}

extension _ShadowedStyle: _GradientStyle where Base: _GradientStyle {
    var paint: _GradientPaint { base.paint }
}

extension ShapeStyle where Self == LinearGradient {
    public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
    }
    public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
    public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint)
    }
}

extension ShapeStyle where Self == RadialGradient {
    public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius)
    }
    public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
    }
    public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius)
    }
}

extension ShapeStyle where Self == EllipticalGradient {
    public static func ellipticalGradient(_ gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(gradient: gradient, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public static func ellipticalGradient(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(colors: colors, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public static func ellipticalGradient(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(gradient: Gradient(stops: stops), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
}

extension ShapeStyle where Self == AngularGradient {
    public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
        AngularGradient(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle)
    }
    public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
        AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle)
    }
    public static func angularGradient(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
        AngularGradient(gradient: Gradient(stops: stops), center: center, startAngle: startAngle, endAngle: endAngle)
    }
    public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
        AngularGradient(gradient: gradient, center: center, angle: angle)
    }
    public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
        AngularGradient(colors: colors, center: center, angle: angle)
    }
    public static func conicGradient(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
        AngularGradient(gradient: Gradient(stops: stops), center: center, angle: angle)
    }
}

extension ShapeStyle where Self == ImagePaint {
    public static func image(_ image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> ImagePaint {
        ImagePaint(image: image, sourceRect: sourceRect, scale: scale)
    }
}

import UIKit
import CoreGraphics

public struct GraphicsContext {
    public struct GradientOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let `repeat` = GradientOptions(rawValue: 1)
        public static let mirror = GradientOptions(rawValue: 2)
        public static let linearColor = GradientOptions(rawValue: 4)
    }

    public struct Shading {
        enum Kind {
            case color(UIColor)
            case linear(Gradient, CGPoint, CGPoint)
            case radial(Gradient, CGPoint, CGFloat, CGFloat)
            case conic(Gradient, CGPoint, Angle)
        }
        let kind: Kind
        var color: UIColor { if case .color(let c) = kind { return c }; return .black }
        public static func color(_ color: Color) -> Shading { Shading(kind: .color(color.uiColor)) }
        public static func color(red: Double, green: Double, blue: Double, opacity: Double = 1) -> Shading {
            Shading(kind: .color(UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))))
        }
        public static func color(white: Double, opacity: Double = 1) -> Shading { Shading(kind: .color(UIColor(white: CGFloat(white), alpha: CGFloat(opacity)))) }
        public static func style<S: ShapeStyle>(_ style: S) -> Shading { Shading(kind: .color(style._uiColor ?? .black)) }
        public static func linearGradient(_ gradient: Gradient, startPoint: CGPoint, endPoint: CGPoint, options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .linear(gradient, startPoint, endPoint))
        }
        public static func radialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .radial(gradient, center, startRadius, endRadius))
        }
        public static func conicGradient(_ gradient: Gradient, center: CGPoint, angle: Angle = Angle(), options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .conic(gradient, center, angle))
        }
        public static let backdrop = Shading(kind: .color(.clear))
        public static let foreground = Shading(kind: .color(.black))
    }

    public struct ClipOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let inverse = ClipOptions(rawValue: 1)
    }

    public struct FilterOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let linearColor = FilterOptions(rawValue: 1)
    }
    public struct ShadowOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let shadowAbove = ShadowOptions(rawValue: 1)
        public static let shadowOnly = ShadowOptions(rawValue: 2)
        public static let invertsAlpha = ShadowOptions(rawValue: 4)
        public static let disablesGroup = ShadowOptions(rawValue: 8)
    }
    public struct BlurOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let opaque = BlurOptions(rawValue: 1)
        public static let dithersResult = BlurOptions(rawValue: 2)
    }

    public struct Filter {
        enum Kind { case shadow(UIColor, CGFloat, CGFloat, CGFloat), transform(CGAffineTransform), unsupported(String) }
        let kind: Kind
        public static func shadow(color: Color = Color(white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0, blendMode: BlendMode = .normal, options: ShadowOptions = ShadowOptions()) -> Filter {
            Filter(kind: .shadow(color.uiColor, radius, x, y))
        }
        public static func projectionTransform(_ matrix: ProjectionTransform) -> Filter {
            Filter(kind: .transform(CGAffineTransform(a: matrix.m11, b: matrix.m12, c: matrix.m21, d: matrix.m22, tx: matrix.m31, ty: matrix.m32)))
        }
        public static func blur(radius: CGFloat, options: BlurOptions = BlurOptions()) -> Filter { Filter(kind: .unsupported("GraphicsContext blur")) }
        public static func colorMatrix(_ matrix: ColorMatrix) -> Filter { Filter(kind: .unsupported("GraphicsContext colorMatrix")) }
        public static func hueRotation(_ angle: Angle) -> Filter { Filter(kind: .unsupported("GraphicsContext hueRotation")) }
        public static func saturation(_ amount: Double) -> Filter { Filter(kind: .unsupported("GraphicsContext saturation")) }
        public static func brightness(_ amount: Double) -> Filter { Filter(kind: .unsupported("GraphicsContext brightness")) }
        public static func contrast(_ amount: Double) -> Filter { Filter(kind: .unsupported("GraphicsContext contrast")) }
        public static func grayscale(_ amount: Double) -> Filter { Filter(kind: .unsupported("GraphicsContext grayscale")) }
        public static func colorInvert(_ amount: Double = 1) -> Filter { Filter(kind: .unsupported("GraphicsContext colorInvert")) }
        public static func colorMultiply(_ color: Color) -> Filter { Filter(kind: .unsupported("GraphicsContext colorMultiply")) }
        public static var luminanceToAlpha: Filter { Filter(kind: .unsupported("GraphicsContext luminanceToAlpha")) }
        public static func alphaThreshold(min: Double, max: Double = 1, color: Color = .black) -> Filter { Filter(kind: .unsupported("GraphicsContext alphaThreshold")) }
    }

    public enum BlendMode: Equatable {
        case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion
        case hue, saturation, color, luminosity, clear, copy, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn
        case destinationOut, destinationAtop, xor, plusDarker, plusLighter
        var cg: CGBlendMode {
            switch self {
            case .normal: return .normal
            case .multiply: return .multiply
            case .screen: return .screen
            case .overlay: return .overlay
            case .darken: return .darken
            case .lighten: return .lighten
            case .colorDodge: return .colorDodge
            case .colorBurn: return .colorBurn
            case .softLight: return .softLight
            case .hardLight: return .hardLight
            case .difference: return .difference
            case .exclusion: return .exclusion
            case .hue: return .hue
            case .saturation: return .saturation
            case .color: return .color
            case .luminosity: return .luminosity
            case .clear: return .clear
            case .copy: return .copy
            case .sourceIn: return .sourceIn
            case .sourceOut: return .sourceOut
            case .sourceAtop: return .sourceAtop
            case .destinationOver: return .destinationOver
            case .destinationIn: return .destinationIn
            case .destinationOut: return .destinationOut
            case .destinationAtop: return .destinationAtop
            case .xor: return .xor
            case .plusDarker: return .plusDarker
            case .plusLighter: return .plusLighter
            }
        }
    }

    public struct ResolvedText {
        let string: NSAttributedString
        public var shading: Shading = .foreground
        public func measure(in size: CGSize) -> CGSize {
            let box = string.boundingRect(with: size, options: [.usesLineFragmentOrigin], context: nil)
            return CGSize(width: ceil(box.size.width), height: ceil(box.size.height))
        }
        public func firstBaseline(in size: CGSize) -> CGFloat { (string.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.ascender ?? 0 }
        public func lastBaseline(in size: CGSize) -> CGFloat { measure(in: size).height - abs((string.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.descender ?? 0) }
    }

    public struct ResolvedImage {
        let image: UIImage?
        public var size: CGSize { image?.size ?? .zero }
        public let baseline: CGFloat = 0
        public var shading: Shading?
    }

    public struct ResolvedSymbol {
        let image: UIImage?
        public var size: CGSize { image?.size ?? .zero }
    }

    let cg: CGContext
    var bounds = CGRect.zero
    var symbols: [AnyHashable: UIImage] = [:]
    public var opacity: Double = 1
    public var blendMode: BlendMode = .normal
    public var environment = EnvironmentValues()

    func prepare() {
        cg.setAlpha(CGFloat(opacity))
        cg.setBlendMode(blendMode.cg)
    }

    func paint(_ shading: Shading) {
        switch shading.kind {
        case .color(let color):
            cg.setFillColor(color.cgColor)
            cg.fill(CGRectIsEmpty(bounds) ? cg.boundingBoxOfClipPath : CGRectUnion(bounds, cg.boundingBoxOfClipPath))
        case .linear(let gradient, let start, let end):
            guard let g = _GradientPaint(kind: .linear(.top, .bottom), stops: gradient.stops).cgGradient() else { return }
            cg.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .radial(let gradient, let center, let r0, let r1):
            guard let g = _GradientPaint(kind: .linear(.top, .bottom), stops: gradient.stops).cgGradient() else { return }
            cg.drawRadialGradient(g, startCenter: center, startRadius: r0, endCenter: center, endRadius: r1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .conic(let gradient, let center, let angle):
            let box = cg.boundingBoxOfClipPath
            let unit = UnitPoint(x: box.size.width > 0 ? (center.x - box.origin.x) / box.size.width : 0.5,
                                 y: box.size.height > 0 ? (center.y - box.origin.y) / box.size.height : 0.5)
            _GradientPaint(kind: .angular(unit, angle, Angle(radians: angle.radians + 2 * Double.pi)), stops: gradient.stops).draw(cg, box)
        }
    }

    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {
        cg.saveGState()
        prepare()
        cg.addPath(path.cgPath)
        if case .color(let color) = shading.kind {
            cg.setFillColor(color.cgColor)
            style.isEOFilled ? cg.fillPath(using: .evenOdd) : cg.fillPath()
        } else {
            style.isEOFilled ? cg.clip(using: .evenOdd) : cg.clip()
            paint(shading)
        }
        cg.restoreGState()
    }

    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {
        stroke(path, with: shading, style: StrokeStyle(lineWidth: lineWidth))
    }

    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {
        cg.saveGState()
        prepare()
        cg.setLineWidth(style.lineWidth)
        cg.setLineCap(style.lineCap)
        cg.setLineJoin(style.lineJoin)
        cg.setMiterLimit(style.miterLimit)
        if !style.dash.isEmpty { cg.setLineDash(phase: style.dashPhase, lengths: style.dash) }
        cg.addPath(path.cgPath)
        if case .color(let color) = shading.kind {
            cg.setStrokeColor(color.cgColor)
            cg.strokePath()
        } else {
            cg.replacePathWithStrokedPath()
            cg.clip()
            paint(shading)
        }
        cg.restoreGState()
    }

    public func resolve(_ image: Image) -> ResolvedImage { ResolvedImage(image: image.stored ?? UIImage(named: image.name)) }

    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) {
        draw(resolve(image), in: rect)
    }

    public func draw(_ image: ResolvedImage, in rect: CGRect, style: FillStyle = FillStyle()) {
        guard let loaded = image.image else { return }
        cg.saveGState()
        prepare()
        UIGraphicsPushContext(cg)
        loaded.draw(in: rect, blendMode: blendMode.cg, alpha: CGFloat(opacity))
        UIGraphicsPopContext()
        cg.restoreGState()
    }

    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) {
        draw(resolve(image), at: point, anchor: anchor)
    }

    public func draw(_ image: ResolvedImage, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = image.size
        draw(image, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }

    public func resolve(_ text: Text) -> ResolvedText {
        var font = environment.scaled(text.font?.uiFont ?? environment.fontValue ?? UIFont.systemFont(ofSize: 17))
        if environment.textScale == .secondary { font = UIFont.systemFont(ofSize: font.pointSize * Text.Scale.secondaryRatio) }
        let color = text.color?.uiColor ?? environment.foregroundColor ?? .black
        return ResolvedText(string: NSAttributedString(string: text.content, attributes: [.font: font, .foregroundColor: color]))
    }

    public func draw(_ text: Text, in rect: CGRect) { draw(resolve(text), in: rect) }

    public func draw(_ text: ResolvedText, in rect: CGRect) {
        cg.saveGState()
        prepare()
        UIGraphicsPushContext(cg)
        text.string.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
        UIGraphicsPopContext()
        cg.restoreGState()
    }

    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) { draw(resolve(text), at: point, anchor: anchor) }

    public func draw(_ text: ResolvedText, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        draw(text, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }

    public func resolveSymbol<ID: Hashable>(id: ID) -> ResolvedSymbol? {
        symbols[AnyHashable(id)].map { ResolvedSymbol(image: $0) }
    }

    public func draw(_ symbol: ResolvedSymbol, in rect: CGRect) {
        guard let image = symbol.image else { return }
        cg.saveGState()
        prepare()
        UIGraphicsPushContext(cg)
        image.draw(in: rect)
        UIGraphicsPopContext()
        cg.restoreGState()
    }

    public func draw(_ symbol: ResolvedSymbol, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = symbol.size
        draw(symbol, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }

    public func clip(to path: Path, style: FillStyle = FillStyle(), options: ClipOptions = ClipOptions()) {
        if options.contains(.inverse) {
            let outside = CGMutablePath()
            outside.addRect(CGRectInset(cg.boundingBoxOfClipPath, -1, -1))
            outside.addPath(path.cgPath)
            cg.addPath(outside)
            cg.clip(using: .evenOdd)
            return
        }
        cg.addPath(path.cgPath)
        style.isEOFilled ? cg.clip(using: .evenOdd) : cg.clip()
    }

    public func clipToLayer(opacity: Double = 1, options: ClipOptions = ClipOptions(), content: (inout GraphicsContext) -> Void) {
        let box = cg.boundingBoxOfClipPath
        guard box.size.width > 0, box.size.height > 0, box.size.width < 4096, box.size.height < 4096 else { return }
        let width = Int(ceil(box.size.width)), height = Int(ceil(box.size.height))
        guard let mask = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        mask.setFillColor(gray: options.contains(.inverse) ? 1 : 0, alpha: 1)
        mask.fill(CGRect(x: 0, y: 0, width: width, height: height))
        mask.translateBy(x: -box.origin.x, y: -box.origin.y)
        var layer = GraphicsContext(cg: mask)
        layer.bounds = box
        layer.opacity = opacity
        content(&layer)
        guard let image = mask.makeImage() else { return }
        cg.clip(to: box, mask: image)
    }

    public mutating func addFilter(_ filter: Filter, options: FilterOptions = FilterOptions()) {
        switch filter.kind {
        case .shadow(let color, let radius, let x, let y):
            cg.setShadow(offset: CGSize(width: x, height: y), blur: radius, color: color.cgColor)
        case .transform(let transform):
            cg.concatenate(transform)
        case .unsupported(let name):
            _Unsupported.note(name, "CoreGraphics of iOS 6 has no filters for drawing in progress")
        }
    }

    public func withCGContext(content: (CGContext) throws -> Void) rethrows {
        cg.saveGState()
        defer { cg.restoreGState() }
        try content(cg)
    }

    public mutating func translateBy(x: CGFloat, y: CGFloat) { cg.translateBy(x: x, y: y) }
    public mutating func scaleBy(x: CGFloat, y: CGFloat) { cg.scaleBy(x: x, y: y) }
    public mutating func rotate(by angle: Angle) { cg.rotate(by: CGFloat(angle.radians)) }
    public mutating func concatenate(_ transform: CGAffineTransform) { cg.concatenate(transform) }
    public var transform: CGAffineTransform { cg.ctm }

    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {
        cg.saveGState()
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        var copy = self
        try content(&copy)
        cg.endTransparencyLayer()
        cg.restoreGState()
    }
}

public struct ColorMatrix: Equatable {
    public var r1: Float = 1, r2: Float = 0, r3: Float = 0, r4: Float = 0, r5: Float = 0
    public var g1: Float = 0, g2: Float = 1, g3: Float = 0, g4: Float = 0, g5: Float = 0
    public var b1: Float = 0, b2: Float = 0, b3: Float = 1, b4: Float = 0, b5: Float = 0
    public var a1: Float = 0, a2: Float = 0, a3: Float = 0, a4: Float = 1, a5: Float = 0
    public init() {}
}

public struct Canvas<Symbols: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let symbols: Symbols
    let renderer: (inout GraphicsContext, CGSize) -> Void
    func makeNode(_ env: EnvironmentValues) -> Node { let n = CanvasNode(); n.update(self, env); return n }
}

extension Canvas where Symbols == EmptyView {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        self.init(symbols: EmptyView(), renderer: renderer)
    }
}

protocol CanvasLike {
    var draw: (inout GraphicsContext, CGSize) -> Void { get }
    func symbolImages(_ env: EnvironmentValues) -> [AnyHashable: UIImage]
}

extension Canvas: CanvasLike {
    var draw: (inout GraphicsContext, CGSize) -> Void { renderer }
    func symbolImages(_ env: EnvironmentValues) -> [AnyHashable: UIImage] {
        var images: [AnyHashable: UIImage] = [:]
        for (tag, view) in taggedViews(symbols) {
            if let image = renderToImage(view, env) { images[tag] = image }
        }
        return images
    }
}

extension Canvas {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {
        self.init(symbols: symbols(), renderer: renderer)
    }
}

func renderToImage(_ view: any View, _ env: EnvironmentValues, proposal: CGSize? = nil) -> UIImage? {
    let host = _HostingViewController(rootView: EmptyView())
    host.setRootView(view, env: env)
    let root = host.view!
    let size = host.items.first?.sizeThatFits(ProposedSize(width: proposal?.width, height: proposal?.height)) ?? .zero
    guard size.width > 0, size.height > 0 else { return nil }
    root.frame = CGRect(origin: .zero, size: size)
    root.backgroundColor = .clear
    root.setNeedsLayout()
    root.layoutIfNeeded()
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
    defer { UIGraphicsEndImageContext() }
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    root.layer.render(in: context)
    return UIGraphicsGetImageFromCurrentImageContext()
}

final class CanvasBackedView: UIView {
    var renderer: ((inout GraphicsContext, CGSize) -> Void)?
    var environment = EnvironmentValues()
    var symbols: [AnyHashable: UIImage] = [:]

    override func draw(_ rect: CGRect) {
        guard let renderer, let cg = UIGraphicsGetCurrentContext() else { return }
        var context = GraphicsContext(cg: cg)
        context.bounds = bounds
        context.environment = environment
        context.symbols = symbols
        renderer(&context, bounds.size)
    }
}

final class CanvasNode: LayoutNode {
    var canvas: CanvasBackedView { uiView as! CanvasBackedView }

    init() {
        let view = CanvasBackedView()
        view.backgroundColor = .clear
        view.contentMode = .redraw
        super.init(view: view)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? CanvasLike else { return }
        canvas.renderer = source.draw
        canvas.environment = env
        canvas.symbols = source.symbolImages(env)
        canvas.setNeedsDisplay()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 10, height: p.height ?? 10)
    }

    override func layoutContents(_ size: CGSize) {
        canvas.setNeedsDisplay()
    }
}

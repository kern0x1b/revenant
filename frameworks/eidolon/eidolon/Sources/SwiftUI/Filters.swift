import UIKit
import CoreGraphics
import CoreImage
import OpenGLES

struct ColorFilter {
    enum Kind: Equatable {
        case brightness(Double), contrast(Double), saturation(Double), grayscale(Double)
        case hueRotation(Double), colorInvert, colorMultiply(UIColor), luminanceToAlpha, blur(CGFloat)
    }
    var kinds: [Kind] = []
    var isIdentity: Bool { kinds.isEmpty }
    var softensEdges: Bool { kinds.contains { if case .blur = $0 { return true }; return false } }

    func appending(_ kind: Kind) -> ColorFilter {
        var copy = self
        copy.kinds.append(kind)
        return copy
    }

    private func last(_ matches: (Kind) -> Bool) -> Kind? {
        var found: Kind?
        for kind in kinds where matches(kind) { found = kind }
        return found
    }

    func filtered(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        var input = CIImage(cgImage: cgImage)
        let extent = input.extent
        var controls: [String: Any] = [:]
        if case .grayscale(let amount)? = last({ if case .grayscale = $0 { return true }; return false }) {
            controls["inputSaturation"] = 1 - min(max(amount, 0), 1)
        } else if case .saturation(let amount)? = last({ if case .saturation = $0 { return true }; return false }) {
            controls["inputSaturation"] = amount
        }
        if case .brightness(let amount)? = last({ if case .brightness = $0 { return true }; return false }) {
            controls["inputBrightness"] = amount
        }
        if case .contrast(let amount)? = last({ if case .contrast = $0 { return true }; return false }) {
            controls["inputContrast"] = amount
        }
        if !controls.isEmpty { input = passing("CIColorControls", through: input, controls) ?? input }
        if case .hueRotation(let radians)? = last({ if case .hueRotation = $0 { return true }; return false }) {
            if let turned = hueRotated(cgImage, by: radians) { input = CIImage(cgImage: turned) }
        }
        if case .colorMultiply(let color)? = last({ if case .colorMultiply = $0 { return true }; return false }) {
            input = multiply(input, by: color) ?? input
        }
        if kinds.contains(.colorInvert) { input = passing("CIColorInvert", through: input) ?? input }
        if kinds.contains(.luminanceToAlpha) { input = luminanceToAlpha(input) ?? input }
        if case .blur(let radius)? = last({ if case .blur = $0 { return true }; return false }), radius > 0 {
            input = passing("CIGaussianBlur", through: input, ["inputRadius": radius]) ?? input
        }
        let produced = input.extent
        let from = CGRect(x: extent.minX - produced.minX, y: extent.minY - produced.minY, width: extent.width, height: extent.height)
        guard let out = ColorFilter.context.createCGImage(input, from: from) else { return nil }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }

    private func passing(_ name: String, through image: CIImage, _ values: [String: Any] = [:]) -> CIImage? {
        guard let filter = CIFilter(name: name) else { return nil }
        filter.setValue(image, forKey: "inputImage")
        for (key, value) in values { filter.setValue(value, forKey: key) }
        return filter.outputImage
    }

    private func hueRotated(_ image: CGImage, by radians: Double) -> CGImage? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let turn = radians / (2 * Double.pi)
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Double(bytes[pixel + 3]) / 255
            guard alpha > 0 else { continue }
            let red = Double(bytes[pixel]) / 255 / alpha
            let green = Double(bytes[pixel + 1]) / 255 / alpha
            let blue = Double(bytes[pixel + 2]) / 255 / alpha
            let (turnedRed, turnedGreen, turnedBlue) = ColorFilter.turnHue(red, green, blue, by: turn)
            bytes[pixel] = UInt8(clamping: Int((turnedRed * alpha * 255).rounded()))
            bytes[pixel + 1] = UInt8(clamping: Int((turnedGreen * alpha * 255).rounded()))
            bytes[pixel + 2] = UInt8(clamping: Int((turnedBlue * alpha * 255).rounded()))
        }
        return context.makeImage()
    }

    private static func turnHue(_ red: Double, _ green: Double, _ blue: Double, by turn: Double) -> (Double, Double, Double) {
        let value = max(red, green, blue)
        let chroma = value - min(red, green, blue)
        guard chroma > 0 else { return (red, green, blue) }
        var hue: Double
        switch value {
        case red: hue = (green - blue) / chroma
        case green: hue = 2 + (blue - red) / chroma
        default: hue = 4 + (red - green) / chroma
        }
        hue = (hue / 6 + turn).truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }
        let saturation = chroma / value
        let sector = hue * 6
        let fraction = sector - sector.rounded(.down)
        let lowest = value * (1 - saturation)
        let down = value * (1 - fraction * saturation)
        let up = value * (1 - (1 - fraction) * saturation)
        switch Int(sector.rounded(.down)) % 6 {
        case 0: return (value, up, lowest)
        case 1: return (down, value, lowest)
        case 2: return (lowest, value, up)
        case 3: return (lowest, down, value)
        case 4: return (up, lowest, value)
        default: return (value, lowest, down)
        }
    }

    private func luminanceToAlpha(_ image: CIImage) -> CIImage? {
        passing("CIColorMatrix", through: image, [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
        ])
    }

    private func multiply(_ image: CIImage, by color: UIColor) -> CIImage? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return passing("CIColorMatrix", through: image, [
            "inputRVector": CIVector(x: red, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: green, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: blue, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha),
        ])
    }

    static let context: CIContext = {
        let options: NSDictionary? = EAGLContext(api: .openGLES2) == nil ? [CIContextOption.useSoftwareRenderer.rawValue: true] : nil
        let made = (CIContext.self as AnyObject).perform(NSSelectorFromString("contextWithOptions:"), with: options)
        if let context = made?.takeUnretainedValue() as? CIContext { return context }
        return CIContext()
    }()
}

struct FilterModifier: NodeModifier {
    let filter: ColorFilter
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { FilterNode() }
}

private let filterDifference = "a Core Image filter over a render of the subtree, made when the screen lays out; an animation inside it is not followed frame by frame"

extension View {
    fileprivate func colored(_ filter: ColorFilter) -> some View {
        _ModifiedView(content: self, modifier: FilterModifier(filter: filter))
    }
    public func grayscale(_ amount: Double) -> some View {
        _Unsupported.note("grayscale", filterDifference)
        return colored(ColorFilter().appending(.grayscale(amount)))
    }
    public func saturation(_ amount: Double) -> some View {
        _Unsupported.note("saturation", filterDifference)
        return colored(ColorFilter().appending(.saturation(amount)))
    }
    public func brightness(_ amount: Double) -> some View {
        _Unsupported.note("brightness", filterDifference)
        return colored(ColorFilter().appending(.brightness(amount)))
    }
    public func contrast(_ amount: Double) -> some View {
        _Unsupported.note("contrast", filterDifference)
        return colored(ColorFilter().appending(.contrast(amount)))
    }
    public func colorInvert() -> some View {
        _Unsupported.note("colorInvert", filterDifference)
        return colored(ColorFilter().appending(.colorInvert))
    }
    public func colorMultiply(_ color: Color) -> some View {
        _Unsupported.note("colorMultiply", filterDifference)
        return colored(ColorFilter().appending(.colorMultiply(color.uiColor)))
    }
    public func hueRotation(_ angle: Angle) -> some View {
        _Unsupported.note("hueRotation", filterDifference)
        return colored(ColorFilter().appending(.hueRotation(angle.radians)))
    }
    public func luminanceToAlpha() -> some View {
        _Unsupported.note("luminanceToAlpha", filterDifference)
        return colored(ColorFilter().appending(.luminanceToAlpha))
    }
    public func blur(radius: CGFloat, opaque: Bool = false) -> some View {
        guard radius > 0 else { return colored(ColorFilter()) }
        _Unsupported.note("blur(radius:)", opaque
            ? "a Core Image blur of a render of the view's own content — iOS 6 has no live backdrop to blur — and the picture is made when the screen lays out, not per frame"
            : "a Core Image blur of a render of the view's own content — iOS 6 has no live backdrop to blur — and it covers the content, since the unblurred content would show through the soft edges")
        return colored(ColorFilter().appending(.blur(radius)))
    }
}

final class FilterView: UIView {
    let content = UIView()
    let picture = UIImageView()
    private var pending = false
    private var make: (() -> UIImage?)?
    private var covers = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        content.backgroundColor = .clear
        picture.isUserInteractionEnabled = false
        addSubview(content)
        addSubview(picture)
    }
    required init?(coder: NSCoder) { fatalError("a filter is not loaded from a nib") }

    func wantsNothing() {
        make = nil
        pending = false
        picture.image = nil
        content.isHidden = false
    }

    func wantsPicture(_ make: @escaping () -> UIImage?, coveringContent: Bool) {
        self.make = make
        covers = coveringContent
        pending = true
        content.isHidden = false
        setNeedsLayout()
    }

    override func layoutSubviews() {
        content.frame = bounds
        picture.frame = bounds
        super.layoutSubviews()
        guard pending, let make else { return }
        pending = false
        picture.image = make()
        content.isHidden = covers
    }
}

final class FilterNode: ContainerNode {
    var filter = ColorFilter()
    override init() { super.init(container: FilterView(frame: .zero)) }

    private var filterView: FilterView { uiView as! FilterView }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        filter = (m.modifierValue as! FilterModifier).filter
        content = adopt(reconcile(content, m.modifiedContent, env))
        askForPicture()
    }

    override func mountContents() {
        syncSubviews(filterView.content, children)
        content?.mount()
        askForPicture()
    }

    override func computeSize(_ proposal: ProposedSize) -> CGSize {
        guard let kid = children.first else { return .zero }
        if children.count == 1 { return kid.sizeThatFits(proposal) }
        var size = CGSize.zero
        for kid in children {
            let s = kid.sizeThatFits(proposal)
            size.width = max(size.width, s.width)
            size.height = max(size.height, s.height)
        }
        return size
    }

    override func layoutContents(_ size: CGSize) {
        for kid in children {
            let s = kid.sizeThatFits(ProposedSize(width: size.width, height: size.height))
            kid.place(CGRect(origin: .zero, size: s))
        }
        askForPicture()
    }

    private func askForPicture() {
        guard !filter.isIdentity else { return filterView.wantsNothing() }
        filterView.wantsPicture({ [weak self] in self?.render() }, coveringContent: filter.softensEdges)
    }

    private func render() -> UIImage? {
        let size = filterView.content.bounds.size
        guard size.width >= 1, size.height >= 1 else { return nil }
        _Probe.tracedFilterRender("render \(Int(size.width))x\(Int(size.height)) of view \(Int(filterView.bounds.width))x\(Int(filterView.bounds.height)) content \(filterView.content.frame)")
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        filterView.content.layer.render(in: UIGraphicsGetCurrentContext()!)
        let drawn = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let drawn else { return nil }
        return filter.isIdentity ? drawn : filter.filtered(drawn)
    }
}

import UIKit
import CoreGraphics

public struct DefaultListStyle: ListStyle { public init() {} }
public struct InsetListStyle: ListStyle { public init() {} }
public struct InsetGroupedListStyle: ListStyle { public init() {} }
public struct SidebarListStyle: ListStyle { public init() {} }

extension ListStyle where Self == PlainListStyle {
    public static var plain: PlainListStyle { PlainListStyle() }
}

extension ListStyle where Self == GroupedListStyle {
    public static var grouped: GroupedListStyle { GroupedListStyle() }
}

extension ListStyle where Self == InsetGroupedListStyle {
    public static var insetGrouped: InsetGroupedListStyle { InsetGroupedListStyle() }
}

extension ListStyle where Self == DefaultListStyle {
    public static var automatic: DefaultListStyle { DefaultListStyle() }
}

public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let label: Label
    public let role: ButtonRole?
    let action: () -> Void
    public func trigger() { action() }
}

public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    typealias Configuration = PrimitiveButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

/// The port's own protocol for a primitive button style that wants to see the press. Apple's
/// `PrimitiveButtonStyle` cannot ask for it — its configuration carries no `isPressed`, and a property
/// wrapper on a style never resolves here, because the style is captured in a closure the reconciler does
/// not walk — so the built-in styles adopt this and the node calls it when a style has it.
protocol PressedButtonStyle {
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View
}

public struct ButtonRole: Equatable {
    let name: String
    public static let destructive = ButtonRole(name: "destructive")
    public static let cancel = ButtonRole(name: "cancel")
    public static let confirm = ButtonRole(name: "confirm")
    public static let close = ButtonRole(name: "close")
}

/// The glass of a button on iOS 26: how thick it is and how much of the background it lets through.
/// iOS 6 has no live blur, so the thickness is what the fill is drawn with.
/// The glass of a button on iOS 26: three settings and nothing else, as the interface declares it
/// (`SwiftUICore.swiftinterface:32551` — `regular`, `clear`, `identity`, `Equatable`, no stored
/// property and no initialiser). iOS 6 has no live blur, so a glass button is the release's own button
/// drawn translucent, and `GlassEffect` below is the port's own measurement of that drawing.
public struct Glass: Equatable {
    enum Kind: Equatable { case regular, clear, identity }
    let kind: Kind
    init(_ kind: Kind) { self.kind = kind }
    public static var regular: Glass { Glass(.regular) }
    public static var clear: Glass { Glass(.clear) }
    public static var identity: Glass { Glass(.identity) }
}

/// How translucent a glass button is drawn, which is the port's own: iOS 6 has no blur to measure, so
/// the thickness is the alpha the fill is painted with and the flags say what else the paint does.
struct GlassEffect {
    enum Thickness { case regular, thick }
    var thickness: Thickness = .regular
    var interactive = false
    var isAdaptive = true
    var opacity: Double { thickness == .thick ? 0.9 : 0.75 }
    init(_ glass: Glass) { kind = glass.kind }
    private var kind: Glass.Kind
}


public struct DefaultButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            .background(pressed ? Color(white: 0.85) : Color.white, cornerRadius: 8)
            .border(Color(white: 0.7), width: 1)
    }
}

public struct PlainButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        configuration.label.opacity(pressed ? 0.4 : 1)
    }
}

public struct BorderedButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _BorderedChrome(label: AnyView(configuration.label), prominent: false, pressed: pressed)
    }
}

public struct BorderedProminentButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _BorderedChrome(label: AnyView(configuration.label), prominent: true, pressed: pressed)
    }
}

// The rest of the styles SwiftUI names for a button, drawn with what iOS 6 has: its title bar draws a bare
// blue word, a link is blue and underlined, and a card is the rounded button of the release without the
// fill gradient. Glass and the accessory bar have nothing to correspond to and say so in the journal.
public struct LinkButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {

    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        configuration.label
            .foregroundColor(Color(red: 0.11, green: 0.37, blue: 0.80))
            .underline(true, color: Color(red: 0.11, green: 0.37, blue: 0.80))
            .opacity(pressed ? 0.4 : 1)
    }
}

public struct CardButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _BorderedChrome(label: AnyView(configuration.label), prominent: false, pressed: pressed)
    }
}

extension PrimitiveButtonStyle where Self == DefaultButtonStyle {
    public static var automatic: DefaultButtonStyle { DefaultButtonStyle() }
}

extension PrimitiveButtonStyle where Self == PlainButtonStyle {
    public static var plain: PlainButtonStyle { PlainButtonStyle() }
}

extension PrimitiveButtonStyle where Self == BorderedButtonStyle {
    public static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

extension PrimitiveButtonStyle where Self == BorderedProminentButtonStyle {
    public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}

extension PrimitiveButtonStyle where Self == LinkButtonStyle {
    public static var link: LinkButtonStyle { LinkButtonStyle() }
}

public struct GlassButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    var glass: Glass
    var effect: GlassEffect
    public init() { glass = .regular; effect = GlassEffect(.regular) }
    public init(_ glass: Glass) { self.glass = glass; effect = GlassEffect(glass) }
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _Unsupported.note("PrimitiveButtonStyle.glass", "iOS 6 has no live blur, so a glass button is the release's own button drawn translucent")
        return AnyView(configuration.label
            .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
            .background(Color(UIColor(white: 0.97, alpha: effect.opacity)), cornerRadius: 7)
            .border(Color(white: 0.62), width: 1)
            .opacity(pressed ? 0.4 : 1))
    }
}

public struct GlassProminentButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {

    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _Unsupported.note("PrimitiveButtonStyle.glassProminent", "iOS 6 has no live blur, so a glass button is the release's own button drawn translucent")
        return AnyView(configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
            .background(Color(red: 0.20, green: 0.42, blue: 0.78).opacity(0.85), cornerRadius: 7)
            .opacity(pressed ? 0.4 : 1))
    }
}

public struct AccessoryBarButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _Unsupported.note("PrimitiveButtonStyle.accessoryBar", "iOS 6 has no accessory bar, so the button is the release's own")
        return AnyView(_BorderedChrome(label: AnyView(configuration.label), prominent: false, pressed: pressed))
    }
}

public struct AccessoryBarActionButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {

    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        _Unsupported.note("PrimitiveButtonStyle.accessoryBarAction", "iOS 6 has no accessory bar, so the button is the release's own")
        return AnyView(configuration.label
            .foregroundColor(Color(red: 0.11, green: 0.37, blue: 0.80))
            .opacity(pressed ? 0.4 : 1))
    }
}

extension PrimitiveButtonStyle where Self == CardButtonStyle {
    public static var card: CardButtonStyle { CardButtonStyle() }
}

extension PrimitiveButtonStyle where Self == GlassButtonStyle {
    public static var glass: GlassButtonStyle { GlassButtonStyle() }
    public static func glass(_ glass: Glass) -> GlassButtonStyle { GlassButtonStyle(glass) }
}

extension PrimitiveButtonStyle where Self == GlassProminentButtonStyle {
    public static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

extension PrimitiveButtonStyle where Self == AccessoryBarButtonStyle {
    public static var accessoryBar: AccessoryBarButtonStyle { AccessoryBarButtonStyle() }
}

extension PrimitiveButtonStyle where Self == AccessoryBarActionButtonStyle {
    public static var accessoryBarAction: AccessoryBarActionButtonStyle { AccessoryBarActionButtonStyle() }
}

// A button as iOS 6 draws one: a vertical gradient, a lighter gloss over its upper half, a dark edge and lettering with a
// small shadow. The bordered style is the grey rounded-rect button of the system, the prominent one the blue of a Done button.
struct _BorderedChrome: View {
    let label: any View
    let prominent: Bool
    let pressed: Bool
    @Environment(\.self) var environment

    var body: some View {
        let colors = prominent
            ? (pressed ? [Color(red: 0.30, green: 0.45, blue: 0.80), Color(red: 0.08, green: 0.22, blue: 0.62)]
                       : [Color(red: 0.47, green: 0.63, blue: 0.95), Color(red: 0.12, green: 0.32, blue: 0.82)])
            : (pressed ? [Color(white: 0.86), Color(white: 0.66)] : [Color(white: 0.99), Color(white: 0.80)])
        let edge = prominent ? Color(red: 0.08, green: 0.20, blue: 0.50) : Color(white: 0.52)
        let lettering: Color? = prominent ? .white : nil
        let shadow = prominent ? Color(red: 0, green: 0, blue: 0).opacity(0.45) : Color.white
        let padded = AnyView(label).foregroundColor(lettering)
            .shadow(color: shadow, radius: 0, x: 0, y: prominent ? -1 : 1)
            .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
        switch environment.buttonBorderShape.kind {
        case .capsule:
            return AnyView(padded.background(_ButtonBody(shape: Capsule(), colors: colors, edge: edge, gloss: !pressed)))
        case .roundedRectangle(let radius):
            return AnyView(padded.background(_ButtonBody(shape: RoundedRectangle(cornerRadius: radius ?? 7), colors: colors, edge: edge, gloss: !pressed)))
        case .automatic:
            return AnyView(padded.background(_ButtonBody(shape: RoundedRectangle(cornerRadius: 7), colors: colors, edge: edge, gloss: !pressed)))
        }
    }
}

struct _ButtonBody<S: Shape>: View {
    let shape: S
    let colors: [Color]
    let edge: Color
    let gloss: Bool
    var body: some View {
        ZStack {
            shape.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            if gloss { _Gloss().fill(LinearGradient(colors: [Color.white.opacity(0.42), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom)) }
            shape.stroke(edge, lineWidth: 1)
        }
    }
}

struct _Gloss: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(x: 1, y: 1, width: max(0, rect.width - 2), height: max(0, rect.height / 2 - 1)), cornerRadius: 6)
    }
}





public struct DefaultToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: Binding(get: { configuration.isOn }, set: { _ in })) { configuration.label }
    }
}

public struct SwitchToggleStyle: ToggleStyle {
    public init() {}
    public init(tint: Color) {}
    public func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: Binding(get: { configuration.isOn }, set: { _ in })) { configuration.label }
    }
}

public struct ButtonToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Text(configuration.isOn ? "✓" : "✗")
            configuration.label
        }
    }
}

extension ToggleStyle where Self == SwitchToggleStyle {
    public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}

extension ToggleStyle where Self == ButtonToggleStyle {
    public static var button: ButtonToggleStyle { ButtonToggleStyle() }
}

public struct DefaultLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HStack(spacing: 6) { configuration.icon; configuration.title } }
}

public struct TitleOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.title }
}

public struct IconOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.icon }
}

public struct DefaultProgressViewStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        ProgressView(configuration)
    }
}

public struct LinearProgressViewStyle: ProgressViewStyle {
    var tint: Color?
    public init() {}
    public init(tint: Color) { self.tint = tint }
    public func makeBody(configuration: Configuration) -> some View {
        ProgressView(configuration).tint(tint)
    }
}

public struct CircularProgressViewStyle: ProgressViewStyle {
    var tint: Color?
    public init() {}
    public init(tint: Color) { self.tint = tint }
    public func makeBody(configuration: Configuration) -> some View { ProgressView().tint(tint) }
}

public struct DefaultMenuStyle: MenuStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { Menu(configuration) }
}

public struct DefaultDatePickerStyle: DatePickerStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
public struct SeparatorShapeStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { UIColor(white: 0.78, alpha: 1) }
}

public struct RGBColorSpace: Equatable {
    public static let sRGB = RGBColorSpace()
    public static let sRGBLinear = RGBColorSpace()
    public static let displayP3 = RGBColorSpace()
}

extension Color {
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {
        self.init(UIColor(white: CGFloat(white), alpha: CGFloat(opacity)))
    }
    public init(white: Double, opacity: Double = 1) {
        self.init(UIColor(white: CGFloat(white), alpha: CGFloat(opacity)))
    }
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        self.init(UIColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: CGFloat(opacity)))
    }
}

public struct ProjectionTransform: Equatable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0
    public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0
    public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1
    public init() {}
    public init(_ transform: CGAffineTransform) {
        m11 = transform.a; m12 = transform.b
        m21 = transform.c; m22 = transform.d
        m31 = transform.tx; m32 = transform.ty
    }
}


// Apple's spelling of makeBody for the styles that also take the press, and the forwarding the node
// calls: a style written the Apple way still gets its body, with the press the node has.
extension DefaultButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension PlainButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension BorderedButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension BorderedProminentButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension LinkButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension CardButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension GlassButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension GlassProminentButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension AccessoryBarButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}
extension AccessoryBarActionButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}

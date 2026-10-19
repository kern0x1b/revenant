import UIKit
import CoreGraphics

extension EnvironmentValues {
    func style<C>(_ configuration: C.Type) -> ((C) -> any View)? {
        styles[ObjectIdentifier(C.self)] as? (C) -> any View
    }
}

func setStyle<V: View, C>(_ view: V, _ make: @escaping (C) -> any View) -> some View {
    _ModifiedView(content: view, modifier: EnvironmentModifier(apply: { $0.styles[ObjectIdentifier(C.self)] = make }, onUpdate: nil))
}

func applyStyle<C>(_ env: EnvironmentValues, _ configuration: C, fallback: () -> any View) -> AnyView {
    guard let style = env.style(C.self) else { return AnyView(fallback()) }
    return AnyView(withEnvironment(style(configuration)) { $0.styles.removeValue(forKey: ObjectIdentifier(C.self)) })
}

struct _StyledPart: View, WrappedView {
    let wrapped: any View
    var body: some View { AnyView(wrapped) }
}

// GroupBox

public protocol GroupBoxStyle {
    associatedtype Body: View
    typealias Configuration = GroupBoxStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct GroupBoxStyleConfiguration {
    public struct Label: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct Content: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public let label: Label
    public let content: Content
}

public struct DefaultGroupBoxStyle: GroupBoxStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            configuration.label.font(.headline)
            configuration.content
        }
        .padding(10)
        .background(Color(red: 0.95, green: 0.95, blue: 0.96), cornerRadius: 8)
    }
}

extension GroupBoxStyle where Self == DefaultGroupBoxStyle {
    public static var automatic: DefaultGroupBoxStyle { DefaultGroupBoxStyle() }
}

extension GroupBox where Label == GroupBoxStyleConfiguration.Label, Content == GroupBoxStyleConfiguration.Content {
    public init(_ configuration: GroupBoxStyleConfiguration) {
        self.init(content: { configuration.content }, label: { configuration.label })
    }
}

// LabeledContent

public protocol LabeledContentStyle {
    associatedtype Body: View
    typealias Configuration = LabeledContentStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct LabeledContentStyleConfiguration {
    public struct Label: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct Content: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public let label: Label
    public let content: Content
}

public struct AutomaticLabeledContentStyle: LabeledContentStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            configuration.content.foregroundColor(.gray)
        }
    }
}

extension LabeledContentStyle where Self == AutomaticLabeledContentStyle {
    public static var automatic: AutomaticLabeledContentStyle { AutomaticLabeledContentStyle() }
}

extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
    public init(_ configuration: LabeledContentStyleConfiguration) {
        self.init(content: { configuration.content }, label: { configuration.label })
    }
}

// ControlGroup

public protocol ControlGroupStyle {
    associatedtype Body: View
    typealias Configuration = ControlGroupStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ControlGroupStyleConfiguration {
    public struct Content: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct Label: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public let content: Content
    public let label: Label
}

public struct AutomaticControlGroupStyle: ControlGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HStack(spacing: 8) { configuration.content } }
}

public struct NavigationControlGroupStyle: ControlGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HStack(spacing: 0) { configuration.content } }
}

/// A group drawn as a palette of its controls: on iOS 6 a control group is a segmented control, and a
/// palette is that with the segments' own backgrounds rather than the system's.
public struct PaletteControlGroupStyle: ControlGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        _ModifiedView(content: AnyView(configuration.content), modifier: EnvironmentModifier(apply: { $0.controlGroupPalette = true }, onUpdate: nil))
    }
}

extension ControlGroupStyle where Self == PaletteControlGroupStyle {
    public static var palette: PaletteControlGroupStyle { PaletteControlGroupStyle() }
}

public struct MenuControlGroupStyle: ControlGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Menu { configuration.content } label: { configuration.label }
    }
}

public struct CompactMenuControlGroupStyle: ControlGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Menu { configuration.content } label: { configuration.label }
    }
}

extension ControlGroupStyle where Self == AutomaticControlGroupStyle {
    public static var automatic: AutomaticControlGroupStyle { AutomaticControlGroupStyle() }
}
extension ControlGroupStyle where Self == NavigationControlGroupStyle {
    public static var navigation: NavigationControlGroupStyle { NavigationControlGroupStyle() }
}
extension ControlGroupStyle where Self == MenuControlGroupStyle {
    public static var menu: MenuControlGroupStyle { MenuControlGroupStyle() }
}
extension ControlGroupStyle where Self == CompactMenuControlGroupStyle {
    public static var compactMenu: CompactMenuControlGroupStyle { CompactMenuControlGroupStyle() }
}

extension ControlGroup where Content == ControlGroupStyleConfiguration.Content {
    public init(_ configuration: ControlGroupStyleConfiguration) {
        self.init(content: { configuration.content })
    }
}

// Gauge

public protocol GaugeStyle {
    associatedtype Body: View
    typealias Configuration = GaugeStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct GaugeStyleConfiguration {
    public struct Label: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct CurrentValueLabel: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct MinimumValueLabel: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct MaximumValueLabel: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public struct MarkedValueLabel: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public var value: Double
    public var label: Label
    public var currentValueLabel: CurrentValueLabel?
    public var minimumValueLabel: MinimumValueLabel?
    public var maximumValueLabel: MaximumValueLabel?
}

public struct DefaultGaugeStyle: GaugeStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
            HStack(spacing: 6) {
                if let minimum = configuration.minimumValueLabel { minimum }
                ProgressView(value: configuration.value)
                if let maximum = configuration.maximumValueLabel { maximum }
            }
        }
    }
}

public typealias LinearGaugeStyle = DefaultGaugeStyle
public typealias LinearCapacityGaugeStyle = DefaultGaugeStyle
public typealias AccessoryLinearGaugeStyle = DefaultGaugeStyle
public typealias AccessoryLinearCapacityGaugeStyle = DefaultGaugeStyle

struct _GaugeRing: Shape {
    let fraction: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.size.width, rect.size.height) / 2 - 3
        let center = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        path.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(135 + 270 * fraction), clockwise: false)
        return path
    }
}

public struct AccessoryCircularGaugeStyle: GaugeStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            _GaugeRing(fraction: 1).stroke(Color(white: 0.85), lineWidth: 5)
            _GaugeRing(fraction: configuration.value).stroke(Color.blue, lineWidth: 5)
            if let current = configuration.currentValueLabel { current } else { configuration.label }
        }
        .frame(width: 58, height: 58)
    }
}

public typealias CircularGaugeStyle = AccessoryCircularGaugeStyle
public typealias AccessoryCircularCapacityGaugeStyle = AccessoryCircularGaugeStyle

extension GaugeStyle where Self == DefaultGaugeStyle {
    public static var automatic: DefaultGaugeStyle { DefaultGaugeStyle() }
    public static var linearCapacity: DefaultGaugeStyle { DefaultGaugeStyle() }
    public static var accessoryLinear: DefaultGaugeStyle { DefaultGaugeStyle() }
    public static var accessoryLinearCapacity: DefaultGaugeStyle { DefaultGaugeStyle() }
}
extension GaugeStyle where Self == AccessoryCircularGaugeStyle {
    public static var accessoryCircular: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() }
    public static var accessoryCircularCapacity: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() }
}

// The two names Apple puts on GaugeStyle itself (arm64-apple-ios.swiftinterface:3237 for the circular
// one): the port aliases the styles above, and the statics have to be on the type it names, or they are
// not there at all.
extension GaugeStyle where Self == AccessoryCircularGaugeStyle {
    public static var circular: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() }
}

extension GaugeStyle where Self == DefaultGaugeStyle {
    public static var linear: DefaultGaugeStyle { DefaultGaugeStyle() }
}

// Form

public protocol FormStyle {
    associatedtype Body: View
    typealias Configuration = FormStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct FormStyleConfiguration {
    public struct Content: View, WrappedView { let wrapped: any View; public var body: some View { AnyView(wrapped) } }
    public let content: Content
}

public struct GroupedFormStyle: FormStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _GroupedForm(content: configuration.content) }
}

public typealias AutomaticFormStyle = GroupedFormStyle
public typealias ColumnsFormStyle = GroupedFormStyle

extension FormStyle where Self == GroupedFormStyle {
    public static var automatic: GroupedFormStyle { GroupedFormStyle() }
    public static var grouped: GroupedFormStyle { GroupedFormStyle() }
    public static var columns: GroupedFormStyle { GroupedFormStyle() }
}

extension Form where Content == FormStyleConfiguration.Content {
    public init(_ configuration: FormStyleConfiguration) { self.init(content: { configuration.content }) }
}

struct _GroupedForm: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let content: any View
    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = ListNode(grouped: true)
        node.update(self, env)
        return node
    }
}

extension _GroupedForm: ListLike {
    var listContent: any View { content }
}

extension View {
    public func groupBoxStyle<S: GroupBoxStyle>(_ style: S) -> some View {
        setStyle(self) { (configuration: GroupBoxStyleConfiguration) in style.makeBody(configuration: configuration) }
    }
    public func labeledContentStyle<S: LabeledContentStyle>(_ style: S) -> some View {
        setStyle(self) { (configuration: LabeledContentStyleConfiguration) in style.makeBody(configuration: configuration) }
    }
    public func controlGroupStyle<S: ControlGroupStyle>(_ style: S) -> some View {
        setStyle(self) { (configuration: ControlGroupStyleConfiguration) in style.makeBody(configuration: configuration) }
    }
    public func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View {
        setStyle(self) { (configuration: GaugeStyleConfiguration) in style.makeBody(configuration: configuration) }
    }
    public func formStyle<S: FormStyle>(_ style: S) -> some View {
        setStyle(self) { (configuration: FormStyleConfiguration) in style.makeBody(configuration: configuration) }
    }
}

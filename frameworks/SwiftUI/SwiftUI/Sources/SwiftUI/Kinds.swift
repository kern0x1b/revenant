import UIKit

public struct ScrollIndicatorVisibility: Equatable {
    let raw: Int
    public static let automatic = ScrollIndicatorVisibility(raw: 0)
    public static let visible = ScrollIndicatorVisibility(raw: 1)
    public static let hidden = ScrollIndicatorVisibility(raw: 2)
    public static let never = ScrollIndicatorVisibility(raw: 3)
}

public struct NavigationBarDrawerDisplayMode: Equatable {
    let always: Bool
    public static let automatic = NavigationBarDrawerDisplayMode(always: false)
    public static let always = NavigationBarDrawerDisplayMode(always: true)
}

public struct SearchFieldPlacement: Equatable {
    let raw: Int
    public static let automatic = SearchFieldPlacement(raw: 0)
    public static let toolbar = SearchFieldPlacement(raw: 1)
    public static let sidebar = SearchFieldPlacement(raw: 2)
    public static let navigationBarDrawer = SearchFieldPlacement(raw: 3)
    public static func navigationBarDrawer(displayMode: NavigationBarDrawerDisplayMode) -> SearchFieldPlacement { .navigationBarDrawer }
}

public struct RefreshAction {
    let action: @Sendable () async -> Void
    public func callAsFunction() async { await action() }
}

public struct DismissSearchAction {
    let action: () -> Void
    public func callAsFunction() { action() }
}

public enum ControlActiveState: Equatable, CaseIterable { case key, active, inactive }
public enum LegibilityWeight: Hashable { case regular, bold }
public enum ColorSchemeContrast: Equatable, CaseIterable { case standard, increased }

extension EnvironmentValues {
    public var refresh: RefreshAction? {
        get { values[ObjectIdentifier(RefreshAction.self)] as? RefreshAction }
        set { values[ObjectIdentifier(RefreshAction.self)] = newValue }
    }
    public var dismissSearch: DismissSearchAction {
        get { (values[ObjectIdentifier(DismissSearchAction.self)] as? DismissSearchAction) ?? DismissSearchAction(action: {}) }
        set { values[ObjectIdentifier(DismissSearchAction.self)] = newValue }
    }
    public var controlActiveState: ControlActiveState { .key }
    public var legibilityWeight: LegibilityWeight? { .regular }
    public var colorSchemeContrast: ColorSchemeContrast { .standard }
}

public struct KeyEquivalent: Equatable, ExpressibleByExtendedGraphemeClusterLiteral {
    public var character: Character
    public init(_ character: Character) { self.character = character }
    public init(extendedGraphemeClusterLiteral value: Character) { character = value }
    public static let upArrow = KeyEquivalent("\u{F700}")
    public static let downArrow = KeyEquivalent("\u{F701}")
    public static let leftArrow = KeyEquivalent("\u{F702}")
    public static let rightArrow = KeyEquivalent("\u{F703}")
    public static let escape = KeyEquivalent("\u{1B}")
    public static let delete = KeyEquivalent("\u{8}")
    public static let deleteForward = KeyEquivalent("\u{F728}")
    public static let home = KeyEquivalent("\u{F729}")
    public static let end = KeyEquivalent("\u{F72B}")
    public static let pageUp = KeyEquivalent("\u{F72C}")
    public static let pageDown = KeyEquivalent("\u{F72D}")
    public static let clear = KeyEquivalent("\u{F739}")
    public static let tab = KeyEquivalent("\t")
    public static let space = KeyEquivalent(" ")
    public static let `return` = KeyEquivalent("\r")
}

public struct KeyboardShortcut: Equatable {
    public var key: KeyEquivalent
    public var modifiers: EventModifiers
    public var localization: Localization = .automatic
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) { self.key = key; self.modifiers = modifiers }
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: Localization) {
        self.key = key; self.modifiers = modifiers; self.localization = localization
    }
    public struct Localization: Equatable {
        let raw: Int
        public static let automatic = Localization(raw: 0)
        public static let withoutMirroring = Localization(raw: 1)
        public static let custom = Localization(raw: 2)
    }
    public static let defaultAction = KeyboardShortcut(.return, modifiers: [])
    public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
    public static func == (a: Self, b: Self) -> Bool { a.key == b.key && a.modifiers.rawValue == b.modifiers.rawValue }
}

extension View {
    public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        ignored(self, "keyboardShortcut", "a shortcut is a UIKeyCommand, iOS 7, and this release hands an app no key presses at all: there is no event class for them, and a text field takes what the keyboard of the system sends")
    }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View {
        ignored(self, "keyboardShortcut", "a shortcut is a UIKeyCommand, iOS 7, and this release hands an app no key presses at all: there is no event class for them, and a text field takes what the keyboard of the system sends")
    }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        ignored(self, "keyboardShortcut", "a shortcut is a UIKeyCommand, iOS 7, and this release hands an app no key presses at all: there is no event class for them, and a text field takes what the keyboard of the system sends")
    }
}

public struct TitleAndIconLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HStack(spacing: 6) { configuration.icon; configuration.title } }
}

extension LabelStyle where Self == DefaultLabelStyle {
    public static var automatic: DefaultLabelStyle { DefaultLabelStyle() }
}
extension LabelStyle where Self == TitleAndIconLabelStyle {
    public static var titleAndIcon: TitleAndIconLabelStyle { TitleAndIconLabelStyle() }
}
extension LabelStyle where Self == TitleOnlyLabelStyle {
    public static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() }
}
extension LabelStyle where Self == IconOnlyLabelStyle {
    public static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() }
}

public struct BorderlessButtonStyle: PrimitiveButtonStyle, PressedButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration, pressed: Bool) -> some View {
        configuration.label
            .foregroundColor(Color(red: 0.2, green: 0.45, blue: 0.85))
            .opacity(pressed ? 0.4 : 1)
    }
}

extension BorderlessButtonStyle {
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View { makeBody(configuration: configuration, pressed: false) }
    func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration, pressed: pressed)) }
}

extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
    public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() }
}


public struct BorderlessButtonMenuStyle: MenuStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        _ModifiedView(content: AnyView(Menu(configuration)), modifier: EnvironmentModifier(apply: { $0.menuBorderless = true }, onUpdate: nil))
    }
}

public struct ButtonMenuStyle: MenuStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { Menu(configuration) }
}

public typealias BorderedButtonMenuStyle = ButtonMenuStyle

extension MenuStyle where Self == DefaultMenuStyle {
    public static var automatic: DefaultMenuStyle { DefaultMenuStyle() }
}
extension MenuStyle where Self == BorderlessButtonMenuStyle {
    public static var borderlessButton: BorderlessButtonMenuStyle { BorderlessButtonMenuStyle() }
}
extension MenuStyle where Self == BorderedButtonMenuStyle {
    public static var borderedButton: BorderedButtonMenuStyle { BorderedButtonMenuStyle() }
}

extension MenuStyle where Self == ButtonMenuStyle {
    public static var button: ButtonMenuStyle { ButtonMenuStyle() }
}

extension Image {
    public enum Interpolation: Hashable { case none, low, medium, high }
    public func interpolation(_ interpolation: Interpolation) -> Image {
        var copy = self
        copy.nearest = interpolation == .none
        return copy
    }
    public func antialiased(_ isAntialiased: Bool) -> Image { self.interpolation(isAntialiased ? .medium : .none) }
}

public struct AnyShapeStyle: ShapeStyle {
    let base: any ShapeStyle
    public init<S: ShapeStyle>(_ style: S) { base = style }
    public var _uiColor: UIColor? { base._uiColor }
}

public struct HierarchicalShapeStyle: ShapeStyle {
    let level: Int
    public static let primary = HierarchicalShapeStyle(level: 0)
    public static let secondary = HierarchicalShapeStyle(level: 1)
    public static let tertiary = HierarchicalShapeStyle(level: 2)
    public static let quaternary = HierarchicalShapeStyle(level: 3)
    public static let quinary = HierarchicalShapeStyle(level: 4)
    public var _uiColor: UIColor? { UIColor(white: 0, alpha: [1, 0.55, 0.3, 0.18, 0.1][level]) }
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .primary }
    public static var secondary: HierarchicalShapeStyle { .secondary }
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
    public static var quaternary: HierarchicalShapeStyle { .quaternary }
}

public struct SelectionShapeStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1) }
}

public struct TintShapeStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1) }
}

extension ShapeStyle where Self == SelectionShapeStyle {
    public static var selection: SelectionShapeStyle { SelectionShapeStyle() }
}
extension ShapeStyle where Self == TintShapeStyle {
    public static var tint: TintShapeStyle { TintShapeStyle() }
}

public struct Material: ShapeStyle {
    let alpha: CGFloat
    public static let ultraThinMaterial = Material(alpha: 0.35)
    public static let thinMaterial = Material(alpha: 0.5)
    public static let regularMaterial = Material(alpha: 0.65)
    public static let thickMaterial = Material(alpha: 0.8)
    public static let ultraThickMaterial = Material(alpha: 0.9)
    public static let bar = Material(alpha: 0.85)
    public var _uiColor: UIColor? {
        _Unsupported.note("Material", "iOS 6 has no live blur; a translucent fill of the same tone is drawn instead")
        return UIColor(white: 0.97, alpha: alpha)
    }
}

extension ShapeStyle where Self == Material {
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    public static var thinMaterial: Material { .thinMaterial }
    public static var regularMaterial: Material { .regularMaterial }
    public static var thickMaterial: Material { .thickMaterial }
    public static var ultraThickMaterial: Material { .ultraThickMaterial }
    public static var bar: Material { .bar }
}

@propertyWrapper
public struct SceneStorage<Value>: DynamicProperty, DynamicPropertyInstaller {
    var inner: AppStorage<Value>
    public var wrappedValue: Value {
        get { inner.wrappedValue }
        nonmutating set { inner.wrappedValue = newValue }
    }
    public var projectedValue: Binding<Value> { inner.projectedValue }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        AppStorage<Value>.install(pointer, node, key)
    }
}

extension SceneStorage {
    public init(wrappedValue: Value, _ key: String) where Value == Bool { inner = AppStorage(wrappedValue: wrappedValue, "scene." + key) }
    public init(wrappedValue: Value, _ key: String) where Value == Int { inner = AppStorage(wrappedValue: wrappedValue, "scene." + key) }
    public init(wrappedValue: Value, _ key: String) where Value == Double { inner = AppStorage(wrappedValue: wrappedValue, "scene." + key) }
    public init(wrappedValue: Value, _ key: String) where Value == String { inner = AppStorage(wrappedValue: wrappedValue, "scene." + key) }
}

public struct UIHostingControllerSizingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let preferredContentSize = UIHostingControllerSizingOptions(rawValue: 1)
    public static let intrinsicContentSize = UIHostingControllerSizingOptions(rawValue: 2)
}

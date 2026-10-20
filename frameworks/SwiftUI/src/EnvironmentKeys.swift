import UIKit
import CoreGraphics

public enum ColorScheme: CaseIterable { case light, dark }
public enum LayoutDirection: CaseIterable { case leftToRight, rightToLeft }
public enum ScenePhase: Comparable { case background, inactive, active }
public enum ControlSize: CaseIterable { case mini, small, regular, large }
public enum ContentSizeCategory: CaseIterable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
}
public enum UserInterfaceSizeClass { case compact, regular }

struct ColorSchemeKey: EnvironmentKey { static var defaultValue: ColorScheme { .light } }
struct LayoutDirectionKey: EnvironmentKey { static var defaultValue: LayoutDirection { .leftToRight } }
struct IsEnabledKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct LocaleKey: EnvironmentKey { static var defaultValue: Locale { .current } }
struct CalendarKey: EnvironmentKey { static var defaultValue: Calendar { .current } }
struct TimeZoneKey: EnvironmentKey { static var defaultValue: TimeZone { .current } }
struct ScenePhaseKey: EnvironmentKey { static var defaultValue: ScenePhase { AppRuntime.scenePhase } }
struct SizeCategoryKey: EnvironmentKey { static var defaultValue: ContentSizeCategory { .large } }
struct ControlSizeKey: EnvironmentKey { static var defaultValue: ControlSize { .regular } }
struct HorizontalSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { nil } }
struct VerticalSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { nil } }
struct DisplayScaleKey: EnvironmentKey { static var defaultValue: CGFloat { UIScreen.main.scale } }
struct IsPressedKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct OpenURLKey: EnvironmentKey { static var defaultValue: OpenURLAction { OpenURLAction() } }
struct SymbolRenderingModeKey: EnvironmentKey { static var defaultValue: SymbolRenderingMode { .monochrome } }
struct VerticalScrollIndicatorKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct HorizontalScrollIndicatorKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct VerticalScrollBounceKey: EnvironmentKey { static var defaultValue: ScrollBounceBehavior { .automatic } }
struct HorizontalScrollBounceKey: EnvironmentKey { static var defaultValue: ScrollBounceBehavior { .automatic } }
struct TextContentTypeKey: EnvironmentKey { static var defaultValue: UITextContentType? { nil } }
struct IsFocusedKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct IsHoverEffectEnabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct ListRowSpacingKey: EnvironmentKey { static var defaultValue: CGFloat { 0 } }
struct ListSectionSpacingKey: EnvironmentKey { static var defaultValue: CGFloat { 0 } }

public struct OpenURLAction {
    public struct Result {
        enum Kind { case handled, discarded, system(URL?) }
        let kind: Kind
        public static let handled = Result(kind: .handled)
        public static let discarded = Result(kind: .discarded)
        public static let systemAction = Result(kind: .system(nil))
        public static func systemAction(_ url: URL) -> Result { Result(kind: .system(url)) }
    }
    let handler: ((URL) -> Result)?
    public init(handler: @escaping (URL) -> Result) { self.handler = handler }
    init() { handler = nil }
    public func callAsFunction(_ url: URL) { callAsFunction(url) { _ in } }
    public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {
        let result = handler?(url) ?? .systemAction
        switch result.kind {
        case .handled: completion(true)
        case .discarded: completion(false)
        case .system(let other): completion(UIApplication.shared.openURL(other ?? url))
        }
    }
}

public struct DismissAction {
    let action: () -> Void
    public func callAsFunction() { action() }
}

struct DismissKey: EnvironmentKey { static var defaultValue: DismissAction { DismissAction(action: {}) } }

extension EnvironmentValues {
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
    public var layoutDirection: LayoutDirection {
        get { self[LayoutDirectionKey.self] }
        set { self[LayoutDirectionKey.self] = newValue }
    }
    public var isEnabled: Bool {
        get { self[IsEnabledKey.self] }
        set { self[IsEnabledKey.self] = newValue }
    }
    public var tintColor: Color? {
        get { tint.map(Color.init(uiColor:)) }
        set { tint = newValue?.uiColor }
    }
    public var accentColor: Color? {
        get { tintColor }
        set { tintColor = newValue }
    }
    public var symbolRenderingMode: SymbolRenderingMode {
        get { self[SymbolRenderingModeKey.self] }
        set { self[SymbolRenderingModeKey.self] = newValue }
    }
    public var verticalScrollIndicatorVisibility: Visibility {
        get { self[VerticalScrollIndicatorKey.self] }
        set { self[VerticalScrollIndicatorKey.self] = newValue }
    }
    public var horizontalScrollIndicatorVisibility: Visibility {
        get { self[HorizontalScrollIndicatorKey.self] }
        set { self[HorizontalScrollIndicatorKey.self] = newValue }
    }
    public var verticalScrollBounceBehavior: ScrollBounceBehavior {
        get { self[VerticalScrollBounceKey.self] }
        set { self[VerticalScrollBounceKey.self] = newValue }
    }
    public var horizontalScrollBounceBehavior: ScrollBounceBehavior {
        get { self[HorizontalScrollBounceKey.self] }
        set { self[HorizontalScrollBounceKey.self] = newValue }
    }
    public var textContentType: UITextContentType? {
        get { self[TextContentTypeKey.self] }
        set { self[TextContentTypeKey.self] = newValue }
    }
    public var isFocused: Bool {
        get { self[IsFocusedKey.self] }
        set { self[IsFocusedKey.self] = newValue }
    }
    public var isHoverEffectEnabled: Bool {
        get { self[IsHoverEffectEnabledKey.self] }
        set { self[IsHoverEffectEnabledKey.self] = newValue }
    }
    public var listRowSpacing: CGFloat {
        get { self[ListRowSpacingKey.self] }
        set { self[ListRowSpacingKey.self] = newValue }
    }
    public var listSectionSpacing: CGFloat {
        get { self[ListSectionSpacingKey.self] }
        set { self[ListSectionSpacingKey.self] = newValue }
    }
    public var isPressed: Bool {
        get { self[IsPressedKey.self] }
        set { self[IsPressedKey.self] = newValue }
    }
    public var locale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
    public var calendar: Calendar {
        get { self[CalendarKey.self] }
        set { self[CalendarKey.self] = newValue }
    }
    public var timeZone: TimeZone {
        get { self[TimeZoneKey.self] }
        set { self[TimeZoneKey.self] = newValue }
    }
    public var scenePhase: ScenePhase {
        get { self[ScenePhaseKey.self] }
        set { self[ScenePhaseKey.self] = newValue }
    }
    public var sizeCategory: ContentSizeCategory {
        get { self[SizeCategoryKey.self] }
        set { self[SizeCategoryKey.self] = newValue }
    }
    public var controlSize: ControlSize {
        get { self[ControlSizeKey.self] }
        set { self[ControlSizeKey.self] = newValue }
    }
    public var horizontalSizeClass: UserInterfaceSizeClass? {
        get { self[HorizontalSizeClassKey.self] }
        set { self[HorizontalSizeClassKey.self] = newValue }
    }
    public var verticalSizeClass: UserInterfaceSizeClass? {
        get { self[VerticalSizeClassKey.self] }
        set { self[VerticalSizeClassKey.self] = newValue }
    }
    public var displayScale: CGFloat {
        get { self[DisplayScaleKey.self] }
        set { self[DisplayScaleKey.self] = newValue }
    }
    public var openURL: OpenURLAction {
        get { self[OpenURLKey.self] }
        set { self[OpenURLKey.self] = newValue }
    }
    public var dismiss: DismissAction {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}

public struct Link<Label: View>: View {
    let destination: URL
    let label: Label
    @Environment(\.openURL) var openURL
    public init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination; self.label = label()
    }
    public var body: some View {
        let open = openURL, url = destination
        return Button(action: { open(url) }) { label }
    }
}

extension Link where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: URL) {
        self.init(destination: destination) { Text(titleKey) }
    }
}

@propertyWrapper
public struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty, DynamicPropertyInstaller {
    let value: Value
    public init(wrappedValue: Value, relativeTo textStyle: Font = .body) { value = wrappedValue }
    public var wrappedValue: Value { value }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {}
}

final class NamespaceStorage {
    nonisolated(unsafe) static var next = 0
    let id: Int
    init() { NamespaceStorage.next += 1; id = NamespaceStorage.next }
}

@propertyWrapper
public struct Namespace: DynamicProperty, DynamicPropertyInstaller {
    public struct ID: Hashable {
        let value: Int
    }
    var storage: NamespaceStorage?
    public var wrappedValue: ID { ID(value: storage?.id ?? 0) }
    public init() {}
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: Namespace.self)
        if let s = node.storages[key] as? NamespaceStorage {
            p.pointee.storage = s
        } else {
            let s = NamespaceStorage()
            node.storages[key] = s
            p.pointee.storage = s
        }
    }
}

struct IsScrollEnabledKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct DefaultMinListRowHeightKey: EnvironmentKey { static var defaultValue: CGFloat { 44 } }
struct DefaultMinListHeaderHeightKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }

extension EnvironmentValues {
    public var lineSpacing: CGFloat {
        get { lineSpacingOverride ?? 0 }
        set { lineSpacingOverride = newValue }
    }
    public var minimumScaleFactor: CGFloat {
        get { scaleFactorOverride ?? 1 }
        set { scaleFactorOverride = newValue == 1 ? nil : newValue }
    }
    public var truncationMode: Text.TruncationMode {
        get {
            switch truncation {
            case .byTruncatingHead?: return .head
            case .byTruncatingMiddle?: return .middle
            default: return .tail
            }
        }
        set {
            switch newValue {
            case .head: truncation = .byTruncatingHead
            case .middle: truncation = .byTruncatingMiddle
            case .tail: truncation = .byTruncatingTail
            }
        }
    }
    public var autocorrectionDisabled: Bool {
        get { input.autocorrection == .no }
        set { input.autocorrection = newValue ? UITextAutocorrectionType.no : UITextAutocorrectionType.yes }
    }
    public var disableAutocorrection: Bool? {
        get { input.autocorrection.map { $0 == .no } }
        set { input.autocorrection = newValue.map { $0 ? UITextAutocorrectionType.no : UITextAutocorrectionType.yes } }
    }
    public var pixelLength: CGFloat { 1 / UIScreen.main.scale }
    public var isPresented: Bool { presentationMode.wrappedValue.isPresented }
    public var undoManager: UndoManager? { host?.undoManager }
    public var isScrollEnabled: Bool {
        get { self[IsScrollEnabledKey.self] }
        set { self[IsScrollEnabledKey.self] = newValue }
    }
    public var defaultMinListRowHeight: CGFloat {
        get { self[DefaultMinListRowHeightKey.self] }
        set { self[DefaultMinListRowHeightKey.self] = newValue }
    }
    public var defaultMinListHeaderHeight: CGFloat? {
        get { self[DefaultMinListHeaderHeightKey.self] }
        set { self[DefaultMinListHeaderHeightKey.self] = newValue }
    }
    public var headerProminence: Prominence {
        get { headerProminent ? .increased : .standard }
        set { headerProminent = newValue == .increased }
    }
    public var dynamicTypeSize: DynamicTypeSize {
        get { self[DynamicTypeSizeKey.self] }
        set { self[DynamicTypeSizeKey.self] = newValue }
    }
    public var accessibilityVoiceOverEnabled: Bool { UIAccessibility.isVoiceOverRunning }
    public var accessibilityEnabled: Bool { UIAccessibility.isVoiceOverRunning }
    public var accessibilityInvertColors: Bool { UIAccessibility.isInvertColorsEnabled }
    public var accessibilityReduceMotion: Bool { false }
    public var accessibilityReduceTransparency: Bool { false }
    public var accessibilityDifferentiateWithoutColor: Bool { false }
    public var accessibilityShowButtonShapes: Bool { false }
    public var accessibilitySwitchControlEnabled: Bool { false }
    public var accessibilityQuickActionsEnabled: Bool { false }
    public var accessibilityLargeContentViewerEnabled: Bool { false }
    public var isLuminanceReduced: Bool { false }
    public var supportsMultipleWindows: Bool { false }
}

struct DynamicTypeSizeKey: EnvironmentKey { static var defaultValue: DynamicTypeSize { .large } }

extension EnvironmentValues: CustomStringConvertible {
    public var description: String { "environment(controlSize: \(controlSize), colorScheme: \(colorScheme), isEnabled: \(isEnabled))" }
}

struct SubmitBlocksReturnKey: EnvironmentKey { static var defaultValue: Bool { false } }

struct PresentationBackgroundKey: EnvironmentKey { static var defaultValue: UIColor? { nil } }

extension EnvironmentValues {
    var presentationBackground: UIColor? {
        get { self[PresentationBackgroundKey.self] }
        set { self[PresentationBackgroundKey.self] = newValue }
    }
}

extension EnvironmentValues {
    var submitBlocksReturn: Bool {
        get { self[SubmitBlocksReturnKey.self] }
        set { self[SubmitBlocksReturnKey.self] = newValue }
    }
}

extension ContentSizeCategory {
    var scale: CGFloat {
        switch self {
        case .extraSmall: return 0.82
        case .small: return 0.88
        case .medium: return 0.94
        case .large: return 1
        case .extraLarge: return 1.12
        case .extraExtraLarge: return 1.23
        case .extraExtraExtraLarge: return 1.35
        }
    }
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        }
    }
}

extension DynamicTypeSize {
    var scale: CGFloat { ContentSizeCategory(self).scale }
    init(_ category: ContentSizeCategory) {
        switch category {
        case .extraSmall: self = .xSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .xLarge
        case .extraExtraLarge: self = .xxLarge
        case .extraExtraExtraLarge: self = .xxxLarge
        }
    }
}

struct DynamicTypeSizeRangeKey: EnvironmentKey { static var defaultValue: ClosedRange<DynamicTypeSize>? { nil } }

extension EnvironmentValues {
    var dynamicTypeSizeRange: ClosedRange<DynamicTypeSize>? {
        get { self[DynamicTypeSizeRangeKey.self] }
        set { self[DynamicTypeSizeRangeKey.self] = newValue }
    }
    func scaledSize(_ size: CGFloat) -> CGFloat { size * textSizeFactor }

    var textSizeFactor: CGFloat {
        let cases = DynamicTypeSize.allCases
        let here = cases.firstIndex(of: DynamicTypeSize(sizeCategory))!
        guard let range = dynamicTypeSizeRange else { return cases[here].scale }
        let low = cases.firstIndex(of: range.lowerBound)!
        let high = max(low, cases.firstIndex(of: range.upperBound)!)
        return cases[min(max(here, low), high)].scale
    }
    func scaled(_ font: UIFont) -> UIFont {
        let size = scaledSize(font.pointSize)
        return size == font.pointSize ? font : font.withSize(size)
    }
}

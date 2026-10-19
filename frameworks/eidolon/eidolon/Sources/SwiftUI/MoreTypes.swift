import UIKit

@propertyWrapper
public struct AccessibilityFocusState<Value: Hashable>: DynamicProperty, DynamicPropertyInstaller {
    let initial: Value
    var storage: StateStorage<Value>?
    public init() where Value == Bool { initial = false }
    public init<T: Hashable>() where Value == T? { initial = nil }
    public var wrappedValue: Value {
        get { storage?.value ?? initial }
        nonmutating set { storage?.value = newValue }
    }
    public struct Binding {
        let get: () -> Value
        let set: (Value) -> Void
        public var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
        public var projectedValue: Binding { self }
    }
    public var projectedValue: Binding {
        let storage = self.storage, initial = self.initial
        return Binding(get: { storage?.value ?? initial }, set: { storage?.value = $0 })
    }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: AccessibilityFocusState<Value>.self)
        if let s = node.storages[key] as? StateStorage<Value> { p.pointee.storage = s; return }
        let s = StateStorage(p.pointee.initial)
        s.node = node
        node.storages[key] = s
        p.pointee.storage = s
    }
}


public struct ColumnNavigationViewStyle: NavigationViewStyle { public init() {} }
extension NavigationViewStyle where Self == ColumnNavigationViewStyle { public static var columns: ColumnNavigationViewStyle { ColumnNavigationViewStyle() } }
extension NavigationViewStyle where Self == StackNavigationViewStyle { public static var stack: StackNavigationViewStyle { StackNavigationViewStyle() } }
extension NavigationViewStyle where Self == DefaultNavigationViewStyle { public static var automatic: DefaultNavigationViewStyle { DefaultNavigationViewStyle() } }

public protocol DynamicTableRowContent: TableRowContent {
    associatedtype Data: Collection
    var data: Data { get }
}
public struct TableHeaderRowContent<Value: Identifiable, Content: TableRowContent>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    let content: Content
    public var _rows: [Value] { content._rows.compactMap { $0 as? Value } }
}
public struct ItemProviderTableRowModifier {}
public struct OnInsertTableRowModifier {}

public protocol FocusedValueKey { associatedtype Value }

@propertyWrapper
public struct FocusedValue<Value>: DynamicProperty {
    public init(_ keyPath: KeyPath<FocusedValues, Value?>) {}
    public var wrappedValue: Value? { nil }
}

@propertyWrapper
public struct FocusedBinding<Value>: DynamicProperty {
    public init(_ keyPath: KeyPath<FocusedValues, Binding<Value>?>) {}
    public var wrappedValue: Value? { get { nil } nonmutating set {} }
    public var projectedValue: Binding<Value?> { Binding(get: { nil }, set: { _ in }) }
}

@propertyWrapper
public struct FocusedObject<ObjectType: ObservableObject>: DynamicProperty {
    public init() {}
    public var wrappedValue: ObjectType? { nil }
}

public struct DefaultFocusEvaluationPriority: Equatable {
    public static let automatic = DefaultFocusEvaluationPriority()
    public static let userInitiated = DefaultFocusEvaluationPriority()
}

public struct GridLayout: Layout {
    public var alignment: Alignment
    public var horizontalSpacing: CGFloat?
    public var verticalSpacing: CGFloat?
    public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.alignment = alignment; self.horizontalSpacing = horizontalSpacing; self.verticalSpacing = verticalSpacing
    }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        VStackLayout(alignment: alignment.horizontal, spacing: verticalSpacing).sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        VStackLayout(alignment: alignment.horizontal, spacing: verticalSpacing).placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
    }
}

public struct LabeledControlGroupContent<Content: View, Label: View>: View {
    let content: Content
    let label: Label
    public var body: some View { HStack(spacing: 8) { content } }
}

public struct LabeledToolbarItemGroupContent<Content: View, Label: View>: View {
    let content: Content
    let label: Label
    public var body: some View { content }
}

extension Text {
    public struct LineStyle: Hashable {
        public enum Pattern: Hashable { case solid, dot, dash, dashDot, dashDotDot }
        public let pattern: Pattern
        public let color: Color?
        public init(pattern: Pattern = .solid, color: Color? = nil) { self.pattern = pattern; self.color = color }
        public static let single = LineStyle()
        public static func == (a: Self, b: Self) -> Bool { a.pattern == b.pattern }
        public func hash(into hasher: inout Hasher) { hasher.combine(pattern) }
    }
    public func underline(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text {
        if pattern != .solid { _Unsupported.note("Text.LineStyle.Pattern", "iOS 6 draws only solid underlines and strikethroughs") }
        return underline(isActive, color: color)
    }
    public func strikethrough(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text {
        if pattern != .solid { _Unsupported.note("Text.LineStyle.Pattern", "iOS 6 draws only solid underlines and strikethroughs") }
        return strikethrough(isActive, color: color)
    }
}

public struct ListItemTint {
    let color: Color?
    public static func fixed(_ tint: Color) -> ListItemTint { ListItemTint(color: tint) }
    public static func preferred(_ tint: Color) -> ListItemTint { ListItemTint(color: tint) }
    public static let monochrome = ListItemTint(color: Color(white: 0.4))
}

extension View {
    public func listItemTint(_ tint: ListItemTint?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.tint = tint?.color?.uiColor ?? $0.tint }, onUpdate: nil))
    }
}

public struct RenameAction {
    public func callAsFunction() {}
}

public struct RenameButton<Label: View>: View {
    public var body: some View {
        ignored(EmptyView(), "RenameButton", "a rename is done on a name in a text field, which this release has; what a row offers as an affordance to rename it is iOS 15")
    }
}
extension RenameButton where Label == SwiftUI.Label<Text, Image> {
    public init() {}
}

public protocol TextSelectability { static var allowsSelection: Bool { get } }
public struct EnabledTextSelectability: TextSelectability { public static var allowsSelection: Bool { true } }
public struct DisabledTextSelectability: TextSelectability { public static var allowsSelection: Bool { false } }
extension TextSelectability where Self == EnabledTextSelectability { public static var enabled: EnabledTextSelectability { EnabledTextSelectability() } }
extension TextSelectability where Self == DisabledTextSelectability { public static var disabled: DisabledTextSelectability { DisabledTextSelectability() } }

extension View {
    public func textSelection<S: TextSelectability>(_ selectability: S) -> some View {
        S.allowsSelection ? ignored(self, "textSelection", "a selectable label is a UITextView of this release, whose own UITextView does not answer isSelectable: the selection of a text view here is what UITextView does with its own gestures, and a view that is not a text view has none") : self
    }
}

public struct ToolbarCustomizationBehavior: Equatable {
    public static let `default` = ToolbarCustomizationBehavior()
    public static let reorderable = ToolbarCustomizationBehavior()
    public static let disabled = ToolbarCustomizationBehavior()
}
public struct ToolbarCustomizationOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alwaysAvailable = ToolbarCustomizationOptions(rawValue: 1)
}
public struct ToolbarTitleMenu<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { EmptyView() }
}

public struct ViewSpacing {
    public static let zero = ViewSpacing()
    public init() {}
    public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat { 8 }
    public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) {}
    public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing { self }
}

extension LayoutSubview {
    public var spacing: ViewSpacing { ViewSpacing() }
}

public struct LayoutProperties {
    public init() {}
    public var stackOrientation: Axis?
}

public enum ShapeRole: Equatable { case fill, stroke, separator }
extension Shape {
    public static var role: ShapeRole { .fill }
}

public struct PreferredColorSchemeKey: PreferenceKey {
    public static var defaultValue: ColorScheme? { nil }
    public static func reduce(value: inout ColorScheme?, nextValue: () -> ColorScheme?) { value = value ?? nextValue() }
}

public protocol CustomPresentationDetent {
    static func height(in context: Self.Context) -> CGFloat?
}
extension CustomPresentationDetent {
    public typealias Context = PresentationDetent.Context
}
extension PresentationDetent {
    public struct Context {
        public let maxDetentValue: CGFloat
    }
}

/// A detent whose height the app decides, from the context it is given. iOS 6's modal screens have no
/// detents to size -- they are always the whole screen -- so the height an app computes has nothing to
/// measure against and `PresentationDetent.Context.maxDetentValue` is the screen: the context is handed
/// the largest detent the release would allow, which here is the screen itself.
extension PresentationDetent.Context {
    public static var maximum: CGFloat { max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height) }
}

public protocol DropDelegate {
    func validateDrop(info: DropInfo) -> Bool
    func performDrop(info: DropInfo) -> Bool
    func dropEntered(info: DropInfo)
    func dropUpdated(info: DropInfo) -> DropProposal?
    func dropExited(info: DropInfo)
}
extension DropDelegate {
    public func validateDrop(info: DropInfo) -> Bool { true }
    public func dropEntered(info: DropInfo) {}
    public func dropUpdated(info: DropInfo) -> DropProposal? { nil }
    public func dropExited(info: DropInfo) {}
}
public struct DropInfo {
    public var location: CGPoint { .zero }
    public func hasItemsConforming(to contentTypes: [String]) -> Bool { false }
}
public enum DropOperation { case cancel, forbidden, copy, move }
public struct DropProposal {
    public let operation: DropOperation
    public init(operation: DropOperation) { self.operation = operation }
}
extension View {
    public func onDrop(of supportedContentTypes: [String], delegate: DropDelegate) -> some View {
        ignored(self, "onDrop", "a drag of this release is a gesture, not a session: UIDragInteraction and UIDropInteraction are iOS 11, and the release hands an app no drag session and no preview to carry a payload in — a table of rows is moved with .onMove, and a drag of one's own is a DragGesture")
    }
}

public struct AccessibilityCustomContentKey {
    public init(_ label: Text, id: String) {}
    public init(_ labelKey: LocalizedStringKey) {}
}
public struct AccessibilityTechnologies: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let voiceOver = AccessibilityTechnologies(rawValue: 1)
    public static let switchControl = AccessibilityTechnologies(rawValue: 2)
}
public struct AccessibilityAttachmentModifier: ViewModifier {
    public func body(content: Content) -> some View { content }
}
public protocol AccessibilityRotorContent {}
public struct AccessibilityRotorEntry<ID: Hashable>: AccessibilityRotorContent {
    public init(_ label: Text, id: ID) {}
}
@resultBuilder
public struct AccessibilityRotorContentBuilder {
    public static func buildBlock<C: AccessibilityRotorContent>(_ content: C...) -> [C] { content }
}
public protocol AXChartDescriptorRepresentable {}

extension Font {
    public enum Leading: Hashable { case standard, tight, loose }
    public func leading(_ leading: Leading) -> Font {
        if leading != .standard { _Unsupported.note("Font.leading", "UIFont of iOS 6 has no leading variants; use lineSpacing") }
        return self
    }
    public struct Width: Hashable {
        public let value: CGFloat
        public init(_ value: CGFloat) { self.value = value }
        public static let compressed = Width(-0.3), condensed = Width(-0.2), standard = Width(0), expanded = Width(0.2)
    }
    public func width(_ width: Width) -> Font {
        if width != .standard { _Unsupported.note("fontWidth", "the system font of this release has no width axis: Helvetica Neue carries four faces on iOS 6.1.3 — Regular, Italic, Bold, Bold Italic — and Avenir Next Condensed is a family of its own, so a width of it would be a different typeface") }
        return self
    }
}

extension Gradient {
    public enum ColorSpace: Hashable { case device, perceptual }
    public func colorSpace(_ space: ColorSpace) -> AnyGradient { AnyGradient(self) }
}

extension Image {
    public enum Orientation: UInt8, CaseIterable, Hashable { case up, upMirrored, down, downMirrored, left, leftMirrored, right, rightMirrored }
    public init(_ cgImage: CGImage, scale: CGFloat, orientation: Orientation = .up, label: Text) {
        let mapped: UIImage.Orientation
        switch orientation {
        case .up: mapped = .up
        case .upMirrored: mapped = .upMirrored
        case .down: mapped = .down
        case .downMirrored: mapped = .downMirrored
        case .left: mapped = .left
        case .leftMirrored: mapped = .leftMirrored
        case .right: mapped = .right
        case .rightMirrored: mapped = .rightMirrored
        }
        self.init(uiImage: UIImage(cgImage: cgImage, scale: scale, orientation: mapped))
        accessibilityLabelText = label.content.isEmpty ? nil : label.content
    }
}

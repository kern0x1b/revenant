import UIKit

extension Axis: CaseIterable, RawRepresentable, CustomStringConvertible {
    public init?(rawValue: Int8) {
        switch rawValue { case 0: self = .horizontal; case 1: self = .vertical; default: return nil }
    }
    public var rawValue: Int8 { switch self { case .horizontal: return 0; case .vertical: return 1 } }
    public var description: String { switch self { case .horizontal: return "horizontal"; case .vertical: return "vertical" } }
    public static var allCases: [Axis] { [.horizontal, .vertical] }
}

extension Alignment {
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let centerFirstTextBaseline = Alignment(horizontal: .center, vertical: .firstTextBaseline)
    public static let centerLastTextBaseline = Alignment(horizontal: .center, vertical: .lastTextBaseline)
    public static let leadingFirstTextBaseline = Alignment(horizontal: .leading, vertical: .firstTextBaseline)
    public static let leadingLastTextBaseline = Alignment(horizontal: .leading, vertical: .lastTextBaseline)
    public static let trailingFirstTextBaseline = Alignment(horizontal: .trailing, vertical: .firstTextBaseline)
    public static let trailingLastTextBaseline = Alignment(horizontal: .trailing, vertical: .lastTextBaseline)
}

extension Font {
    public func monospaced() -> Font { Font(uiFont: UIFont(name: "Courier", size: uiFont.pointSize) ?? uiFont) }
    // digits of the system font of iOS 6 already have one width
    public func monospacedDigit() -> Font { self }
    public func lowercaseSmallCaps() -> Font {
        _Unsupported.note("Font.smallCaps", "the fonts of iOS 6 have no small-capital variants; the text keeps its case")
        return self
    }
    public func uppercaseSmallCaps() -> Font { lowercaseSmallCaps() }
    public static func custom(_ name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font { custom(name, size: size) }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { custom(name, size: fixedSize) }
}

extension Picker {
    public init(selection: Binding<SelectionValue>, label: Label, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content, label: { label })
    }
}

extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isActive: Binding<Bool>, @ViewBuilder destination: () -> Destination) {
        self.init(isActive: isActive, destination: destination) { Text(titleKey) }
    }
    public init<S: StringProtocol>(_ title: S, isActive: Binding<Bool>, @ViewBuilder destination: () -> Destination) {
        self.init(isActive: isActive, destination: destination) { Text(title) }
    }
    public init<V: Hashable>(_ titleKey: LocalizedStringKey, tag: V, selection: Binding<V?>, @ViewBuilder destination: () -> Destination) {
        self.init(destination: destination(), tag: tag, selection: selection) { Text(titleKey) }
    }
    public init<S: StringProtocol, V: Hashable>(_ title: S, tag: V, selection: Binding<V?>, @ViewBuilder destination: () -> Destination) {
        self.init(destination: destination(), tag: tag, selection: selection) { Text(title) }
    }
}

extension NavigationLink {
    public init<V: Hashable>(tag: V, selection: Binding<V?>, @ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.init(destination: destination(), tag: tag, selection: selection, label: label)
    }
}


extension Section where Parent == EmptyView, Content: View, Footer: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(header: EmptyView(), content: content(), footer: footer())
    }
}

extension Section where Parent: View, Content: View, Footer: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {
        self.init(header: header(), content: content(), footer: footer())
    }
}

extension Section where Parent == EmptyView, Content: View, Footer: View {
    public init(footer: Footer, @ViewBuilder content: () -> Content) {
        self.init(header: EmptyView(), content: content(), footer: footer)
    }
}

extension GestureState {
    public init(wrappedValue: Value, reset: @escaping (Value, inout Transaction) -> Void) { self.init(wrappedValue: wrappedValue) }
    public init(wrappedValue: Value, resetTransaction: Transaction) { self.init(wrappedValue: wrappedValue) }
    public init(initialValue: Value, reset: @escaping (Value, inout Transaction) -> Void) { self.init(initialValue: initialValue) }
    public init(initialValue: Value, resetTransaction: Transaction) { self.init(initialValue: initialValue) }
}

extension GestureState where Value: ExpressibleByNilLiteral {
    public init(reset: @escaping (Value, inout Transaction) -> Void) { self.init(wrappedValue: nil) }
    public init(resetTransaction: Transaction) { self.init(wrappedValue: nil) }
}

extension Menu {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {
        _Unsupported.note("Menu(primaryAction:)", "a menu opens on a tap on iOS 6, and its primary action is not run")
        self.init(content: content, label: label)
    }
}

extension Menu where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {
        self.init(content: content, label: { Text(titleKey) }, primaryAction: primaryAction)
    }
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {
        self.init(content: content, label: { Text(title) }, primaryAction: primaryAction)
    }
}

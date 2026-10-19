import UIKit
import CoreGraphics

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}

extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= CGFloat(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }
    public var magnitudeSquared: Double { self * self }
}

extension Double: Animatable {
    public var animatableData: Double {
        get { self }
        set { self = newValue }
    }
}

extension Float: Animatable {
    public var animatableData: Double {
        get { Double(self) }
        set { self = Float(newValue) }
    }
}

public struct EmptyAnimatableData: VectorArithmetic {
    public init() {}
    public static let zero = EmptyAnimatableData()
    public static func + (a: EmptyAnimatableData, b: EmptyAnimatableData) -> EmptyAnimatableData { a }
    public static func - (a: EmptyAnimatableData, b: EmptyAnimatableData) -> EmptyAnimatableData { a }
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
}

public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public static var zero: AnimatablePair<First, Second> { AnimatablePair(First.zero, Second.zero) }
    public static func + (a: Self, b: Self) -> Self { AnimatablePair(a.first + b.first, a.second + b.second) }
    public static func - (a: Self, b: Self) -> Self { AnimatablePair(a.first - b.first, a.second - b.second) }
    public mutating func scale(by rhs: Double) {
        first.scale(by: rhs)
        second.scale(by: rhs)
    }
    public var magnitudeSquared: Double { first.magnitudeSquared + second.magnitudeSquared }
}

public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData { get set }
}

extension Animatable where AnimatableData == EmptyAnimatableData {
    public var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set {}
    }
}

public struct LabeledContent<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    @Environment(\.self) var environment
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label()
    }
    public var body: some View {
        let configuration = LabeledContentStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: content))
        return applyStyle(environment, configuration) { AutomaticLabeledContentStyle().makeBody(configuration: configuration) }
    }
}

extension LabeledContent where Label == Text, Content == Text {
    public init<S: StringProtocol>(_ titleKey: LocalizedStringKey, value: S) {
        self.init(content: { Text(value) }, label: { Text(titleKey) })
    }
}

extension LabeledContent where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
}

extension Binding {
    public init?(_ base: Binding<Value?>) {
        guard base.wrappedValue != nil else { return nil }
        self.init(get: { base.wrappedValue! }, set: { base.wrappedValue = $0 })
    }
}

extension Font {
    public enum TextStyle: CaseIterable {
        case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2

        var font: Font {
            switch self {
            case .largeTitle: return .largeTitle
            case .title: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption: return .caption
            case .caption2: return .caption2
            }
        }
    }

    public static func system(_ style: TextStyle, design: Design = .default, weight: Weight? = nil) -> Font {
        var base = style.font
        if let weight { base = base.weight(weight) }
        return design == .default ? base : base.design(design)
    }
}

extension View {
    public func lineSpacing(_ spacing: CGFloat) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.lineSpacingOverride = spacing }, onUpdate: nil))
    }
}

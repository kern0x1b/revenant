import UIKit
import CoreGraphics

// What a field shows and what it does with what is typed: a plain text binding, or a value shown through a Formatter.
struct TextFieldModel {
    var display: () -> String
    var edited: (String) -> Void
    var committed: (String) -> Void
    var tracksBinding: Bool

    init(text: Binding<String>) {
        display = { text.wrappedValue }
        edited = { text.wrappedValue = $0 }
        committed = { _ in }
        tracksBinding = true
    }

    init<V>(value: Binding<V>, formatter: Formatter) {
        display = { formatter.string(for: value.wrappedValue) ?? "" }
        edited = { _ in }
        committed = { typed in
            var object: AnyObject?
            if formatter.getObjectValue(&object, for: typed, errorDescription: nil), let parsed = object as? V { value.wrappedValue = parsed }
        }
        tracksBinding = false
    }
}

protocol TextFieldLike {
    var fieldPlaceholder: String { get }
    var fieldModel: TextFieldModel { get }
    var fieldAccessibilityLabel: String? { get }
    var fieldEditingChanged: ((Bool) -> Void)? { get }
    var fieldCommit: (() -> Void)? { get }
    var fieldMultiline: Bool { get }
}

extension TextFieldLike {
    var fieldAccessibilityLabel: String? { nil }
    var fieldEditingChanged: ((Bool) -> Void)? { nil }
    var fieldCommit: (() -> Void)? { nil }
    var fieldMultiline: Bool { false }
}

public struct TextField<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let model: TextFieldModel
    let prompt: Text?
    let axis: Axis
    var onEditingChanged: ((Bool) -> Void)?
    var onCommit: (() -> Void)?

    init(label: Label, model: TextFieldModel, prompt: Text?, axis: Axis = .horizontal,
         onEditingChanged: ((Bool) -> Void)? = nil, onCommit: (() -> Void)? = nil) {
        self.label = label
        self.model = model
        self.prompt = prompt
        self.axis = axis
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    func makeNode(_ env: EnvironmentValues) -> Node { let n = TextFieldNode(); n.update(self, env); return n }
}

extension TextField: TextFieldLike {
    var fieldPlaceholder: String { prompt?.content ?? findText(label)?.content ?? "" }
    var fieldModel: TextFieldModel { model }
    var fieldAccessibilityLabel: String? { prompt == nil ? nil : findText(label)?.content }
    var fieldEditingChanged: ((Bool) -> Void)? { onEditingChanged }
    var fieldCommit: (() -> Void)? { onCommit }
    var fieldMultiline: Bool { axis == .vertical }
}

extension TextField {
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(label: label(), model: TextFieldModel(text: text), prompt: prompt)
    }
    public init(text: Binding<String>, prompt: Text? = nil, axis: Axis, @ViewBuilder label: () -> Label) {
        self.init(label: label(), model: TextFieldModel(text: text), prompt: prompt, axis: axis)
    }
    public init<V>(value: Binding<V>, formatter: Formatter, prompt: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(label: label(), model: TextFieldModel(value: value, formatter: formatter), prompt: prompt)
    }
}

extension TextField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.init(label: Text(titleKey), model: TextFieldModel(text: text), prompt: prompt)
    }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil, axis: Axis) {
        self.init(label: Text(titleKey), model: TextFieldModel(text: text), prompt: prompt, axis: axis)
    }
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text? = nil) {
        self.init(label: Text(title), model: TextFieldModel(text: text), prompt: prompt)
    }
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text? = nil, axis: Axis) {
        self.init(label: Text(title), model: TextFieldModel(text: text), prompt: prompt, axis: axis)
    }

    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {
        self.init(label: Text(titleKey), model: TextFieldModel(text: text), prompt: nil, onEditingChanged: onEditingChanged, onCommit: onCommit)
    }
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {
        self.init(label: Text(title), model: TextFieldModel(text: text), prompt: nil, onEditingChanged: onEditingChanged, onCommit: onCommit)
    }

    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter) {
        self.init(label: Text(titleKey), model: TextFieldModel(value: value, formatter: formatter), prompt: nil)
    }
    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, onCommit: @escaping () -> Void) {
        self.init(label: Text(titleKey), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onCommit: onCommit)
    }
    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, onEditingChanged: @escaping (Bool) -> Void) {
        self.init(label: Text(titleKey), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onEditingChanged: onEditingChanged)
    }
    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {
        self.init(label: Text(titleKey), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onEditingChanged: onEditingChanged, onCommit: onCommit)
    }
    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, prompt: Text?) {
        self.init(label: Text(titleKey), model: TextFieldModel(value: value, formatter: formatter), prompt: prompt)
    }
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter) {
        self.init(label: Text(title), model: TextFieldModel(value: value, formatter: formatter), prompt: nil)
    }
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, onCommit: @escaping () -> Void) {
        self.init(label: Text(title), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onCommit: onCommit)
    }
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, onEditingChanged: @escaping (Bool) -> Void) {
        self.init(label: Text(title), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onEditingChanged: onEditingChanged)
    }
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {
        self.init(label: Text(title), model: TextFieldModel(value: value, formatter: formatter), prompt: nil, onEditingChanged: onEditingChanged, onCommit: onCommit)
    }
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, prompt: Text?) {
        self.init(label: Text(title), model: TextFieldModel(value: value, formatter: formatter), prompt: prompt)
    }
}

public struct SecureField<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let model: TextFieldModel
    let prompt: Text?
    var onCommit: (() -> Void)?

    init(label: Label, model: TextFieldModel, prompt: Text?, onCommit: (() -> Void)? = nil) {
        self.label = label
        self.model = model
        self.prompt = prompt
        self.onCommit = onCommit
    }

    func makeNode(_ env: EnvironmentValues) -> Node { let n = TextFieldNode(secure: true); n.update(self, env); return n }
}

extension SecureField: TextFieldLike {
    var fieldPlaceholder: String { prompt?.content ?? findText(label)?.content ?? "" }
    var fieldModel: TextFieldModel { model }
    var fieldAccessibilityLabel: String? { prompt == nil ? nil : findText(label)?.content }
    var fieldCommit: (() -> Void)? { onCommit }
}

extension SecureField {
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(label: label(), model: TextFieldModel(text: text), prompt: prompt)
    }
}

extension SecureField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.init(label: Text(titleKey), model: TextFieldModel(text: text), prompt: prompt)
    }
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text? = nil) {
        self.init(label: Text(title), model: TextFieldModel(text: text), prompt: prompt)
    }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.init(label: Text(titleKey), model: TextFieldModel(text: text), prompt: nil, onCommit: onCommit)
    }
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.init(label: Text(title), model: TextFieldModel(text: text), prompt: nil, onCommit: onCommit)
    }
}

final class TextFieldNode: LayoutNode {
    let target = ControlTarget()
    let submitTarget = ControlTarget()
    let commitTarget = ControlTarget()
    let beginTarget = ControlTarget()
    let endTarget = ControlTarget()
    var model = TextFieldModel(text: .constant(""))
    var onCommit: (() -> Void)?
    var onEditingChanged: ((Bool) -> Void)?
    var installed = false
    var field: UITextField { uiView as! UITextField }

    init(secure: Bool = false) {
        let f = UITextField()
        f.borderStyle = .roundedRect
        f.isSecureTextEntry = secure
        super.init(view: f)
        f.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .editingChanged)
        f.addTarget(endTarget, action: #selector(ControlTarget.fire), for: .editingDidEnd)
        f.addTarget(beginTarget, action: #selector(ControlTarget.fire), for: .editingDidBegin)
        f.addTarget(commitTarget, action: #selector(ControlTarget.fire), for: .editingDidEndOnExit)
        target.valueChanged = { [weak self] control in self?.model.edited((control as! UITextField).text ?? "") }
        endTarget.action = { [weak self] in
            guard let self else { return }
            self.model.committed(self.field.text ?? "")
            if !self.model.tracksBinding { self.field.text = self.model.display() }
            self.onEditingChanged?(false)
        }
        beginTarget.action = { [weak self] in self?.onEditingChanged?(true) }
        commitTarget.action = { [weak self] in self?.onCommit?() }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let t = view as? TextFieldLike else { return }
        model = t.fieldModel
        onCommit = t.fieldCommit
        onEditingChanged = t.fieldEditingChanged
        field.placeholder = t.fieldPlaceholder
        field.accessibilityLabel = t.fieldAccessibilityLabel
        if t.fieldMultiline {
            _Unsupported.note("TextField(axis: .vertical)", "a field of iOS 6 has one line; the text scrolls sideways instead of wrapping")
        }
        if !field.isFirstResponder || model.tracksBinding, field.text != model.display() { field.text = model.display() }
        if let value = env.input.autocapitalization { field.autocapitalizationType = value }
        if let value = env.input.autocorrection { field.autocorrectionType = value }
        if let value = env.input.keyboard { field.keyboardType = value }
        if let value = env.input.returnKey { field.returnKeyType = value }
        if let submit = env.input.onSubmit {
            submitTarget.action = submit
            if !installed {
                installed = true
                field.addTarget(submitTarget, action: #selector(ControlTarget.fire), for: .editingDidEndOnExit)
            }
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 200, height: 31) }
}

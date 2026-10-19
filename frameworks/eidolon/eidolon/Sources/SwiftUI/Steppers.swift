import UIKit
import CoreGraphics

protocol StepperLike {
    var stepperLabel: any View { get }
    var stepperIncrement: (() -> Void)? { get }
    var stepperDecrement: (() -> Void)? { get }
    var stepperEditing: (Bool) -> Void { get }
}

// Steps a value in whole strides inside optional bounds, the way Stepper(value:in:step:) does.
func stepping<V: Strideable>(_ value: Binding<V>, in bounds: ClosedRange<V>?, by step: V.Stride) -> (increment: () -> Void, decrement: () -> Void) {
    ({
        let next = value.wrappedValue.advanced(by: step)
        if bounds == nil || next <= bounds!.upperBound { value.wrappedValue = next }
    }, {
        let next = value.wrappedValue.advanced(by: -step)
        if bounds == nil || next >= bounds!.lowerBound { value.wrappedValue = next }
    })
}

public struct Stepper<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let onIncrement: (() -> Void)?
    let onDecrement: (() -> Void)?
    let onEditingChanged: (Bool) -> Void

    init(label: Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void) {
        self.label = label
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onEditingChanged = onEditingChanged
    }

    func makeNode(_ env: EnvironmentValues) -> Node { let n = StepperNode(); n.update(self, env); return n }
}

extension Stepper: StepperLike {
    var stepperLabel: any View { label }
    var stepperIncrement: (() -> Void)? { onIncrement }
    var stepperDecrement: (() -> Void)? { onDecrement }
    var stepperEditing: (Bool) -> Void { onEditingChanged }
}

extension Stepper {
    @_disfavoredOverload
    public init(onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) {
        self.init(label: label(), onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }
    public init(@ViewBuilder label: () -> Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(label: label(), onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }

    public init<V: Strideable>(value: Binding<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: nil, by: step)
        self.init(label: label(), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    public init<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: bounds, by: step)
        self.init(label: label(), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload
    public init<V: Strideable>(value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) {
        let move = stepping(value, in: nil, by: step)
        self.init(label: label(), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload
    public init<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) {
        let move = stepping(value, in: bounds, by: step)
        self.init(label: label(), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
}

extension Stepper where Label == Text {
    public init(_ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(label: Text(titleKey), onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(label: Text(title), onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: nil, by: step)
        self.init(label: Text(titleKey), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload
    public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: nil, by: step)
        self.init(label: Text(title), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: bounds, by: step)
        self.init(label: Text(titleKey), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload
    public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let move = stepping(value, in: bounds, by: step)
        self.init(label: Text(title), onIncrement: move.increment, onDecrement: move.decrement, onEditingChanged: onEditingChanged)
    }
}

final class StepperNode: ContainerNode {
    let stepper = UIStepper()
    let target = ControlTarget()
    let downTarget = ControlTarget()
    let upTarget = ControlTarget()
    var last: Double = 0
    var editing: (Bool) -> Void = { _ in }

    override init() {
        super.init()
        stepper.minimumValue = -1e9
        stepper.maximumValue = 1e9
        stepper.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
        stepper.addTarget(downTarget, action: #selector(ControlTarget.fire), for: .touchDown)
        stepper.addTarget(upTarget, action: #selector(ControlTarget.fire), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        downTarget.action = { [weak self] in self?.editing(true) }
        upTarget.action = { [weak self] in self?.editing(false) }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let s = view as? StepperLike else { return }
        let up = s.stepperIncrement, down = s.stepperDecrement
        editing = s.stepperEditing
        target.valueChanged = { [weak self] control in
            guard let self else { return }
            let value = (control as! UIStepper).value
            if value > self.last { up?() } else if value < self.last { down?() }
            self.last = value
        }
        content = adopt(reconcile(content, s.stepperLabel, env))
    }

    override func mountContents() { super.mountContents(); uiView.addSubview(stepper) }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let control = stepper.sizeThatFits(.zero)
        let label = children.first?.sizeThatFits(ProposedSize(width: (p.width ?? infinity) - control.width - 8, height: nil)) ?? .zero
        return CGSize(width: p.width ?? (label.width + 8 + control.width), height: max(label.height, control.height))
    }

    override func layoutContents(_ size: CGSize) {
        let control = stepper.sizeThatFits(.zero)
        stepper.frame = CGRect(x: size.width - control.width, y: (size.height - control.height) / 2, width: control.width, height: control.height)
        if let label = children.first {
            let wanted = label.sizeThatFits(ProposedSize(width: size.width - control.width - 8, height: nil))
            label.place(CGRect(x: 0, y: (size.height - wanted.height) / 2, width: wanted.width, height: wanted.height))
        }
    }
}

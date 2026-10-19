import UIKit
import CoreGraphics

// What a slider reads and writes: any floating-point binding, seen as Doubles.
struct SliderModel {
    var get: () -> Double
    var set: (Double) -> Void
    var bounds: ClosedRange<Double>
    var step: Double?
    var editing: (Bool) -> Void

    init<V: BinaryFloatingPoint>(value: Binding<V>, bounds: ClosedRange<V>, step: V.Stride?, editing: @escaping (Bool) -> Void) where V.Stride: BinaryFloatingPoint {
        get = { Double(value.wrappedValue) }
        set = { value.wrappedValue = V($0) }
        self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound)
        self.step = step.map { Double($0) }
        self.editing = editing
    }
}

protocol SliderLike {
    var sliderValue: Double { get }
    var sliderBounds: ClosedRange<Double> { get }
}

public struct Slider<Label: View, ValueLabel: View>: View, SliderLike {
    let model: SliderModel
    let label: Label
    let minimumValueLabel: ValueLabel?
    let maximumValueLabel: ValueLabel?

    init(model: SliderModel, label: Label, minimumValueLabel: ValueLabel?, maximumValueLabel: ValueLabel?) {
        self.model = model
        self.label = label
        self.minimumValueLabel = minimumValueLabel
        self.maximumValueLabel = maximumValueLabel
    }

    var sliderValue: Double { model.get() }
    var sliderBounds: ClosedRange<Double> { model.bounds }

    public var body: some View {
        if let low = minimumValueLabel, let high = maximumValueLabel {
            HStack(spacing: 8) {
                low
                _SliderControl(model: model, label: label)
                high
            }
        } else {
            _SliderControl(model: model, label: label)
        }
    }
}

extension Slider where ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: nil, editing: onEditingChanged), label: label(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: step, editing: onEditingChanged), label: label(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
    @_disfavoredOverload
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: nil, editing: onEditingChanged), label: label(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
    @_disfavoredOverload
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: step, editing: onEditingChanged), label: label(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
}

extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: nil, editing: onEditingChanged), label: EmptyView(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: step, editing: onEditingChanged), label: EmptyView(), minimumValueLabel: nil, maximumValueLabel: nil)
    }
}

extension Slider {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: nil, editing: onEditingChanged), label: label(), minimumValueLabel: minimumValueLabel(), maximumValueLabel: maximumValueLabel())
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: step, editing: onEditingChanged), label: label(), minimumValueLabel: minimumValueLabel(), maximumValueLabel: maximumValueLabel())
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, minimumValueLabel: ValueLabel, maximumValueLabel: ValueLabel, @ViewBuilder label: () -> Label) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: nil, editing: onEditingChanged), label: label(), minimumValueLabel: minimumValueLabel, maximumValueLabel: maximumValueLabel)
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, minimumValueLabel: ValueLabel, maximumValueLabel: ValueLabel, @ViewBuilder label: () -> Label) where V.Stride: BinaryFloatingPoint {
        self.init(model: SliderModel(value: value, bounds: bounds, step: step, editing: onEditingChanged), label: label(), minimumValueLabel: minimumValueLabel, maximumValueLabel: maximumValueLabel)
    }
}

struct _SliderControl<Label: View>: View, PrimitiveView, SliderLike {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let model: SliderModel
    let label: Label
    var sliderValue: Double { model.get() }
    var sliderBounds: ClosedRange<Double> { model.bounds }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = SliderNode(); n.update(self, env); return n }
}

protocol SliderControlLike {
    var controlModel: SliderModel { get }
    var controlLabel: any View { get }
}

extension _SliderControl: SliderControlLike {
    var controlModel: SliderModel { model }
    var controlLabel: any View { label }
}

final class SliderNode: LayoutNode {
    let target = ControlTarget()
    let downTarget = ControlTarget()
    let upTarget = ControlTarget()
    var model: SliderModel?
    var slider: UISlider { uiView as! UISlider }

    init() {
        super.init(view: UISlider())
        slider.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
        slider.addTarget(downTarget, action: #selector(ControlTarget.fire), for: .touchDown)
        slider.addTarget(upTarget, action: #selector(ControlTarget.fire), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        downTarget.action = { [weak self] in self?.model?.editing(true) }
        upTarget.action = { [weak self] in self?.model?.editing(false) }
        target.valueChanged = { [weak self] control in
            guard let self, let model = self.model else { return }
            var value = Double((control as! UISlider).value)
            if let step = model.step, step > 0 {
                value = model.bounds.lowerBound + ((value - model.bounds.lowerBound) / step).rounded() * step
                value = min(max(value, model.bounds.lowerBound), model.bounds.upperBound)
            }
            model.set(value)
        }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let control = view as? SliderControlLike else { return }
        let model = control.controlModel
        self.model = model
        slider.minimumValue = Float(model.bounds.lowerBound)
        slider.maximumValue = Float(model.bounds.upperBound)
        slider.accessibilityLabel = findText(control.controlLabel)?.content
        if abs(Double(slider.value) - model.get()) > 0.0001 { slider.value = Float(model.get()) }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 200, height: 34) }
}

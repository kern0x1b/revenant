import UIKit

public struct DatePickerComponents: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1)
    public static let date = DatePickerComponents(rawValue: 2)
}

public struct DatePicker<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public typealias Components = DatePickerComponents
    public var body: Never { neverBody(Self.self) }
    let selection: Binding<Date>
    let label: Label
    let components: DatePickerComponents
    let minimum: Date?
    let maximum: Date?
    func makeNode(_ env: EnvironmentValues) -> Node { let n = DatePickerNode(); n.update(self, env); return n }

    public init(selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = nil; maximum = nil
    }
    public init(selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = range.lowerBound; maximum = range.upperBound
    }
    public init(selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = range.lowerBound; maximum = nil
    }
    public init(selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = nil; maximum = range.upperBound
    }
}

extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
}

protocol DatePickerLike {
    var pickedDate: Binding<Date> { get }
    var pickedComponents: DatePickerComponents { get }
    var pickedLabel: any View { get }
    var pickedMinimum: Date? { get }
    var pickedMaximum: Date? { get }
}

extension DatePicker: DatePickerLike {
    var pickedDate: Binding<Date> { selection }
    var pickedComponents: DatePickerComponents { components }
    var pickedLabel: any View { label }
    var pickedMinimum: Date? { minimum }
    var pickedMaximum: Date? { maximum }
}

// A date in a field, as a grouped-table cell of iOS 6 shows one: the text right-aligned, grey and
// bordered, and the wheel under it while it is being changed.
struct _DateField: View {
    @Binding var date: Date
    var components: DatePickerComponents

    // the field shows what the picker shows: the time alone, the date alone, or both
    private var style: Text.DateStyle {
        if components == .hourAndMinute { return .time }
        if components.contains(.hourAndMinute) { return .date }
        return .date
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(date, style: style)
                .font(.system(size: 17))
                .foregroundColor(Color(white: 0.35))
                .frame(minWidth: 90, minHeight: 20)
                .background(Color.white)
                .border(Color(white: 0.78), width: 1)
        }
    }
}

// The same field with the two steppers of iOS 6's segmented control beside it, which walk the date by
// one unit of what the picker shows.
struct _DateStepperField: View {
    @Binding var date: Date
    var components: DatePickerComponents

    private var step: TimeInterval {
        if components == .hourAndMinute { return 60 * 60 }
        if components.contains(.hourAndMinute) { return 24 * 60 * 60 }
        return 24 * 60 * 60
    }

    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            _DateField(date: $date, components: components)
            Stepper("", onIncrement: { date = date.addingTimeInterval(step) },
                    onDecrement: { date = date.addingTimeInterval(-step) })
                .labelsHidden()
                .frame(width: 94, height: 22)
        }
    }
}

// iOS 6 has the wheel only, so the label sits above it, as SwiftUI puts it for the wheel style.
final class DatePickerNode: ContainerNode {
    let target = ControlTarget()
    let picker = UIDatePicker()
    var showsLabel = true

    override init() {
        super.init()
        picker.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? DatePickerLike else { return }
        let binding = source.pickedDate
        target.valueChanged = { binding.wrappedValue = ($0 as! UIDatePicker).date }
        if source.pickedComponents == .hourAndMinute {
            picker.datePickerMode = .time
        } else if source.pickedComponents.contains(.hourAndMinute) {
            picker.datePickerMode = .dateAndTime
        } else {
            picker.datePickerMode = .date
        }
        picker.minimumDate = source.pickedMinimum
        picker.maximumDate = source.pickedMaximum
        if abs(picker.date.timeIntervalSince(binding.wrappedValue)) > 1 { picker.date = binding.wrappedValue }
        showsLabel = !env.labelsHidden
        var above: any View = showsLabel ? source.pickedLabel : EmptyView()
        if let styled = env.datePickerBody {
            let configuration = DatePickerStyleConfiguration(label: AnyView(above), selection: binding,
                                                             minimumDate: source.pickedMinimum, maximumDate: source.pickedMaximum,
                                                             components: source.pickedComponents)
            above = styled(configuration)
        }
        content = adopt(reconcile(content, above, env))
    }

    override func mountContents() { super.mountContents(); uiView.addSubview(picker) }

    var labelNode: LayoutNode? { showsLabel ? children.first : nil }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let width = p.width ?? 320
        let label = labelNode?.sizeThatFits(ProposedSize(width: width, height: nil)) ?? .zero
        return CGSize(width: width, height: (label.height > 0 ? label.height + 4 : 0) + 216)
    }

    override func layoutContents(_ size: CGSize) {
        var y: CGFloat = 0
        if let label = labelNode {
            let wanted = label.sizeThatFits(ProposedSize(width: size.width, height: nil))
            label.place(CGRect(x: 0, y: 0, width: wanted.width, height: wanted.height))
            y = wanted.height + 4
        }
        picker.frame = CGRect(x: 0, y: y, width: size.width, height: 216)
    }
}

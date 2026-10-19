import UIKit
import CoreGraphics

public protocol TimelineSchedule {
    associatedtype Entries: Sequence where Entries.Element == Date
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries
}

public struct PeriodicTimelineSchedule: TimelineSchedule {
    let interval: TimeInterval
    let startDate: Date
    public init(from startDate: Date, by interval: TimeInterval) { self.interval = interval; self.startDate = startDate }
    public struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date
        let interval: TimeInterval
        public mutating func next() -> Date? {
            let current = upcoming
            upcoming = upcoming.addingTimeInterval(interval)
            return current
        }
    }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        let elapsed = startDate.timeIntervalSince(self.startDate)
        let first = elapsed <= 0 ? self.startDate : self.startDate.addingTimeInterval(floor(elapsed / interval) * interval)
        return Entries(upcoming: first, interval: interval)
    }
}

public struct EveryMinuteTimelineSchedule: TimelineSchedule {
    public init() {}
    public struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date
        public mutating func next() -> Date? {
            let current = upcoming
            upcoming = upcoming.addingTimeInterval(60)
            return current
        }
    }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        let minute = floor(startDate.timeIntervalSinceReferenceDate / 60) * 60
        return Entries(upcoming: Date(timeIntervalSinceReferenceDate: minute))
    }
}

public struct AnimationTimelineSchedule: TimelineSchedule {
    let minimumInterval: Double?
    let paused: Bool
    public init(minimumInterval: Double? = nil, paused: Bool = false) { self.minimumInterval = minimumInterval; self.paused = paused }
    public struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date?
        let interval: TimeInterval
        let paused: Bool
        public mutating func next() -> Date? {
            guard let current = upcoming else { return nil }
            upcoming = paused ? nil : current.addingTimeInterval(interval)
            return current
        }
    }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(upcoming: startDate, interval: max(minimumInterval ?? 1.0 / 30, mode == .lowFrequency ? 1 : 1.0 / 60), paused: paused)
    }
}

extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule {
        PeriodicTimelineSchedule(from: startDate, by: interval)
    }
}

extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
    public static var everyMinute: EveryMinuteTimelineSchedule { EveryMinuteTimelineSchedule() }
}

public struct TimelineViewDefaultContext {
    public let date: Date
    public var cadence: Cadence { .live }
    public enum Cadence: Comparable { case live, seconds, minutes }
}

public struct TimelineView<Schedule: TimelineSchedule, Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public typealias Context = TimelineViewDefaultContext
    let schedule: Schedule
    let content: (Context) -> Content
    public init(_ schedule: Schedule, @ViewBuilder content: @escaping (Context) -> Content) {
        self.schedule = schedule; self.content = content
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TimelineNode(); n.update(self, env); return n }
}

protocol TimelineLike {
    func sameSchedule(as other: TimelineLike) -> Bool
    func dates(from start: Date) -> AnyIterator<Date>
    func timelineContent(_ date: Date) -> any View
}

extension TimelineView: TimelineLike {
    func sameSchedule(as other: TimelineLike) -> Bool {
        guard let other = other as? Self else { return false }
        return withUnsafeBytes(of: schedule) { a in withUnsafeBytes(of: other.schedule) { b in a.elementsEqual(b) } }
    }
    func dates(from start: Date) -> AnyIterator<Date> {
        var iterator = schedule.entries(from: start, mode: .normal).makeIterator()
        return AnyIterator { iterator.next() }
    }
    func timelineContent(_ date: Date) -> any View { content(Context(date: date)) }
}

final class TimelineTimerTarget: NSObject {
    var tick: () -> Void = {}
    @objc func fire() { tick() }
}

final class TimelineNode: ContainerNode {
    var source: TimelineLike?
    let timerTarget = TimelineTimerTarget()
    var timer: Timer?
    var dates: AnyIterator<Date>?
    var current = Date()

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let previous = source
        source = view as? TimelineLike
        if dates == nil || previous == nil || !(source?.sameSchedule(as: previous!) ?? false) {
            restart()
        }
        rebuild()
    }

    func restart() {
        timer?.invalidate()
        timer = nil
        guard let source else { return }
        let now = Date()
        let iterator = source.dates(from: now)
        var entry = iterator.next()
        current = entry ?? now
        while let date = entry, date <= now {
            current = date
            entry = iterator.next()
        }
        dates = iterator
        schedule(entry)
    }

    func schedule(_ next: Date?) {
        guard let next else { return }
        timerTarget.tick = { [weak self] in
            guard let self else { return }
            self.current = next
            self.rebuild()
            self.mount()
            if let host = self.env.host { host.view.setNeedsLayout() }
            self.schedule(self.dates?.next())
        }
        let timer = Timer.scheduledTimer(timeInterval: max(0.001, next.timeIntervalSinceNow), target: timerTarget, selector: #selector(TimelineTimerTarget.fire), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func rebuild() {
        guard let source else { return }
        content = adopt(reconcile(content, source.timelineContent(current), env))
    }

    override func dispose() {
        super.dispose()
        timer?.invalidate()
        timer = nil
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

public struct GroupBox<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    @Environment(\.self) var environment
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label()
    }
    public var body: some View {
        let configuration = GroupBoxStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: content))
        return applyStyle(environment, configuration) { DefaultGroupBoxStyle().makeBody(configuration: configuration) }
    }
}

extension GroupBox where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
}

extension GroupBox where Label == EmptyView {
    public init(@ViewBuilder content: () -> Content) {
        self.init(content: content, label: { EmptyView() })
    }
}

public struct ControlGroup<Content: View>: View {
    let content: Content
    var label: any View = EmptyView()
    @Environment(\.self) var environment
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        let configuration = ControlGroupStyleConfiguration(content: .init(wrapped: content), label: .init(wrapped: label))
        return applyStyle(environment, configuration) { AutomaticControlGroupStyle().makeBody(configuration: configuration) }
    }
}

extension ControlGroup {
    public init<L: View>(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> L) {
        self.content = content(); self.label = label()
    }
}

public struct Gauge<Label: View, CurrentValueLabel: View>: View {
    let value: Double
    let bounds: ClosedRange<Double>
    let label: Label
    var currentValueLabel: (any View)?
    var minimumValueLabel: (any View)?
    var maximumValueLabel: (any View)?
    @Environment(\.self) var environment
    public var body: some View {
        let fraction = max(0, min(1, (value - bounds.lowerBound) / max(bounds.upperBound - bounds.lowerBound, 0.0001)))
        let configuration = GaugeStyleConfiguration(value: fraction, label: .init(wrapped: label),
                                                    currentValueLabel: currentValueLabel.map { .init(wrapped: $0) },
                                                    minimumValueLabel: minimumValueLabel.map { .init(wrapped: $0) },
                                                    maximumValueLabel: maximumValueLabel.map { .init(wrapped: $0) })
        return applyStyle(environment, configuration) { DefaultGaugeStyle().makeBody(configuration: configuration) }
    }
}

extension Gauge {
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        self.init(value: Double(value), bounds: Double(bounds.lowerBound)...Double(bounds.upperBound), label: label())
        self.currentValueLabel = currentValueLabel()
    }
    public init<V: BinaryFloatingPoint, Min: View, Max: View>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel, @ViewBuilder minimumValueLabel: () -> Min, @ViewBuilder maximumValueLabel: () -> Max) {
        self.init(value: Double(value), bounds: Double(bounds.lowerBound)...Double(bounds.upperBound), label: label())
        self.currentValueLabel = currentValueLabel()
        self.minimumValueLabel = minimumValueLabel()
        self.maximumValueLabel = maximumValueLabel()
    }
}

extension Gauge where CurrentValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label) {
        self.init(value: Double(value), bounds: Double(bounds.lowerBound)...Double(bounds.upperBound), label: label())
    }
}

final class ShareTarget: NSObject {
    var present: () -> Void = {}
    @objc func fire() { present() }
}

public struct ShareLink<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let items: [Any]
    let label: Label
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShareNode(); n.update(self, env); return n }
}

extension ShareLink where Label == DefaultShareLinkLabel {
    public init(item: URL, subject: Text? = nil, message: Text? = nil) {
        if subject != nil { _Unsupported.note("ShareLink(subject:)", "the share sheet of iOS 6 takes no subject") }
        self.init(items: (message.map { [$0.content as Any] } ?? []) + [item], label: DefaultShareLinkLabel())
    }
    public init(item: String, subject: Text? = nil, message: Text? = nil) {
        if subject != nil { _Unsupported.note("ShareLink(subject:)", "the share sheet of iOS 6 takes no subject") }
        self.init(items: (message.map { [$0.content as Any] } ?? []) + [item], label: DefaultShareLinkLabel())
    }
    public init(item: URL, subject: Text? = nil, message: Text? = nil, preview: SharePreview) {
        self.init(item: item, subject: subject, message: message)
    }
}

extension ShareLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, item: URL, subject: Text? = nil, message: Text? = nil) {
        self.init(items: (message.map { [$0.content as Any] } ?? []) + [item], label: Text(titleKey))
    }
    public init<S: StringProtocol>(_ title: S, item: URL, subject: Text? = nil, message: Text? = nil) {
        self.init(items: (message.map { [$0.content as Any] } ?? []) + [item], label: Text(title))
    }
}

extension ShareLink {
    public init(item: URL, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(items: (message.map { [$0.content as Any] } ?? []) + [item], label: label())
    }
}

public struct DefaultShareLinkLabel: View {
    public var body: some View { Text("Share") }
}

public struct SharePreview {
    let title: String
    public init(_ titleKey: LocalizedStringKey) { title = titleKey.text }
    public init<I>(_ titleKey: LocalizedStringKey, image: I) { title = titleKey.text }
}

protocol ShareLinkLike {
    var shareItems: [Any] { get }
    var shareLabel: any View { get }
}

extension ShareLink: ShareLinkLike {
    var shareItems: [Any] { items }
    var shareLabel: any View { label }
}

final class ShareNode: LayoutNode {
    let target = ShareTarget()
    var button: UIButton { uiView as! UIButton }

    init() {
        let control = UIButton(type: .roundedRect)
        super.init(view: control)
        control.addTarget(target, action: #selector(ShareTarget.fire), for: .touchUpInside)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? ShareLinkLike else { return }
        let title = findText(source.shareLabel)?.content ?? "Share"
        if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
        let items = source.shareItems
        let host = env.host
        target.present = {
            guard let host else { return }
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            host.present(controller, animated: true, completion: nil)
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let wanted = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(max(wanted.width + 24, 72), p.width ?? infinity), height: max(wanted.height, 37))
    }
}

public struct EditMode: Equatable {
    public static let inactive = EditMode(active: false)
    public static let active = EditMode(active: true)
    let active: Bool
    public var isEditing: Bool { active }
}

struct EditModeKey: EnvironmentKey {
    static var defaultValue: Binding<EditMode>? { nil }
}

extension EnvironmentValues {
    public var editMode: Binding<EditMode>? {
        get { self[EditModeKey.self] }
        set { self[EditModeKey.self] = newValue }
    }
}

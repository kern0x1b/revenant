import UIKit

public struct MultiDatePicker<Label: View>: View {
    let label: Label
    let selection: Binding<Set<DateComponents>>
    let bounds: Range<Date>?
    @State private var shownMonth: Date
    var initialMonth = Date()

    public init(selection: Binding<Set<DateComponents>>, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.label = label(); bounds = nil; _shownMonth = State(wrappedValue: Date())
    }
    public init(selection: Binding<Set<DateComponents>>, in bounds: Range<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.label = label(); self.bounds = bounds; _shownMonth = State(wrappedValue: Date())
    }
    public init(selection: Binding<Set<DateComponents>>, in bounds: PartialRangeFrom<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.label = label(); self.bounds = bounds.lowerBound..<Date.distantFuture; _shownMonth = State(wrappedValue: Date())
    }
    public init(selection: Binding<Set<DateComponents>>, in bounds: PartialRangeUpTo<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.label = label(); self.bounds = Date.distantPast..<bounds.upperBound; _shownMonth = State(wrappedValue: Date())
    }

    public var body: some View {
        let calendar = Calendar.current
        let month = calendar.dateComponents([Calendar.Component.year, Calendar.Component.month], from: shownMonth)
        let first = calendar.date(from: month) ?? shownMonth
        let days = calendar.range(of: Calendar.Component.day, in: Calendar.Component.month, for: first)?.count ?? 30
        let weekday = calendar.dateComponents([Calendar.Component.weekday], from: first).weekday ?? 1
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        let cells: [Int?] = Array(repeating: nil, count: lead) + (1...days).map { Optional($0) }
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let title = formatter.string(from: first)
        return VStack(spacing: 6) {
            label
            header(title, calendar)
            monthGrid(rows, month, calendar)
        }
    }

    func header(_ title: String, _ calendar: Calendar) -> AnyView {
        let back: () -> Void = { shownMonth = calendar.date(byAdding: DateComponents(month: -1), to: shownMonth) ?? shownMonth }
        let forward: () -> Void = { shownMonth = calendar.date(byAdding: DateComponents(month: 1), to: shownMonth) ?? shownMonth }
        return AnyView(HStack {
            Button("‹", action: back)
            Spacer()
            Text(title).fixedSize()
            Spacer()
            Button("›", action: forward)
        })
    }

    func monthGrid(_ rows: [[Int?]], _ month: DateComponents, _ calendar: Calendar) -> AnyView {
        AnyView(Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        dayCell(column < rows[row].count ? rows[row][column] : nil, month, calendar)
                    }
                }
            }
        })
    }

    public func _showing(_ month: Date) -> Self {
        var copy = self
        copy._shownMonth = State(wrappedValue: month)
        return copy
    }

    func dayCell(_ day: Int?, _ month: DateComponents, _ calendar: Calendar) -> AnyView {
        guard let day else { return AnyView(Color.clear.frame(width: 36, height: 30)) }
        var components = DateComponents()
        components.year = month.year; components.month = month.month; components.day = day
        let date = calendar.date(from: components)
        let allowed = date.map { bounds?.contains($0) ?? true } ?? false
        let chosen = selection.wrappedValue.contains { $0.year == components.year && $0.month == components.month && $0.day == components.day }
        let binding = selection
        return AnyView(
            Text("\(day)")
                .foregroundColor(chosen ? .white : (allowed ? .black : .gray))
                .frame(width: 36, height: 30)
                .background(chosen ? Color.accentColor : Color.clear, cornerRadius: 15)
                .onTapGesture {
                    guard allowed else { return }
                    if let existing = binding.wrappedValue.first(where: { $0.year == components.year && $0.month == components.month && $0.day == components.day }) {
                        binding.wrappedValue.remove(existing)
                    } else {
                        binding.wrappedValue.insert(components)
                    }
                }
        )
    }
}

extension MultiDatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>) {
        self.init(selection: selection) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>, in bounds: Range<Date>) {
        self.init(selection: selection, in: bounds) { Text(titleKey) }
    }
}

import UIKit

public struct _AnyTableColumn<Row> {
    let title: String
    let cell: (Row) -> any View
    let sortKey: AnyKeyPath?
    let readKey: ((Row) -> any Comparable)?
    let columnAlignment: TableColumnAlignment
    init(title: String, cell: @escaping (Row) -> any View, sortKey: AnyKeyPath? = nil,
         readKey: ((Row) -> any Comparable)? = nil, columnAlignment: TableColumnAlignment = .automatic) {
        self.title = title; self.cell = cell; self.sortKey = sortKey; self.readKey = readKey
        self.columnAlignment = columnAlignment
    }
}

public protocol TableColumnContent {
    associatedtype TableRowValue: Identifiable
    associatedtype TableColumnSortComparator
    associatedtype TableColumnBody
    var _columns: [_AnyTableColumn<TableRowValue>] { get }
    func alignment(_ alignment: TableColumnAlignment) -> Self
}

extension TableColumnContent {
    public func alignment(_ alignment: TableColumnAlignment) -> Self { self }
}

public struct TableColumn<RowValue: Identifiable, Sort, Content: View, Label: View>: TableColumnContent, View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Content
    let title: String
    let cell: (RowValue) -> Content
    let sortKey: AnyKeyPath?
    let readKey: ((RowValue) -> any Comparable)?
    let columnAlignment: TableColumnAlignment
    public var _columns: [_AnyTableColumn<RowValue>] {
        [_AnyTableColumn(title: title, cell: { cell($0) }, sortKey: sortKey, readKey: readKey,
                         columnAlignment: alignment)]
    }
    var alignment: TableColumnAlignment { columnAlignment }
    public func width(_ width: CGFloat? = nil) -> Self { self }
    public func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> Self { self }
}

extension TableColumn where Sort == Never, Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping (RowValue) -> Content) {
        title = titleKey.text; cell = content; sortKey = nil; readKey = nil; columnAlignment = .automatic
    }
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: @escaping (RowValue) -> Content) {
        self.title = String(title); cell = content; sortKey = nil; readKey = nil; columnAlignment = .automatic
    }
}

extension TableColumn where Sort == Never, Label == Text, Content == Text {
    public init<C: Comparable>(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, C>) {
        title = titleKey.text
        cell = { Text(String(describing: $0[keyPath: value])) }
        sortKey = value as AnyKeyPath
        readKey = { $0[keyPath: value] as any Comparable }
        columnAlignment = .numeric
    }
    public init<S: StringProtocol, C: Comparable>(_ title: S, value: KeyPath<RowValue, C>) {
        self.title = String(title)
        cell = { Text(String(describing: $0[keyPath: value])) }
        sortKey = value as AnyKeyPath
        readKey = { $0[keyPath: value] as any Comparable }
        columnAlignment = .numeric
    }
    public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>) {
        title = titleKey.text
        cell = { Text($0[keyPath: value]) }
        sortKey = value as AnyKeyPath
        readKey = { $0[keyPath: value] as any Comparable }
        columnAlignment = .automatic
    }
    public init<S: StringProtocol>(_ title: S, value: KeyPath<RowValue, String>) {
        self.title = String(title)
        cell = { Text($0[keyPath: value]) }
        sortKey = value as AnyKeyPath
        readKey = { $0[keyPath: value] as any Comparable }
        columnAlignment = .automatic
    }
}

public struct TupleTableColumnContent<RowValue: Identifiable, Sort, T>: TableColumnContent {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    public let value: T
    public let _columns: [_AnyTableColumn<RowValue>]
}

@resultBuilder
public struct TableColumnBuilder<RowValue: Identifiable, Sort> {
    public static func buildExpression<C: TableColumnContent>(_ column: C) -> C where C.TableRowValue == RowValue { column }
    public static func buildBlock<C: TableColumnContent>(_ column: C) -> C where C.TableRowValue == RowValue { column }
    public static func buildBlock<each C: TableColumnContent>(_ columns: repeat each C) -> TupleTableColumnContent<RowValue, Sort, (repeat each C)> {
        var all: [_AnyTableColumn<RowValue>] = []
        for column in repeat each columns {
            for part in column._columns { if let typed = part as? _AnyTableColumn<RowValue> { all.append(typed) } }
        }
        return TupleTableColumnContent(value: (repeat each columns), _columns: all)
    }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == Never, T.TableRowValue == F.TableRowValue,
              F.TableColumnSortComparator == Never { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, Sort == T.TableColumnSortComparator, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == F.TableColumnSortComparator, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .falseContent(second))
    }
    @_disfavoredOverload
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == Never, T.TableRowValue == F.TableRowValue,
              F.TableColumnSortComparator == Never { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildIf<C>(_ content: C?) -> C?
        where RowValue == C.TableRowValue, Sort == C.TableColumnSortComparator, C: TableColumnContent { content }
    @_disfavoredOverload
    public static func buildIf<C>(_ content: C?) -> C?
        where RowValue == C.TableRowValue, C: TableColumnContent, C.TableColumnSortComparator == Never { content }
    public static func buildLimitedAvailability<C: TableColumnContent>(_ content: C) -> _AnyTableColumnContent<RowValue, Sort>
        where C.TableRowValue == RowValue, C.TableColumnSortComparator == Sort { _AnyTableColumnContent(content) }
    @_disfavoredOverload
    public static func buildLimitedAvailability<C: TableColumnContent>(_ content: C) -> _AnyTableColumnContent<RowValue, Never>
        where C.TableRowValue == RowValue, C.TableColumnSortComparator == Never { _AnyTableColumnContent(content) }
    public static func buildLimitedAvailability() -> _AnyTableColumnContent<RowValue, Sort> {
        _AnyTableColumnContent(_EmptyTableColumnContent<RowValue, Sort>())
    }
}

public protocol TableRowContent {
    associatedtype TableRowValue: Identifiable
    associatedtype TableRowBody
    var _rows: [TableRowValue] { get }
}

public struct TableRow<Value: Identifiable>: TableRowContent, View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    let value: Value
    public init(_ value: Value) { self.value = value }
    public var _rows: [Value] { [value] }
}

public struct TableForEachContent<Data: RandomAccessCollection, RowContent: TableRowContent>: TableRowContent
    where Data.Element: Identifiable, RowContent.TableRowValue == Data.Element {
    public typealias TableRowValue = Data.Element
    public typealias TableRowBody = Never
    let data: Data
    let content: (Data.Element) -> RowContent
    public init(_ data: Data, content: @escaping (Data.Element) -> RowContent) {
        self.data = data; self.content = content
    }
    public var _rows: [Data.Element] { Array(data) }
}

public struct _AnyTableRowContent<Value: Identifiable>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public let _rows: [Value]
    init<C: TableRowContent>(_ content: C) where C.TableRowValue == Value { _rows = content._rows }
}

public struct _AnyTableColumnContent<RowValue: Identifiable, Sort>: TableColumnContent {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    public let _columns: [_AnyTableColumn<RowValue>]
    init<C: TableColumnContent>(_ content: C) where C.TableRowValue == RowValue, C.TableColumnSortComparator == Sort {
        _columns = content._columns
    }
}

public struct _EmptyTableColumnContent<RowValue: Identifiable, Sort>: TableColumnContent {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    public init() {}
    public var _columns: [_AnyTableColumn<RowValue>] { [] }
}

public struct EmptyTableRowContent<Value: Identifiable>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public var _rows: [Value] { [] }
}

public struct TupleTableRowContent<Value: Identifiable, T>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public let value: T
    public let _rows: [Value]
}

@resultBuilder
public struct TableRowBuilder<Value: Identifiable> {
    public static func buildExpression<R: TableRowContent>(_ row: R) -> R where R.TableRowValue == Value { row }
    public static func buildBlock() -> EmptyTableRowContent<Value> { EmptyTableRowContent() }
    public static func buildBlock<R: TableRowContent>(_ row: R) -> R where R.TableRowValue == Value { row }
    public static func buildBlock<each R: TableRowContent>(_ rows: repeat each R) -> TupleTableRowContent<Value, (repeat each R)> {
        var all: [Value] = []
        for row in repeat each rows {
            for item in row._rows { if let typed = item as? Value { all.append(typed) } }
        }
        return TupleTableRowContent(value: (repeat each rows), _rows: all)
    }
    public static func buildIf<C>(_ content: C?) -> C? where Value == C.TableRowValue, C: TableRowContent { content }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F>
        where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .trueContent(first))
    }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .falseContent(second))
    }
    public static func buildLimitedAvailability<C: TableRowContent>(_ content: C) -> _AnyTableRowContent<Value>
        where C.TableRowValue == Value { _AnyTableRowContent(content) }
    public static func buildLimitedAvailability() -> _AnyTableRowContent<Value> {
        _AnyTableRowContent(EmptyTableRowContent<Value>())
    }
}

public protocol TableStyle {}
public struct AutomaticTableStyle: TableStyle { public init() {} }
public struct InsetTableStyle: TableStyle { public init() {} }
public struct BorderedTableStyle: TableStyle { public init() {} }
public struct TableStyleConfiguration {}
extension TableStyle where Self == AutomaticTableStyle { public static var automatic: AutomaticTableStyle { AutomaticTableStyle() } }
extension TableStyle where Self == InsetTableStyle { public static var inset: InsetTableStyle { InsetTableStyle() } }

public struct Table<Value: Identifiable, Rows: TableRowContent, Columns: TableColumnContent>: View where Rows.TableRowValue == Value, Columns.TableRowValue == Value {
    let rows: Rows
    let columns: Columns
    var selection: SelectionBox?
    var sortOrder: Binding<[KeyPathComparator<Value>]>?
    var customizationBehavior: TableColumnCustomizationBehavior = .all
    struct ColumnVisibility { var order: [String] = []; var hidden: [String] = [] }
    var columnCustomization: ColumnVisibility?

    var visibleColumns: [_AnyTableColumn<Value>] {
        let all = columns._columns
        guard let customization = columnCustomization, customizationBehavior.contains(.visibility) else { return all }
        let hidden = Set(customization.hidden)
        let kept = all.filter { !hidden.contains($0.title) }
        let ordered = customization.order.compactMap { title in kept.first { $0.title == title } }
        return ordered.isEmpty ? kept : ordered
    }
    public var body: AnyView {
        if UIDevice.current.userInterfaceIdiom == .pad { _Unsupported.pendingNote("Table columns on iPad") }
        var ordered = rows._rows
        if let sortOrder {
            for comparator in sortOrder.wrappedValue.reversed() {
                ordered.sort { a, b in
                    let selector = NSSelectorFromString("compare:")
                    func compare(_ left: any Comparable, _ right: any Comparable) -> Int? {
                        guard let both = left as? NSObject, let other = right as? NSObject else { return nil }
                        return both.perform(selector, with: other).takeUnretainedValue() as? Int
                    }
                    guard let order = compare(comparator.read(a), comparator.read(b)) else { return false }
                    if order == 0 { return false }
                    return comparator.ascending ? order < 0 : order > 0
                }
            }
        }
        let shown = visibleColumns
        var list = List { ForEach(ordered) { row -> AnyView in
            guard let first = shown.first else { return AnyView(EmptyView()) }
            let cell = first.cell(row)
            switch first.columnAlignment.horizontal {
            case .leading: return AnyView(HStack { AnyView(cell); Spacer() })
            case .trailing: return AnyView(HStack { Spacer(); AnyView(cell) })
            default: return AnyView(cell)
            }
        } }
        if sortOrder == nil { return AnyView(list) }
        return AnyView(VStack(spacing: 0) {
            TableHeader(columns: shown, sortOrder: sortOrder)
            list
        })
    }
}

extension Table {
    public init<Data: RandomAccessCollection>(_ data: Data, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data, EmptyTableRowContent<Value>>, Data.Element == Value {
        rows = TableForEachContent(data) { _ in EmptyTableRowContent() }; self.columns = columns(); selection = nil; sortOrder = nil
    }
    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data, EmptyTableRowContent<Value>>, Data.Element == Value {
        rows = TableForEachContent(data) { _ in EmptyTableRowContent() }; self.columns = columns()
        self.selection = SelectionBox(current: { selection.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                                      choose: { if let value = $0.base as? Value.ID { selection.wrappedValue = value } },
                                      clear: { selection.wrappedValue = nil })
        sortOrder = nil
    }
    public init(@TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.rows = rows(); self.columns = columns(); selection = nil; sortOrder = nil
    }
}

extension View {
    public func tableStyle<S: TableStyle>(_ style: S) -> some View { self }
}

extension Never: TableRowContent {
    public typealias TableRowValue = Never
    public typealias TableRowBody = Never
    public var _rows: [Never] { [] }
}

extension Group: TableRowContent where Content: TableRowContent {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [Content.TableRowValue] { content._rows }
}

extension Section: TableRowContent where Content: TableRowContent {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [Content.TableRowValue] { content._rows }
}

extension ForEach: TableRowContent where Content: TableRowContent {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [Content.TableRowValue] {
        data.map { content($0)._rows }.flatMap { $0 }
    }
}

extension Group: TableColumnContent where Content: TableColumnContent {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableColumnSortComparator = Content.TableColumnSortComparator
    public typealias TableColumnBody = Never
    public var _columns: [_AnyTableColumn<Content.TableRowValue>] { content._columns }
}

extension Table {
    public init(of type: Value.Type, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(columns: columns, rows: rows)
    }
    public init(of type: Value.Type, sortOrder: Binding<[KeyPathComparator<Value>]>,
                columnCustomization: Binding<TableColumnCustomization<Value>>,
                @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows)
        where Value.ID: Codable {
        self.init(of: type, sortOrder: sortOrder, columns: columns, rows: rows)
        project(columnCustomization.wrappedValue)
    }
    public init(of type: Value.Type, columnCustomization: Binding<TableColumnCustomization<Value>>,
                @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows)
        where Value.ID: Codable {
        self.init(columns: columns, rows: rows)
        project(columnCustomization.wrappedValue)
    }
    mutating func project(_ given: TableColumnCustomization<Value>) where Value.ID: Codable {
        var titles: [String] = []
        var hiddenTitles: [String] = []
        let drawn = columns._columns
        for (index, id) in given.order.enumerated() where index < drawn.count {
            titles.append(drawn[index].title)
            if given.visibility[id] == false { hiddenTitles.append(drawn[index].title) }
        }
        columnCustomization = ColumnVisibility(order: titles, hidden: hiddenTitles)
    }
    public init(of type: Value.Type, sortOrder: Binding<[KeyPathComparator<Value>]>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(columns: columns, rows: rows)
        self.sortOrder = sortOrder
    }
    public init(of type: Value.Type, selection: Binding<Value.ID?>, sortOrder: Binding<[KeyPathComparator<Value>]>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(of: type, selection: selection, columns: columns, rows: rows)
        self.sortOrder = sortOrder
    }
    @_disfavoredOverload
    public init(of type: Value.Type, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[KeyPathComparator<Value>]>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(of: type, selection: selection, columns: columns, rows: rows)
        self.sortOrder = sortOrder
    }
    public init(of type: Value.Type, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.rows = rows(); self.columns = columns()
        self.selection = SelectionBox(current: { selection.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                                      choose: { if let value = $0.base as? Value.ID { selection.wrappedValue = value } },
                                      clear: { selection.wrappedValue = nil })
        sortOrder = nil
    }
    @_disfavoredOverload
    public init(of type: Value.Type, selection: Binding<Set<Value.ID>>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.rows = rows(); self.columns = columns()
        self.selection = SelectionBox(current: { Set(selection.wrappedValue.map { AnyHashable($0) }) },
                                      choose: { value in
                                          guard let typed = value.base as? Value.ID else { return }
                                          if selection.wrappedValue.contains(typed) { selection.wrappedValue.remove(typed) } else { selection.wrappedValue.insert(typed) }
                                      },
                                      clear: { selection.wrappedValue = [] })
        sortOrder = nil
    }
}

@frozen public struct KeyPathComparator<Value>: Equatable {
    public typealias Key = KeyPath<Value, any Comparable>
    public let key: AnyKeyPath
    var ascending: Bool
    let read: (Value) -> any Comparable
    public init<C: Comparable>(_ key: KeyPath<Value, C>, ascending: Bool = true) {
        self.key = key as AnyKeyPath; self.ascending = ascending
        read = { value in value[keyPath: key] as any Comparable }
    }
    func ordering(_ comparators: [KeyPathComparator<Value>], after column: KeyPathComparator<Value>) -> [KeyPathComparator<Value>] {
        if comparators.first?.key == column.key {
            var turned = comparators
            turned[0].ascending = !turned[0].ascending
            return turned
        }
        return [KeyPathComparator(existing: column.key, read: column.read)] + comparators.filter { $0.key != column.key }
    }
    init(existing key: AnyKeyPath, read: @escaping (Value) -> any Comparable) {
        self.key = key; ascending = true; self.read = read
    }
    public static func == (a: KeyPathComparator<Value>, b: KeyPathComparator<Value>) -> Bool {
        a.key == b.key && a.ascending == b.ascending
    }
}

extension KeyPathComparator {
    func ordering<C: Comparable>(_ comparators: [KeyPathComparator<Value>], after key: KeyPath<Value, C>) -> [KeyPathComparator<Value>] {
        if comparators.first?.key == (key as AnyKeyPath) {
            var turned = comparators
            turned[0].ascending = !turned[0].ascending
            return turned
        }
        return [KeyPathComparator(key, ascending: true)] + comparators.filter { $0.key != (key as AnyKeyPath) }
    }
}

extension ForEach where Content: TableRowContent {
    public init<Data: RandomAccessCollection>(_ data: Data, @TableRowBuilder<Data.Element> content: @escaping (Data.Element) -> Content)
        where Data.Element: Identifiable {
        self.init(data, id: \.id, content: content)
    }
    public init<Data: RandomAccessCollection, ID: Hashable>(_ data: Data, id: KeyPath<Data.Element, ID>,
                                                              @TableRowBuilder<Data.Element> content: @escaping (Data.Element) -> Content)
        where Data.Element: Identifiable {
        self.init(data, id: id, content: content)
    }
}

extension Table {
    public init<Data: RandomAccessCollection>(_ data: Data, sortOrder: Binding<[KeyPathComparator<Value>]>,
                                              @TableColumnBuilder<Value, Never> columns: () -> Columns)
        where Rows == TableForEachContent<Data, EmptyTableRowContent<Value>>, Data.Element == Value {
        self.init(data, columns: columns)
        self.sortOrder = sortOrder
    }
    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Value.ID?>,
                                              sortOrder: Binding<[KeyPathComparator<Value>]>,
                                              @TableColumnBuilder<Value, Never> columns: () -> Columns)
        where Rows == TableForEachContent<Data, EmptyTableRowContent<Value>>, Data.Element == Value {
        self.init(data, selection: selection, columns: columns)
        self.sortOrder = sortOrder
    }
    @_disfavoredOverload
    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Set<Value.ID>>,
                                              sortOrder: Binding<[KeyPathComparator<Value>]>,
                                              @TableColumnBuilder<Value, Never> columns: () -> Columns)
        where Rows == TableForEachContent<Data, EmptyTableRowContent<Value>>, Data.Element == Value {
        self.init(data, columns: columns)
        self.sortOrder = sortOrder
        self.selection = SelectionBox(current: { Set(selection.wrappedValue.map { AnyHashable($0) }) },
                                      choose: { value in
                                          guard let typed = value.base as? Value.ID else { return }
                                          if selection.wrappedValue.contains(typed) { selection.wrappedValue.remove(typed) } else { selection.wrappedValue.insert(typed) }
                                      },
                                      clear: { selection.wrappedValue = [] })
    }
}

struct TableSortArrow: Shape {
    public func path(in whole: CGRect) -> Path {
        let w = min(whole.size.width, 8), h = min(whole.size.height, 6)
        let x = whole.origin.x + (whole.size.width - w) / 2
        let y = whole.origin.y + (whole.size.height - h) / 2
        var path = Path()
        path.move(to: CGPoint(x: x + w / 2, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h))
        path.closeSubpath()
        return path
    }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        let proposed = proposal.replacingUnspecifiedDimensions()
        return CGSize(width: min(proposed.width, 8), height: min(proposed.height, 6))
    }
}

struct TableHeader<Value: Identifiable>: View {
    let columns: [_AnyTableColumn<Value>]
    let sortOrder: Binding<[KeyPathComparator<Value>]>?
    var body: some View {
        HStack(spacing: 0) {
            cell(0)
            cell(1)
            cell(2)
            cell(3)
        }
    }
    private var arrowTint: Color { Color(UIColor(white: 0.55, alpha: 1)) }
    private func cell(_ index: Int) -> some View {
        let column = index < columns.count ? columns[index] : nil
        guard let column else { return AnyView(EmptyView()) }
        let key = column.sortKey
        let sorted = key != nil && sortOrder?.wrappedValue.first?.key == key
        let forward = sortOrder?.wrappedValue.first?.ascending ?? true
        let title = HStack(spacing: 4) {
            Text(column.title)
            if sorted {
                TableSortArrow().fill(arrowTint)
                    .rotationEffect(.degrees(forward ? 0 : 180))
                    .frame(width: 8, height: 6)
            }
        }
        guard let sortOrder, let read = column.readKey, key != nil else { return AnyView(title) }
        let comparator = KeyPathComparator<Value>(existing: key!, read: read)
        return AnyView(Button(action: { sortOrder.wrappedValue = comparator.ordering(sortOrder.wrappedValue, after: comparator) }) { title })
    }
}

public struct TableColumnCustomizationBehavior: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let reorder = TableColumnCustomizationBehavior(rawValue: 1 << 0)
    public static let resize = TableColumnCustomizationBehavior(rawValue: 1 << 1)
    public static let visibility = TableColumnCustomizationBehavior(rawValue: 1 << 2)
    public static let all: TableColumnCustomizationBehavior = [.reorder, .resize, .visibility]
}

public struct TableColumnAlignment: Hashable {
    let horizontal: HorizontalAlignment?
    let numbering: String?
    init(horizontal: HorizontalAlignment?, numbering: String?) {
        self.horizontal = horizontal; self.numbering = numbering
    }
    public static var automatic: TableColumnAlignment { TableColumnAlignment(horizontal: nil, numbering: nil) }
    public static var leading: TableColumnAlignment { TableColumnAlignment(horizontal: .leading, numbering: nil) }
    public static var center: TableColumnAlignment { TableColumnAlignment(horizontal: .center, numbering: nil) }
    public static var trailing: TableColumnAlignment { TableColumnAlignment(horizontal: .trailing, numbering: nil) }
    public static var numeric: TableColumnAlignment { TableColumnAlignment(horizontal: .trailing, numbering: nil) }
    public static func numeric(_ numberingSystem: String) -> TableColumnAlignment {
        TableColumnAlignment(horizontal: .trailing, numbering: numberingSystem)
    }
    public static func == (a: TableColumnAlignment, b: TableColumnAlignment) -> Bool {
        a.horizontal == b.horizontal && a.numbering == b.numbering
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(String(describing: horizontal)); hasher.combine(numbering) }
    public var hashValue: Int { var h = Hasher(); hash(into: &h); return h.finalize() }
}

@frozen public struct TableColumnCustomization<Value: Identifiable> where Value.ID: Codable {
    public typealias ID = Value.ID
    public var visibility: [ID: Bool]
    public var order: [ID]
    public init() { visibility = [:]; order = [] }
    public mutating func resetOrder() { order = [] }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(order)
        try container.encode(Set(visibility.filter { !$0.value }.keys))
    }
}

extension Optional: TableRowContent where Wrapped: TableRowContent {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [Wrapped.TableRowValue] { self?._rows ?? [] }
}

extension Optional: TableColumnContent where Wrapped: TableColumnContent, Wrapped.TableColumnSortComparator == Never {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public var _columns: [_AnyTableColumn<Wrapped.TableRowValue>] { self?._columns ?? [] }
}


extension _ConditionalContent: TableColumnContent
    where TrueContent: TableColumnContent, FalseContent: TableColumnContent,
          TrueContent.TableRowValue == FalseContent.TableRowValue,
          TrueContent.TableColumnSortComparator == FalseContent.TableColumnSortComparator {
    public typealias TableRowValue = TrueContent.TableRowValue
    public typealias TableColumnSortComparator = TrueContent.TableColumnSortComparator
    public typealias TableColumnBody = Never
    public var _columns: [_AnyTableColumn<TrueContent.TableRowValue>] {
        switch storage {
        case .trueContent(let arm): return arm._columns
        case .falseContent(let arm): return arm._columns
        }
    }
}

extension _ConditionalContent: TableRowContent
    where TrueContent: TableRowContent, FalseContent: TableRowContent,
          TrueContent.TableRowValue == FalseContent.TableRowValue {
    public typealias TableRowValue = TrueContent.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [TrueContent.TableRowValue] {
        switch storage {
        case .trueContent(let arm): return arm._rows
        case .falseContent(let arm): return arm._rows
        }
    }
}

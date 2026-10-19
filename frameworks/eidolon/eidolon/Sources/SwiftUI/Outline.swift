import UIKit

struct OutlineItem {
    let id: AnyHashable
    let row: () -> any View
    let children: [OutlineItem]?
}

public struct OutlineSubgroupChildren: View {
    let items: [OutlineItem]
    public var body: some View { _OutlineRows(items: items) }
}

struct _OutlineRows: View {
    let items: [OutlineItem]
    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            _OutlineRow(item: items[index])
        }
    }
}

struct _OutlineRow: View {
    let item: OutlineItem
    var body: some View {
        if let children = item.children {
            DisclosureGroup {
                OutlineSubgroupChildren(items: children)
            } label: {
                AnyView(item.row())
            }
        } else {
            AnyView(item.row())
        }
    }
}

public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, Parent, Leaf, Subgroup>: View {
    let items: [OutlineItem]
    public var body: some View { _OutlineRows(items: items) }
}

func outlineItems<Element, ID: Hashable>(_ data: some Collection<Element>, id: KeyPath<Element, ID>, children: KeyPath<Element, [Element]?>, content: @escaping (Element) -> any View) -> [OutlineItem] {
    data.map { element in
        OutlineItem(id: AnyHashable(element[keyPath: id]),
                    row: { content(element) },
                    children: element[keyPath: children].map { outlineItems($0, id: id, children: children, content: content) })
    }
}

extension OutlineGroup where ID == Data.Element.ID, Parent: View, Parent == Leaf, Subgroup == DisclosureGroup<Parent, OutlineSubgroupChildren>, Leaf: View, Data.Element: Identifiable {
    public init<DataElement: Identifiable>(_ data: Data, children: KeyPath<DataElement, Data?>, @ViewBuilder content: @escaping (DataElement) -> Leaf) where ID == DataElement.ID, DataElement == Data.Element {
        items = outlineItems(Array(data), id: \.id, children: children.appending(path: \Data?.asArray), content: { content($0) })
    }
    public init<DataElement: Identifiable>(_ root: DataElement, children: KeyPath<DataElement, Data?>, @ViewBuilder content: @escaping (DataElement) -> Leaf) where ID == DataElement.ID, DataElement == Data.Element {
        items = outlineItems([root], id: \.id, children: children.appending(path: \Data?.asArray), content: { content($0) })
    }
}

extension OutlineGroup where Parent: View, Parent == Leaf, Subgroup == DisclosureGroup<Parent, OutlineSubgroupChildren>, Leaf: View {
    public init<DataElement>(_ data: Data, id: KeyPath<DataElement, ID>, children: KeyPath<DataElement, Data?>, @ViewBuilder content: @escaping (DataElement) -> Leaf) where DataElement == Data.Element {
        items = outlineItems(Array(data), id: id, children: children.appending(path: \Data?.asArray), content: { content($0) })
    }
    public init<DataElement>(_ root: DataElement, id: KeyPath<DataElement, ID>, children: KeyPath<DataElement, Data?>, @ViewBuilder content: @escaping (DataElement) -> Leaf) where DataElement == Data.Element {
        items = outlineItems([root], id: id, children: children.appending(path: \Data?.asArray), content: { content($0) })
    }
}

extension Optional where Wrapped: Collection {
    var asArray: [Wrapped.Element]? { map { Array($0) } }
}

extension List where SelectionValue == Never {
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, children: KeyPath<Data.Element, Data?>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == OutlineGroup<Data, Data.Element.ID, RowContent, RowContent, DisclosureGroup<RowContent, OutlineSubgroupChildren>>, Data.Element: Identifiable {
        self.init { OutlineGroup(data, children: children, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == OutlineGroup<Data, ID, RowContent, RowContent, DisclosureGroup<RowContent, OutlineSubgroupChildren>> {
        self.init { OutlineGroup(data, id: id, children: children, content: rowContent) }
    }
}

// An outline group's rows for a table are its leaves' rows: a node with children is a section, and the
// row content of a node is the content of the leaf it stands for. The row value is the leaf's own.
extension OutlineGroup: TableRowContent where Leaf: TableRowContent {
    public typealias TableRowValue = Leaf.TableRowValue
    public typealias TableRowBody = Never
    public var _rows: [Leaf.TableRowValue] { leafRows(in: items, as: Leaf.self) }
}

private func leafRows<Value: TableRowContent>(in items: [OutlineItem], as: Value.Type) -> [Value.TableRowValue] {
    items.flatMap { item -> [Value.TableRowValue] in
        if let children = item.children { return leafRows(in: children, as: Value.self) }
        return (item.row() as? Value)?._rows ?? []
    }
}

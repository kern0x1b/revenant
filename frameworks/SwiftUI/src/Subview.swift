import UIKit

public struct Subview: View, PrimitiveView, Identifiable {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    public struct ID: Hashable {
        let identity: AnyHashable
        let position: Int
        public static func == (a: Subview.ID, b: Subview.ID) -> Bool {
            a.identity == b.identity && a.position == b.position
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(identity)
            hasher.combine(position)
        }
        public var hashValue: Int { var hasher = Hasher(); hash(into: &hasher); return hasher.finalize() }
    }

    public let id: ID
    public let containerValues: ContainerValues
    let content: AnyView

    public init(_ content: some View) {
        self.content = AnyView(content)
        id = ID(identity: AnyHashable(ObjectIdentifier(content as AnyObject)), position: 0)
        containerValues = ContainerValues()
    }
    init(_ content: AnyView, id: ID, containerValues: ContainerValues) {
        self.content = content
        self.id = id
        self.containerValues = containerValues
    }
    public init(from decoder: any Decoder) throws { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "a subview is made by a container, not decoded")) }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id.hashValue)
    }
    func makeNode(_ env: EnvironmentValues) -> Node { content.makeNode(env) }
}

public struct SubviewsCollection: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<SubviewsCollection>
    public typealias SubSequence = SubviewsCollectionSlice
    public let startIndex: Int
    public let endIndex: Int
    let children: [Subview]
    init(_ children: [Subview]) {
        self.children = children
        startIndex = 0
        endIndex = children.count
    }
    public subscript(index: Int) -> Subview { children[index] }
    public subscript(bounds: Range<Int>) -> SubviewsCollectionSlice {
        SubviewsCollectionSlice(Array(children[bounds]))
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}

public struct SubviewsCollectionSlice: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<SubviewsCollectionSlice>
    public typealias SubSequence = SubviewsCollectionSlice
    public let startIndex: Int
    public let endIndex: Int
    let children: [Subview]
    init(_ children: [Subview]) {
        self.children = children
        startIndex = 0
        endIndex = children.count
    }
    public subscript(index: Int) -> Subview { children[index] }
    public subscript(bounds: Range<Int>) -> SubviewsCollectionSlice {
        SubviewsCollectionSlice(Array(children[bounds]))
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}

public struct SectionConfiguration: Identifiable {
    public struct ID: Hashable {
        let identity: AnyHashable
        let position: Int
        public static func == (a: SectionConfiguration.ID, b: SectionConfiguration.ID) -> Bool {
            a.identity == b.identity && a.position == b.position
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(identity)
            hasher.combine(position)
        }
        public var hashValue: Int { var hasher = Hasher(); hash(into: &hasher); return hasher.finalize() }
    }

    public struct Actions {
        var rowActions: [any View] = []
        init() {}
    }

    public let id: ID
    public let containerValues: ContainerValues
    public let header: SubviewsCollection
    public let footer: SubviewsCollection
    public let content: SubviewsCollection
    let actions: Actions
    init(id: ID, containerValues: ContainerValues, header: SubviewsCollection, footer: SubviewsCollection,
         content: SubviewsCollection, actions: Actions = Actions()) {
        self.id = id
        self.containerValues = containerValues
        self.header = header
        self.footer = footer
        self.content = content
        self.actions = actions
    }
}

public struct ForEachSubviewCollection<Content: View>: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<ForEachSubviewCollection>
    public typealias SubSequence = Slice<ForEachSubviewCollection>
    let children: [Subview]
    let content: (Subview) -> Content
    public init(_ children: SubviewsCollection, @ViewBuilder content: @escaping (Subview) -> Content) {
        self.init(children: Array(children), content: content)
    }
    init(children: [Subview], content: @escaping (Subview) -> Content) {
        self.children = children
        self.content = content
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { children.count }
    public subscript(index: Int) -> Subview { children[index] }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public var views: [Content] { children.map { content($0) } }
}

public struct GroupElementsOfContent<Subviews: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let subviews: Subviews
    let transformed: Content
    var childViews: [any View] { [subviews, transformed] }
}

extension ForEach where Content: View {
    public init<V: View>(subviews view: V, @ViewBuilder content: @escaping (Subview) -> Content)
        where Data == ForEachSubviewCollection<Content>, ID == Subview.ID {
        let identified = subviewChildren(of: view).map { Subview($0) }
        self.init(data: ForEachSubviewCollection(children: identified, content: content), id: \.id, content: content)
    }
}

extension Group {
    public init<Base: View, Result: View>(subviews view: Base,
                                          @ViewBuilder transform: @escaping (SubviewsCollection) -> Result)
        where Content == GroupElementsOfContent<Base, Result> {
        let collection = SubviewsCollection(subviewChildren(of: view).map { Subview($0) })
        self.init { GroupElementsOfContent(subviews: view, transformed: transform(collection)) }
    }
}

extension Section where Parent == EmptyView, Footer == EmptyView, Content == _SubviewGroup {
    public init(subviews: SubviewsCollection) {
        self.init(header: EmptyView(), content: _SubviewGroup(subviews: subviews), footer: EmptyView())
    }
}

public struct _SubviewGroup: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let subviews: SubviewsCollection
    public init(subviews: SubviewsCollection) { self.subviews = subviews }
    var childViews: [any View] { subviews.map { $0.content } }
}

func subviewChildren(of view: any View) -> [any View] {
    var current = view
    while true {
        if let group = current as? GroupView { return group.childViews }
        if let wrapped = current as? WrappedView { current = wrapped.wrapped; continue }
        if let modified = current as? ModifiedViewLike { current = modified.modifiedContent; continue }
        let body = current.bodyView
        if type(of: body) == type(of: current) { return [current] }
        current = body
    }
}

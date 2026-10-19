import Foundation
import FoundationEssentials
import FoundationInternationalization

public struct FetchDescriptor<T> where T: PersistentModel {
    public var predicate: Predicate<T>?

    public var sortBy: [SortDescriptor<T>]

    public var fetchLimit: Int?
    public var fetchOffset: Int?

    public var includePendingChanges: Bool

    public var propertiesToFetch: [PartialKeyPath<T>]

    public var relationshipKeyPathsForPrefetching: [PartialKeyPath<T>]

    public init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) {
        self.predicate = predicate
        self.sortBy = sortBy
        self.fetchLimit = nil
        self.fetchOffset = nil
        self.includePendingChanges = true
        self.propertiesToFetch = []
        self.relationshipKeyPathsForPrefetching = []
    }
}

extension FetchDescriptor: Equatable {
    public static func == (lhs: FetchDescriptor<T>, rhs: FetchDescriptor<T>) -> Bool {
        lhs.fetchLimit == rhs.fetchLimit && lhs.fetchOffset == rhs.fetchOffset
            && lhs.includePendingChanges == rhs.includePendingChanges
            && lhs.sortBy.map { "\($0.keyPath.map { "\($0)" } ?? "")" }
                == rhs.sortBy.map { "\($0.keyPath.map { "\($0)" } ?? "")" }
            && lhs.propertiesToFetch.map { "\($0)" } == rhs.propertiesToFetch.map { "\($0)" }
            && lhs.relationshipKeyPathsForPrefetching.map { "\($0)" }
                == rhs.relationshipKeyPathsForPrefetching.map { "\($0)" }
    }
}

extension FetchDescriptor: @unchecked Sendable {}

public struct FetchResultsCollection<Element>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<FetchResultsCollection<Element>>
    public typealias SubSequence = Slice<FetchResultsCollection<Element>>

    public var startIndex: Int { 0 }
    public var endIndex: Int { elements.count }
    public subscript(position: Int) -> Element { elements[position] }

    let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }
}

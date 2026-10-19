// What to read out of a store: which rows, in what order, how many.
//
// The predicate and the sort order are `Foundation.Predicate` and `Foundation.SortDescriptor`,
// which are the port's Foundation's once charon@swift-foundation is in the store: `Predicate`
// and `SortOrder` in FoundationEssentials, `SortDescriptor` in FoundationInternationalization
// (swift-foundation 6.4.0, 3b9d8f42b7923a7c1ae9ce20f3b05d1facac334e). Until that package is
// merged this module is typechecked against the Foundation band's own build of those two
// modules, read (not installed) from its worktree.

import Foundation
import FoundationEssentials
import FoundationInternationalization

public struct FetchDescriptor<T> where T: PersistentModel {
    /// Which rows. The store cannot turn a `Predicate` into an `NSPredicate`: the node types of
    /// `PredicateExpression` are internal to swift-foundation and `Predicate.evaluate(_:)` is the
    /// only public way to run one, so a fetch with a predicate reads its rows and filters them in
    /// memory, which is what `DataStoreError.preferInMemoryFilter` documents.
    public var predicate: Predicate<T>?

    /// The order, pushed into the store: a `SortDescriptor`'s key path is a `KeyPath`, and
    /// `AnyKeyPath._kvcKeyPathString` is the name Core Data's `NSSortDescriptor` sorts by, so
    /// the rows come back ordered by the store rather than by Swift.
    public var sortBy: [SortDescriptor<T>]

    /// How many rows to read, and how many to skip before the first. Both are the store's own
    /// limits, applied where the store applies them, and both are counted after the predicate has
    /// filtered, because the filtering happens here.
    public var fetchLimit: Int?
    public var fetchOffset: Int?

    /// Whether the rows this context has changed but not saved are in the answer. `true` is what
    /// `NSFetchRequest.includesPendingChanges` means, and the release has had it since iOS 3.0.
    public var includePendingChanges: Bool

    /// The properties to read: a row comes back with these, and the rest fault, which is what
    /// Core Data does with a row whose columns were not fetched.
    public var propertiesToFetch: [PartialKeyPath<T>]

    /// The relationships to bring in with the row.
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

/// A page of a fetch, so that a program can walk a store's rows without holding them all. A
/// `RandomAccessCollection` over one page, which is what it is.
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

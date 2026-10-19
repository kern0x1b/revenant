// What a store remembers of what was saved to it, iOS 18, over the Core Data history the
// backports carry (registry/CoreData/ios11.json: NSPersistentHistoryChangeRequest,
// NSPersistentHistoryToken, NSPersistentHistoryTransaction, NSPersistentHistoryChange,
// NSPersistentHistoryResult, NSPersistentHistoryTrackingKey, NSPersistentHistoryTokenKey,
// -[NSPersistentStoreCoordinator currentPersistentHistoryTokenFromStores:] and
// NSManagedObjectContext.transactionAuthor).
//
// A transaction is one save; a change is one row inside it; a token is where the reader is, and a
// tombstone is what a deleted row left behind so that a reader can still ask what it held.

import Foundation
import CoreData
import FoundationEssentials
import FoundationInternationalization

// This port's Foundation overlay and swift-foundation's FoundationEssentials both declare
// `Date`, and a file that imports both cannot say which it means. FoundationEssentials is the one
// that will be the port's Foundation once charon@swift-foundation is in the store, and it is the
// one whose values a store's rows are written as, so it is named at every use below.

// MARK: - The protocols

public protocol HistoryTransaction: Hashable, Identifiable, Sendable {
    associatedtype TokenType: Comparable, Hashable, Identifiable, Sendable
    associatedtype TransactionIdentifier: Comparable, Hashable, Sendable
    var timestamp: FoundationEssentials.Date { get }
    var changes: [HistoryChange] { get }
    var token: TokenType { get }
    var transactionIdentifier: TransactionIdentifier { get }
    var storeIdentifier: String { get }
    var author: String? { get }
}

public enum HistoryChange: Sendable {
    case insert(any HistoryInsert)
    case update(any HistoryUpdate)
    case delete(any HistoryDelete)

    /// The row the change is about, whichever of the three it is.
    public var changedPersistentIdentifier: PersistentIdentifier {
        switch self {
        case .insert(let change): return change.changedPersistentIdentifier
        case .update(let change): return change.changedPersistentIdentifier
        case .delete(let change): return change.changedPersistentIdentifier
        }
    }
}

public protocol HistoryInsert<Model>: Sendable {
    associatedtype Model: PersistentModel
    associatedtype TransactionIdentifier: Comparable, Hashable, Sendable
    associatedtype ChangeIdentifier: Comparable, Hashable, Sendable
    var changeIdentifier: ChangeIdentifier { get }
    var transactionIdentifier: TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
}

public protocol HistoryUpdate<Model>: Sendable {
    associatedtype Model: PersistentModel
    associatedtype TransactionIdentifier: Comparable, Hashable, Sendable
    associatedtype ChangeIdentifier: Comparable, Hashable, Sendable
    typealias PropertyUpdate = PartialKeyPath<Model> & Sendable
    var changeIdentifier: ChangeIdentifier { get }
    var transactionIdentifier: TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
    var updatedAttributes: [any PartialKeyPath<Model> & Sendable] { get }
}

public protocol HistoryDelete<Model>: Sendable {
    associatedtype Model: PersistentModel
    associatedtype TransactionIdentifier: Comparable, Hashable, Sendable
    associatedtype ChangeIdentifier: Comparable, Hashable, Sendable
    var changeIdentifier: ChangeIdentifier { get }
    var transactionIdentifier: TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
    var tombstone: HistoryTombstone<Model> { get }
}

public protocol HistoryToken: Comparable, Decodable, Encodable, Hashable, Identifiable, Sendable {
    associatedtype TokenType: Decodable, Encodable, Hashable, Sendable
    var tokenValue: TokenType? { get }
}

public protocol HistoryProviding {
    associatedtype HistoryType: HistoryTransaction
    static var historyType: Self.HistoryType.Type { get }
    func fetchHistory(_ descriptor: HistoryDescriptor<Self.HistoryType>) throws -> [Self.HistoryType]
    func deleteHistory(_ descriptor: HistoryDescriptor<Self.HistoryType>) throws
}

/// What a deleted row left behind, so that a reader can still ask what it held.
public struct HistoryTombstone<Model>: Sequence, @unchecked Sendable where Model: PersistentModel {
    public typealias Element = Any

    public struct Iterator: IteratorProtocol {
        public typealias Element = Any

        let values: [(String, Any)]
        var offset = 0

        public mutating func next() -> Any? {
            guard offset < values.count else { return nil }
            defer { offset += 1 }
            return values[offset]
        }
    }

    let values: [(String, Any)]

    public subscript(keyPath: PartialKeyPath<Model>) -> (any Sendable)? {
        guard let name = keyPath._kvcKeyPathString else { return nil }
        return StoredValue.box(values.first { $0.0 == name }?.1) ?? NSNull()
    }

    public func makeIterator() -> Iterator { Iterator(values: values) }
}

public struct HistoryDescriptor<TransactionType> where TransactionType: HistoryTransaction {
    /// How many transactions to read; zero is every one of them.
    public var fetchLimit: UInt64
    public var predicate: Predicate<TransactionType>?
    public var sortBy: [SortDescriptor<TransactionType>]

    public init(predicate: Predicate<TransactionType>? = nil, sortBy: [SortDescriptor<TransactionType>] = []) {
        self.fetchLimit = 0
        self.predicate = predicate
        self.sortBy = sortBy
    }
}

// MARK: - The default ones

public struct DefaultHistoryTransaction: HistoryTransaction {
    public typealias TransactionIdentifier = Int64
    public typealias TokenType = DefaultHistoryToken
    public typealias ID = Int64

    public var id: Int64 { transactionIdentifier }
    public let timestamp: FoundationEssentials.Date
    public let changes: [HistoryChange]
    public let token: DefaultHistoryToken
    public let transactionIdentifier: Int64
    public let storeIdentifier: String
    public let bundleIdentifier: String
    public let processIdentifier: String
    public let author: String?

    public static func == (lhs: DefaultHistoryTransaction, rhs: DefaultHistoryTransaction) -> Bool {
        lhs.transactionIdentifier == rhs.transactionIdentifier && lhs.storeIdentifier == rhs.storeIdentifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(transactionIdentifier)
        hasher.combine(storeIdentifier)
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

public struct DefaultHistoryInsert<Model>: HistoryInsert where Model: PersistentModel {
    public typealias TransactionIdentifier = Int64
    public typealias ChangeIdentifier = Int64

    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier

    public static func == (lhs: DefaultHistoryInsert<Model>, rhs: DefaultHistoryInsert<Model>) -> Bool {
        lhs.changeIdentifier == rhs.changeIdentifier
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier) }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

public struct DefaultHistoryUpdate<Model>: HistoryUpdate where Model: PersistentModel {
    public typealias TransactionIdentifier = Int64
    public typealias ChangeIdentifier = Int64
    public typealias PropertyUpdate = PartialKeyPath<Model> & Sendable

    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier
    public let updatedAttributes: [any PartialKeyPath<Model> & Sendable]

    public static func == (lhs: DefaultHistoryUpdate<Model>, rhs: DefaultHistoryUpdate<Model>) -> Bool {
        lhs.changeIdentifier == rhs.changeIdentifier
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier) }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

public struct DefaultHistoryDelete<Model>: HistoryDelete where Model: PersistentModel {
    public typealias TransactionIdentifier = Int64
    public typealias ChangeIdentifier = Int64

    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier
    public let tombstone: HistoryTombstone<Model>

    public static func == (lhs: DefaultHistoryDelete<Model>, rhs: DefaultHistoryDelete<Model>) -> Bool {
        lhs.changeIdentifier == rhs.changeIdentifier
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier) }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

public struct DefaultHistoryToken: HistoryToken, Comparable, Codable {
    public typealias TokenType = [String: Int64]
    public typealias ID = Int

    /// Where the reader is, per store: the transaction number the store has reached. Apple's token
    /// value has this shape, and a token is this shape because it is the whole of what a history
    /// fetch can be resumed from.
    public var tokenValue: [String: Int64]?

    public var id: Int { Int(tokenValue?.values.max() ?? 0) }

    public init(tokenValue: [String: Int64]? = nil) {
        self.tokenValue = tokenValue
    }

    public init(from decoder: any Decoder) throws {
        self.tokenValue = try decoder.singleValueContainer().decode([String: Int64].self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(tokenValue ?? [:])
    }

    public static func == (lhs: DefaultHistoryToken, rhs: DefaultHistoryToken) -> Bool {
        lhs.tokenValue == rhs.tokenValue
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(tokenValue) }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    public static func < (lhs: DefaultHistoryToken, rhs: DefaultHistoryToken) -> Bool {
        lhs.id < rhs.id
    }
}

// The identity a store gives one of its rows.
//
// Apple's ID is opaque and, in their store, a UUID. Here the store is Core Data, whose identity
// is the NSManagedObjectID, and that is what an ID carries: a permanent objectID for a row of
// one store, resolved through that store's coordinator. Decoding needs no store, because
// NSManagedObjectID's -URIRepresentation is self-contained (CoreData, iOS 5.0), and a decoded
// identifier names a store that the decoder's process may not have loaded - which is exactly
// what an identifier that arrived over the wire is.

import Foundation
import CoreData

public struct PersistentIdentifier: Hashable, Identifiable, Equatable, Comparable, Codable, Sendable {
    public struct ID: Hashable, Equatable, Sendable {
        /// The row's permanent objectID, when the store that made it is here to resolve one.
        /// An NSManagedObjectID is immutable once made and Core Data answers hash/isEqual for it,
        /// so it is safe to hand between the threads a ModelContext is used from - which is what
        /// Sendable on the identifier promises.
        let object: NSManagedObjectID?

        /// The row's own URI form, which is what an identifier keeps and what it is compared and
        /// hashed by: it names the store as well as the row, so an identifier that arrived from
        /// another process says which store it belongs to without a coordinator to ask.
        let uri: URL

        init(_ object: NSManagedObjectID) {
            self.object = object
            self.uri = object.uriRepresentation()
        }

        init(uri: URL) {
            self.object = nil
            self.uri = uri
        }

        public static func == (lhs: ID, rhs: ID) -> Bool {
            if let left = lhs.object, let right = rhs.object {
                return left.isEqual(right)
            }
            return lhs.uri == rhs.uri
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }
    }

    public let id: ID
    public var entityName: String { name }
    public var storeIdentifier: String? { store }

    let name: String
    let store: String?

    public init(_ object: NSManagedObjectID, entityName: String) {
        self.id = ID(object)
        self.name = entityName
        self.store = object.persistentStore?.url?.lastPathComponent
    }

    init(uri: URL, entityName: String) {
        self.id = ID(uri: uri)
        self.name = entityName
        self.store = uri.lastPathComponent
    }

    /// The store's own naming of a row, for a store that is not Core Data: the primary key's
    /// value, as a string, together with the entity it names.
    public static func identifier<T>(for storeIdentifier: String, entityName: String,
                                     primaryKey: T) throws -> PersistentIdentifier
    where T: Comparable, T: CustomStringConvertible, T: Decodable, T: Encodable, T: Hashable {
        guard let url = URL(string: "\(storeIdentifier)") else {
            throw SwiftDataError.unknownSchema
        }
        return PersistentIdentifier(uri: url, entityName: entityName)
    }

    public static func == (lhs: PersistentIdentifier, rhs: PersistentIdentifier) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.store == rhs.store
    }

    // Two identifiers of one store are ordered by the row's place in it, which Core Data answers
    // with the objectID's own -compare:; identifiers of different stores are ordered by the store
    // name, so the order is total and stable rather than undefined.
    public static func < (lhs: PersistentIdentifier, rhs: PersistentIdentifier) -> Bool {
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        if lhs.store != rhs.store { return (lhs.store ?? "") < (rhs.store ?? "") }
        return lhs.id.uri.absoluteString < rhs.id.uri.absoluteString
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(store)
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    private enum CodingKeys: String, CodingKey {
        case entityName, storeIdentifier, uri
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .entityName)
        try container.encodeIfPresent(store, forKey: .storeIdentifier)
        try container.encode(id.uri, forKey: .uri)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .entityName)
        self.store = try container.decodeIfPresent(String.self, forKey: .storeIdentifier)
        self.id = ID(uri: try container.decode(URL.self, forKey: .uri))
    }
}

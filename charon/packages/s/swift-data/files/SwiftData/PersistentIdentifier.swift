import Foundation
import CoreData

public struct PersistentIdentifier: Hashable, Identifiable, Equatable, Comparable, Codable, Sendable {
    public struct ID: Hashable, Equatable, Sendable {
        let object: NSManagedObjectID?

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

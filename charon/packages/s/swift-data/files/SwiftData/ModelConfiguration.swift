// Where a store keeps itself: which file, whose container it is shared through, and what it
// mirrors.

import Foundation
import CoreData

public struct ModelConfiguration: Identifiable, Hashable, @unchecked Sendable {
    /// A group container is either "the one the bundle's entitlements name", named by hand, or
    /// none. `automatic` and a named container are different answers and are kept apart, because
    /// a store in the wrong container is a store another process cannot see.
    public struct GroupContainer: Hashable, Sendable {
        enum Choice: Hashable { case automatic, none, identifier(String) }

        let choice: Choice

        public static var automatic: GroupContainer { GroupContainer(choice: .automatic) }
        public static var none: GroupContainer { GroupContainer(choice: .none) }
        public static func identifier(_ groupName: String) -> GroupContainer {
            GroupContainer(choice: .identifier(groupName))
        }

        /// The container's identifier, when one was named. `automatic` reads the bundle's
        /// entitlements, which is where the name of the automatic group is written down.
        public var identifier: String? {
            switch choice {
            case .automatic: return ModelConfiguration.bundleGroupContainerIdentifier()
            case .none: return nil
            case .identifier(let name): return name
            }
        }
    }

    /// What a store mirrors. `private(_:)` names the CloudKit container the store mirrors into;
    /// `none` says it mirrors nothing; `automatic` says the store mirrors into the container the
    /// bundle's own identifier names.
    public struct CloudKitDatabase: Hashable, Sendable {
        enum Choice: Hashable { case automatic, none, privateDatabase(String) }

        let choice: Choice

        public static var automatic: CloudKitDatabase { CloudKitDatabase(choice: .automatic) }
        public static var none: CloudKitDatabase { CloudKitDatabase(choice: .none) }
        public static func `private`(_ privateDBName: String) -> CloudKitDatabase {
            CloudKitDatabase(choice: .privateDatabase(privateDBName))
        }

        /// The container identifier this configuration names, or nil when it names none. It is
        /// what `cloudKitContainerIdentifier` answers, and what the store description is built
        /// from.
        public var identifier: String? {
            switch choice {
            case .automatic: return nil
            case .none: return nil
            case .privateDatabase(let name): return name
            }
        }
    }

    public let url: URL
    public let name: String
    public let groupAppContainerIdentifier: String?
    public let cloudKitContainerIdentifier: String?
    public let groupContainer: GroupContainer
    public let cloudKitDatabase: CloudKitDatabase
    public var schema: Schema?
    public let allowsSave: Bool
    public let isStoredInMemoryOnly: Bool

    public typealias ID = URL

    public init(isStoredInMemoryOnly: Bool = false) {
        self.init(nil, schema: nil, isStoredInMemoryOnly: isStoredInMemoryOnly)
    }

    public init(for forTypes: any PersistentModel.Type..., isStoredInMemoryOnly: Bool = false) {
        self.init(nil, schema: Schema(forTypes, version: .init(1, 0, 0)), isStoredInMemoryOnly: isStoredInMemoryOnly)
    }

    public init(_ name: String? = nil, schema: Schema? = nil, isStoredInMemoryOnly: Bool = false,
                allowsSave: Bool = true, groupContainer: GroupContainer = .automatic,
                cloudKitDatabase: CloudKitDatabase = .automatic) {
        self.name = name ?? "default"
        self.schema = schema
        self.allowsSave = allowsSave
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
        self.groupContainer = groupContainer
        self.groupAppContainerIdentifier = groupContainer.identifier
        self.cloudKitDatabase = cloudKitDatabase
        self.cloudKitContainerIdentifier = cloudKitDatabase.identifier
        self.url = ModelConfiguration.locate(name: self.name, inMemoryOnly: isStoredInMemoryOnly,
                                             groupAppContainerIdentifier: groupContainer.identifier)
    }

    public init(_ name: String? = nil, schema: Schema? = nil, url: URL, allowsSave: Bool = true,
                cloudKitDatabase: CloudKitDatabase = .automatic) {
        self.name = name ?? url.lastPathComponent
        self.schema = schema
        self.allowsSave = allowsSave
        self.isStoredInMemoryOnly = false
        self.groupContainer = .none
        self.groupAppContainerIdentifier = nil
        self.cloudKitDatabase = cloudKitDatabase
        self.cloudKitContainerIdentifier = cloudKitDatabase.identifier
        self.url = url
    }

    public var id: URL { url }

    /// The file a store of this name is kept in. A store in a group container is inside that
    /// container - which is what makes it visible to the processes that share it - and a store
    /// that names none is in the app's own Application Support, where a store of its own belongs.
    static func locate(name: String, inMemoryOnly: Bool, groupAppContainerIdentifier: String?) -> URL {
        if inMemoryOnly { return URL(fileURLWithPath: "/dev/null") }
        let manager = FileManager.default
        if let group = groupAppContainerIdentifier, let shared = manager.containerURL(
            forSecurityApplicationGroupIdentifier: group) {
            return shared.appendingPathComponent(name).appendingPathExtension("store")
        }
        let support = (try? manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                                        create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent(name).appendingPathExtension("store")
    }

    /// The group container the bundle's own entitlements name, which is what `.automatic` means
    /// and the only place a program can learn it without writing it down twice.
    static func bundleGroupContainerIdentifier() -> String? {
        (Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String).map { _ in
            Bundle.main.object(forInfoDictionaryKey: "GroupContainers") as? [[String: Any]] ?? []
        }.flatMap { $0.first?["identifier"] as? String }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(name)
        hasher.combine(groupAppContainerIdentifier)
        hasher.combine(cloudKitContainerIdentifier)
        hasher.combine(allowsSave)
        hasher.combine(isStoredInMemoryOnly)
    }

    public static func == (lhs: ModelConfiguration, rhs: ModelConfiguration) -> Bool {
        lhs.url == rhs.url && lhs.name == rhs.name
            && lhs.groupAppContainerIdentifier == rhs.groupAppContainerIdentifier
            && lhs.cloudKitContainerIdentifier == rhs.cloudKitContainerIdentifier
            && lhs.allowsSave == rhs.allowsSave && lhs.isStoredInMemoryOnly == rhs.isStoredInMemoryOnly
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

extension ModelConfiguration: CustomDebugStringConvertible {
    public var debugDescription: String {
        "ModelConfiguration(\(name) at \(url.path)"
            + (groupAppContainerIdentifier.map { ", group \($0)" } ?? "")
            + (cloudKitContainerIdentifier.map { ", cloud \($0)" } ?? "")
            + (isStoredInMemoryOnly ? ", in memory" : "") + ")"
    }
}

extension ModelConfiguration: DataStoreConfiguration {
    public typealias Store = DefaultStore

    /// What a configuration has to answer for before a store is opened from it: a name a file
    /// system takes, a schema the container has, and a file a container can be written into.
    public func validate() throws {
        if name.isEmpty { throw SwiftDataError.configurationFileNameContainsInvalidCharacters }
        if name.utf8.count > 255 { throw SwiftDataError.configurationFileNameTooLong }
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        if name.rangeOfCharacter(from: illegal) != nil {
            throw SwiftDataError.configurationFileNameContainsInvalidCharacters
        }
        guard let schema else { return }
        for entity in schema.entities {
            if entity.attributes.contains(where: { $0.defaultValue == nil && $0.isOptional })
                && entity.relationships.isEmpty && entity.attributes.isEmpty {
                throw SwiftDataError.modelValidationFailure
            }
        }
    }
}

extension DataStoreConfiguration {
    /// The default: a configuration with no schema of its own is a configuration of whatever
    /// schema the container it is given to holds.
    public func validate() throws {}
}

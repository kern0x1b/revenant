// The declarative description of a store: what a program says its rows are, which is what a
// store is opened from, what a migration compares, and what a model file is read back into.
//
// Schema is a class, as Apple's is: a container, a context and a model share one description
// rather than copies of it. It is Codable, so a schema is a file a build writes and a version
// control keeps.

import Foundation

public final class Schema: Codable, Hashable {
    /// The version a written schema carries. Apple's is 1; a schema read from a file that says
    /// something else is refused, which is the whole point of writing the version down.
    public static let schemaEncodingVersion = Version(1, 0, 0)

    public let encodingVersion: Version
    public let version: Version
    public let entities: [Entity]
    public let entitiesByName: [String: Entity]

    public init() {
        self.encodingVersion = Schema.schemaEncodingVersion
        self.version = Version(0, 0, 0)
        self.entities = []
        self.entitiesByName = [:]
    }

    public convenience init(_ entities: Entity..., version: Version = Version(1, 0, 0)) {
        self.init(entities, version: version)
    }

    /// The designated form the variadic initialiser above calls. Apple's interface declares only
    /// the variadic one, so this is internal: a caller with a list calls it with `...`.
    init(_ entities: [Entity], version: Version = Version(1, 0, 0)) {
        self.encodingVersion = Schema.schemaEncodingVersion
        self.version = version
        self.entities = entities
        self.entitiesByName = Schema.index(entities)
        for entity in entities {
            entity.schema = self
            for subentity in entity.subentities { subentity.schema = self }
        }
    }

    /// The schema of a set of model types, which is what `@Model` writes into `schemaMetadata`
    /// and what this reads back: one entity per type, named after the type, holding the
    /// properties the macro recorded.
    public convenience init(_ types: [any PersistentModel.Type], version: Version = Version(1, 0, 0)) {
        self.init(types.map { Entity($0) }, version: version)
    }

    public convenience init(_ types: any PersistentModel.Type..., version: Version = Version(1, 0, 0)) {
        self.init(types, version: version)
    }

    public convenience init(versionedSchema: any VersionedSchema.Type) {
        self.init(versionedSchema.models, version: versionedSchema.versionIdentifier)
    }

    private static func index(_ entities: [Entity]) -> [String: Entity] {
        var byName = [String: Entity](minimumCapacity: entities.count)
        for entity in entities {
            byName[entity.name] = entity
            for subentity in entity.subentities { byName[subentity.name] = subentity }
        }
        return byName
    }

    // MARK: The entity

    public final class Entity: Codable, Hashable, CustomDebugStringConvertible {
        public var name: String
        public var subentities: Set<Entity>
        public var superentityName: String?
        public var storedProperties: [any SchemaProperty]
        public var inheritedProperties: [any SchemaProperty]

        /// The schema that holds this entity, so `superentity` can be answered without a second
        /// copy of the entity list. Weak, because a schema holds its entities and an entity must
        /// not keep the schema alive.
        weak var schema: Schema?

        public var superentity: Entity? {
            get { superentityName.flatMap { schema?.entitiesByName[$0] } }
            set { superentityName = newValue?.name }
        }

        /// Everything a store holds: what this entity declares and what it inherits.
        public var properties: [any SchemaProperty] { storedProperties + inheritedProperties }

        public var attributes: Set<Attribute> {
            Set(storedProperties.compactMap { $0 as? Attribute })
        }

        public var relationships: Set<Relationship> {
            Set(storedProperties.compactMap { $0 as? Relationship })
        }

        public var attributesByName: [String: Attribute] {
            Dictionary(attributes.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        }

        public var relationshipsByName: [String: Relationship] {
            Dictionary(relationships.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        }

        public var storedPropertiesByName: [String: any SchemaProperty] {
            Dictionary(storedProperties.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        }

        public var inheritedPropertiesByName: [String: any SchemaProperty] {
            Dictionary(inheritedProperties.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        }

        /// The indexes, as the property names each one is built over: what
        /// `NSEntityDescription.indexes` takes, and what the store builds.
        public var indices: [[String]] {
            storedProperties.flatMap { ($0 as? any IndexNaming)?.indexPropertyNames ?? [] }
        }

        /// The uniqueness constraints, as the property names each one names. The store of the
        /// port cannot enforce them - `NSEntityDescription.uniquenessConstraints` is registered
        /// `absent` for iOS 6, its reason being that a constraint nothing enforces would let in
        /// the duplicates the model says cannot exist - so `ModelContext.save` checks them itself.
        public var uniquenessConstraints: [[String]] {
            storedProperties.flatMap { ($0 as? any UniqueNaming)?.uniquePropertyNames ?? [] }
        }

        public init(_ name: String) {
            self.name = name
            self.subentities = []
            self.superentityName = nil
            self.storedProperties = []
            self.inheritedProperties = []
        }

        public convenience init(_ name: String, subentities: Entity..., properties: any SchemaProperty...) {
            self.init(name, subentities: subentities, properties: properties)
        }

        public convenience init(_ name: String, properties: any SchemaProperty...) {
            self.init(name, subentities: [Entity](), properties: properties)
        }

        /// The designated form the two variadic initialisers above call. Apple's interface
        /// declares only the variadic ones, so this is internal: a caller holds a list and wants
        /// one entity out of it, the variadic initialiser takes it with `...`.
        init(_ name: String, subentities: [Entity], properties: [any SchemaProperty]) {
            self.name = name
            self.subentities = Set(subentities)
            self.superentityName = nil
            self.storedProperties = properties
            self.inheritedProperties = []
            for subentity in subentities {
                subentity.schema = schema
                subentity.superentityName = name
            }
        }

        /// The entity a model type is stored as, with the properties its macro recorded. The
        /// order is the order the macro wrote, which is the order the source declared them in:
        /// a store's columns are made in that order and a migration compares them in that order.
        public convenience init(_ modelType: any PersistentModel.Type) {
            self.init(Schema.entityName(for: modelType))
            storedProperties = modelType.schemaMetadata.map { entry in
                entry.metadata ?? Attribute(name: entry.name, originalName: entry.name,
                                            options: [], valueType: Any.self,
                                            defaultValue: entry.defaultValue)
            }
        }

        public static func == (lhs: Entity, rhs: Entity) -> Bool {
            lhs.name == rhs.name && lhs.superentityName == rhs.superentityName
                && lhs.subentities.map { $0.name } == rhs.subentities.map { $0.name }
                && Schema.Fingerprint.of(lhs.storedProperties) == Schema.Fingerprint.of(rhs.storedProperties)
                && Schema.Fingerprint.of(lhs.inheritedProperties) == Schema.Fingerprint.of(rhs.inheritedProperties)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(superentityName)
            hasher.combine(subentities.map { $0.name })
            for property in storedProperties { hasher.combine(property) }
            for property in inheritedProperties { hasher.combine(property) }
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }

        public var debugDescription: String {
            "Entity(\(name): \(properties.map { $0.name }.joined(separator: ", ")))"
        }

        private enum CodingKeys: String, CodingKey {
            case name, superentityName, subentities, storedProperties, inheritedProperties
        }

        public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.superentityName = try container.decodeIfPresent(String.self, forKey: .superentityName)
            self.subentities = Set(try container.decodeIfPresent([Entity].self, forKey: .subentities) ?? [])
            self.storedProperties = try container.decodeIfPresent([StoredProperty].self, forKey: .storedProperties)?
                .map { $0.property } ?? []
            self.inheritedProperties = try container.decodeIfPresent([StoredProperty].self, forKey: .inheritedProperties)?
                .map { $0.property } ?? []
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(superentityName, forKey: .superentityName)
            try container.encode(subentities.sorted { $0.name < $1.name }, forKey: .subentities)
            try container.encode(storedProperties.map { StoredProperty($0) }, forKey: .storedProperties)
            try container.encode(inheritedProperties.map { StoredProperty($0) }, forKey: .inheritedProperties)
        }
    }

    // MARK: What one model's property is

    /// What a model's property is: the name, the key path that reaches it, the value it starts
    /// as, and the schema property the macro built for it. This is what `@Model` writes and what
    /// `Schema` reads, so a model type says its own shape with no `.xcdatamodeld` beside it.
    public struct PropertyMetadata {
        public let name: String
        public let keypath: AnyKeyPath
        public let defaultValue: Any?
        public let metadata: (any SchemaProperty)?

        public init(name: String, keypath: AnyKeyPath, defaultValue: Any? = nil,
                    metadata: (any SchemaProperty)? = nil) {
            self.name = name
            self.keypath = keypath
            self.defaultValue = defaultValue
            self.metadata = metadata
        }
    }

    // MARK: The version

    public struct Version: Codable, Comparable, CustomStringConvertible, Hashable {
        public let major: Int
        public let minor: Int
        public let patch: Int

        public init(_ major: Int, _ minor: Int, _ patch: Int) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }

        public static func == (lhs: Version, rhs: Version) -> Bool {
            !(lhs < rhs) && !(lhs > rhs)
        }

        public static func < (lhs: Version, rhs: Version) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }

        public var description: String { "\(major).\(minor).\(patch)" }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let parts = try container.decode(String.self).split(separator: ".", maxSplits: 2).map { Int($0) ?? 0 }
            self.major = parts.count > 0 ? parts[0] : 0
            self.minor = parts.count > 1 ? parts[1] : 0
            self.patch = parts.count > 2 ? parts[2] : 0
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(major)
            hasher.combine(minor)
            hasher.combine(patch)
        }

        public var hashValue: Int {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }
    }

    // MARK: Identity and the file

    public static func == (lhs: Schema, rhs: Schema) -> Bool {
        lhs.entities == rhs.entities && lhs.version == rhs.version && lhs.encodingVersion == rhs.encodingVersion
    }

    public func hash(into hasher: inout Hasher) {
        for entity in entities { hasher.combine(entity) }
        hasher.combine(version)
        hasher.combine(encodingVersion)
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    /// The entity a model type is stored as, or nil where this schema has none: a model type the
    /// schema does not name cannot be read from or written to this store, and nil says so.
    public final func entity<T>(for type: T.Type) -> Entity? where T: PersistentModel {
        entitiesByName[Schema.entityName(for: type)]
    }

    public static func entityName<T>(for type: T.Type) -> String where T: PersistentModel {
        "\(type)"
    }

    public final func save(to toURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(self).write(to: toURL)
    }

    public static func load(from fromURL: URL) throws -> Schema {
        try JSONDecoder().decode(Schema.self, from: try Data(contentsOf: fromURL))
    }

    private enum CodingKeys: String, CodingKey {
        case version, encodingVersion, entities
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entities = try container.decode([Entity].self, forKey: .entities)
        self.version = try container.decode(Version.self, forKey: .version)
        self.encodingVersion = try container.decodeIfPresent(Version.self, forKey: .encodingVersion)
            ?? Schema.schemaEncodingVersion
        self.entitiesByName = Schema.index(entities)
        for entity in entities {
            entity.schema = self
            for subentity in entity.subentities { subentity.schema = self }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(encodingVersion, forKey: .encodingVersion)
        try container.encode(entities, forKey: .entities)
    }
}

extension Schema {
    /// What a property list is, as text. An entity holds `[any SchemaProperty]`, and an
    /// existential of a `Hashable` protocol is not itself `Hashable`, so a list of them is
    /// compared and hashed through this: every member of every kind, in one place, so that two
    /// entities are equal exactly when they say the same things.
    enum Fingerprint {
        static func of(_ properties: [any SchemaProperty]) -> String {
            properties.map(one).joined(separator: "|")
        }

        private static func one(_ property: any SchemaProperty) -> String {
            switch property {
            case let attribute as CompositeAttribute:
                return "composite(\(attribute.name), \(attribute.originalName), \(attribute.options), " +
                    "\(attribute.valueType), \(String(describing: attribute.defaultValue)), " +
                    "\(attribute.hashModifier ?? "")){\(of(attribute.properties))}"
            case let attribute as Attribute:
                return "attribute(\(attribute.name), \(attribute.originalName), \(attribute.options), " +
                    "\(attribute.valueType), \(String(describing: attribute.defaultValue)), " +
                    "\(attribute.hashModifier ?? ""))"
            case let relationship as Relationship:
                return "relationship(\(relationship.name), \(relationship.originalName), \(relationship.options), " +
                    "\(relationship.valueType), \(relationship.destination), \(relationship.deleteRule), " +
                    "\(relationship.inverseName ?? ""), \(relationship.minimumModelCount.map(String.init) ?? ""), " +
                    "\(relationship.maximumModelCount.map(String.init) ?? ""), \(relationship.hashModifier ?? ""))"
            case let index as any IndexNaming:
                return "index(\(index.indexPropertyNames))"
            case let unique as any UniqueNaming:
                return "unique(\(unique.uniquePropertyNames))"
            default:
                return "\(property.name)"
            }
        }
    }
}

extension Schema: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Schema(\(version), \(entities.map { $0.name }))"
    }
}

extension Schema: @unchecked Sendable {}

/// One entry of a schema entity's property list, written with the kind of property it is: the
/// list holds four kinds side by side, and an array of existentials has no `Encodable` of its
/// own. This is the one place a schema's written form is ours - Apple's own is not published, and
/// a file this package writes is read by this package.
enum StoredProperty: Codable {
    case attribute(Schema.Attribute)
    case composite(Schema.CompositeAttribute)
    case relationship(Schema.Relationship)
    case index([String])
    case unique([[String]])

    init(_ property: any SchemaProperty) {
        switch property {
        case let attribute as Schema.CompositeAttribute: self = .composite(attribute)
        case let attribute as Schema.Attribute: self = .attribute(attribute)
        case let relationship as Schema.Relationship: self = .relationship(relationship)
        case let index as any IndexNaming: self = .index(index.indexPropertyNames.flatMap { $0 })
        case let unique as any UniqueNaming: self = .unique(unique.uniquePropertyNames)
        default: self = .index([property.name])
        }
    }

    var property: any SchemaProperty {
        switch self {
        case .attribute(let value): return value
        case .composite(let value): return value
        case .relationship(let value): return value
        case .index(let names): return IndexNames(name: names.joined(separator: "+"), valueType: [String].self, indices: names)
        case .unique(let names): return UniqueNames(name: names.map { $0.joined(separator: "+") }.joined(separator: "|"),
                                                  valueType: [[String]].self, constraints: names)
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, value, indices, constraints }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "attribute": self = .attribute(try Schema.Attribute(from: decoder))
        case "composite": self = .composite(try Schema.CompositeAttribute(from: decoder))
        case "relationship": self = .relationship(try Schema.Relationship(from: decoder))
        case "unique": self = .unique(try container.decode([[String]].self, forKey: .constraints))
        default: self = .index(try container.decode([String].self, forKey: .indices))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .attribute(let value):
            try container.encode("attribute", forKey: .kind)
            try value.encode(to: encoder)
        case .composite(let value):
            try container.encode("composite", forKey: .kind)
            try value.encode(to: encoder)
        case .relationship(let value):
            try container.encode("relationship", forKey: .kind)
            try value.encode(to: encoder)
        case .index(let names):
            try container.encode("index", forKey: .kind)
            try container.encode(names, forKey: .indices)
        case .unique(let names):
            try container.encode("unique", forKey: .kind)
            try container.encode(names, forKey: .constraints)
        }
    }
}

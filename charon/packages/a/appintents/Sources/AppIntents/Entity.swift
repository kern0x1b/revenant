// Entities and enums: what a parameter can carry that the app names, and the queries that find it.
//
// An `AppEntity` is a value the app can be asked about; an `AppEnum` is a closed set of cases. Both
// are `Identifiable` and both are shown through their display representation. The queries are the
// app's own: the framework calls `entities(for:)` and `suggestedEntities()` and the app answers.

import Foundation

/// An entity: a thing the app can be asked about, which a parameter carries and a query finds.
public protocol AppEntity: AppValue, DisplayRepresentable, Identifiable
    where ValueType == Self, ID: EntityIdentifierConvertible {
    /// The query that finds the entity when a caller names it, which is the entity's own query.
    associatedtype DefaultQuery: EntityQuery where DefaultQuery.Entity == Self

    /// The property of an entity an intent is asked about, which is a parameter of the entity.
    typealias Property = EntityProperty<Self>

    /// The query that finds this entity when a caller names it, which is the entity's own query.
    /// A requirement, not a convenience, so that `MyEntity.defaultQuery` is one thing whatever the
    /// query is; the framework's own declaration carries it and supplies a default only where a
    /// conformance may have one (`arm64e-apple-macos.swiftinterface:413-416`).
    static var defaultQuery: Self.DefaultQuery { get }
}

/// The resolver specification an entity of this kind is asked through, which is the
/// framework's own default. It is an `extension AppEntity` member and not a requirement
/// (`arm64e-apple-macos.swiftinterface:423-425`), so a port that declares it on individual
/// types is writing a different thing: the framework gives *every* entity this, and a
/// conformance that wants another specification names its own beside it.
extension AppEntity {
    public static var defaultResolverSpecification: EmptyResolverSpecification<Self> {
        return EmptyResolverSpecification()
    }
}

/// An enum: a closed set of cases the app names, which a parameter carries.
public protocol AppEnum: AppValue, StaticDisplayRepresentable, RawRepresentable where RawValue: LosslessStringConvertible {}

/// A value that can be written as the string an entity identifier is, which is what the framework
/// needs to key an entity, a donation and a search result by the same value.
public protocol EntityIdentifierConvertible {
    /// The string this value is keyed by, which is the value itself written out.
    var entityIdentifierString: String { get }
    /// The value the string names, or nothing when the string is not one of them.
    static func entityIdentifier(for entityIdentifierString: String) -> Self?
}

extension EntityIdentifierConvertible where Self: LosslessStringConvertible {
    public var entityIdentifierString: String { return description }

    public static func entityIdentifier(for entityIdentifierString: String) -> Self? {
        return Self(entityIdentifierString)
    }
}

/// The identifier of an entity: the string the entity is keyed by, and the type of entity it names.
public struct EntityIdentifier: Hashable, Sendable, CustomStringConvertible {
    /// The string the entity is keyed by.
    public let identifier: String
    /// The name of the type of entity it names, which is what tells two identifiers apart.
    public let entityType: String

    public init(for identifier: String) {
        self.identifier = identifier
        self.entityType = ""
    }

    public init<Identifier>(for value: Identifier, identifier: String) where Identifier: LosslessStringConvertible {
        self.identifier = identifier
        self.entityType = CharonNames.simple(Identifier.self)
    }

    /// An identifier read back from a resumed activity, which is the framework's own reading of the
    /// string an activity carries; a string that is not an identifier is not one.
    public init?(activityIdentifier: String) {
        self.init(for: activityIdentifier)
    }

    /// The identifier of a value, when the value is one the framework can write.
    public init<Identifier>(for value: Identifier) where Identifier: LosslessStringConvertible {
        self.identifier = value.description
        self.entityType = CharonNames.simple(Identifier.self)
    }

    public var description: String { return identifier }

    /// The length an identifier of a file is limited to, which the framework's own limit is.
    public var valueMaximumLength: Int? { return nil }

    public static var defaultResolverSpecification: EmptyResolverSpecification<EntityIdentifier> {
        return EmptyResolverSpecification()
    }
}

extension EntityIdentifier: _IntentValue {
    public typealias ValueType = EntityIdentifier
    public typealias UnwrappedType = EntityIdentifier
    public typealias Specification = EmptyResolverSpecification<EntityIdentifier>
}

/// The query that finds an entity by the identifiers the caller gave, and offers the ones it suggests.
public protocol EntityQuery: DynamicOptionsProvider, PersistentlyIdentifiable, Sendable {
    associatedtype Entity: AppEntity
    associatedtype Result: ResultsCollection = [Entity] where Result.Result == Entity
    init()
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity]
    func suggestedEntities() async throws -> Result
}

extension EntityQuery {
    /// The entities the query suggests when the caller named none: every one the query has, which is
    /// what the framework's own default is.
    public func suggestedEntities() async throws -> Result {
        return try await results()
    }

    /// The entities the query has, which is the list the caller chooses from.
    public func results() async throws -> Result {
        return try await suggestedEntities()
    }
}

/// A query that can list every entity it has, which is what a picker of entities is built on.
public protocol EnumerableEntityQuery: EntityQuery {
    func allEntities() async throws -> Result
    /// What the framework shows above the list, which is what the app wrote.
    var findIntentDescription: IntentDescription? { get }
}

extension EnumerableEntityQuery {
    public var findIntentDescription: IntentDescription? { return nil }

    /// The entities an enumerable query suggests when the caller named none: every one it has, which
    /// is what the framework's own default is.
    public func suggestedEntities() async throws -> Result {
        return try await allEntities()
    }
}

/// A query whose entities are found by a string the caller wrote.
public protocol EntityStringQuery: EntityQuery {
    func entities(matching string: String) async throws -> [Entity]
}

/// A query of a type whose raw value is its own identifier, which is what an `AppEnum` needs.
public struct _RawRepresentableStringQuery<Entity>: EntityStringQuery
    where Entity: AppEntity, Entity: RawRepresentable, Entity.ID == Entity.RawValue {
    public typealias Result = [Entity]
    public typealias DefaultValue = [Entity].Result
    public typealias Item = Entity
    public typealias ItemCollection = [Entity]
    public typealias ItemSection = [Entity]

    public init() {}

    public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        return identifiers.compactMap { identifier in Entity(rawValue: identifier) }
    }

    /// The entity whose own value is the identifier the caller gave, which is what a raw-representable
    /// entity's own case is.
    public static func entity(for identifier: Entity.ID) -> Entity? {
        return Entity(rawValue: identifier)
    }

    public func results() async throws -> [Entity] {
        return try await suggestedEntities()
    }

    public func defaultResult() async throws -> [Entity] {
        return try await results()
    }

    public func entities(matching string: String) async throws -> [Entity] {
        guard let raw: Entity.RawValue = CharonIntentValueParser.parse(string, as: Entity.RawValue.self) else {
            return []
        }
        let one: Entity? = Entity(rawValue: raw)
        return one.map { [$0] } ?? []
    }

    public func suggestedEntities() async throws -> [Entity] {
        return []
    }
}

/// An entity the app makes as the caller speaks, which is not stored and not indexed.
public protocol TransientAppEntity: AppEntity {}

extension TransientAppEntity {
    /// A transient entity is made by the app as the caller speaks, not by the framework: the
    /// declaration exists so that an entity type of the app's own can spell it, and the framework's own
    /// is unavailable for the same reason.
    @available(*, unavailable, message: "A transient entity is made by the app, not by the framework")
    public init() {
        fatalError("a transient entity is made by the app")
    }

    public var id: String { return String(describing: Self.self) }

    /// A transient entity is found by asking for it, which is what its own query does.
    public static var defaultQuery: _TransientAppEntityQuery<Self> { return _TransientAppEntityQuery() }
}

/// The query of a transient entity: it holds one, and there is nothing to look up.
public struct _TransientAppEntityQuery<Entity>: EntityQuery where Entity: TransientAppEntity {
    public typealias Result = [Entity]
    public typealias Entity = Entity
    public typealias DefaultValue = [Entity].Result
    public typealias Item = Entity
    public typealias ItemCollection = [Entity]
    public typealias ItemSection = [Entity]

    private let entity: Entity?
    private let provider: (() async -> [Entity])?

    public init() {
        self.entity = nil
        self.provider = nil
    }

    public init(entity: Entity) {
        self.entity = entity
        self.provider = nil
    }

    public init(provider: @escaping () async -> [Entity]) {
        self.entity = nil
        self.provider = provider
    }

    public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        return entity.map { [$0] } ?? []
    }

    public func results() async throws -> [Entity] {
        return try await entities(for: [])
    }

    public func defaultResult() async throws -> [Entity] {
        return try await results()
    }
}

/// An entity that stands for one thing only, so that a query can answer "the" entity without a list.
public protocol UniqueAppEntity: AppEntity where Self.DefaultQuery: UniqueAppEntityQuery {
    var id: String { get }
    var displayRepresentation: DisplayRepresentation { get }
}

/// The query of a unique entity: the one entity, or none.
public protocol UniqueAppEntityQuery: EnumerableEntityQuery where Entity: UniqueAppEntity {
    func uniqueEntity() async throws -> Entity?
}

extension UniqueAppEntityQuery {
    /// Every entity of a unique query is the one entity it holds.
    public func allEntities() async throws -> [Entity] {
        return try await uniqueEntity().map { [$0] } ?? []
    }

    public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        return try await uniqueEntity().map { [$0] } ?? []
    }

    public func suggestedEntities() async throws -> [Entity] {
        return try await uniqueEntity().map { [$0] } ?? []
    }
}

/// The provider of a unique entity, which is a query that holds one value.
public struct UniqueAppEntityProvider<Entity>: UniqueAppEntityQuery where Entity: UniqueAppEntity {
    public typealias Result = [Entity]
    public typealias Entity = Entity
    public typealias Unique = Entity

    /// The value a provider of a unique entity starts from, which is the entity itself.
    public typealias DefaultValue = [Entity].Result
    public typealias Item = Entity
    public typealias ItemCollection = [Entity]
    public typealias ItemSection = [Entity]

    private let stored: Entity?
    private let provider: (@Sendable () async throws -> Entity)?

    public init() {
        self.stored = nil
        self.provider = nil
    }

    public init(_ entity: Entity) {
        self.stored = entity
        self.provider = nil
    }

    public init(_ provider: @escaping @Sendable () async throws -> Entity) {
        self.stored = nil
        self.provider = provider
    }

    public func uniqueEntity() async throws -> Entity? {
        if let provider = provider { return try await provider() }
        return stored
    }

    public func results() async throws -> Entity {
        guard let entity = try await uniqueEntity() else {
            CharonUnset.fatal("a unique-entity provider with no entity has no result")
        }
        return entity
    }

    public func defaultResult() async throws -> Entity { return try await results() }
}

/// An entity the index knows, which is what a Spotlight search result is made of.
public protocol IndexedEntity: AppEntity {
    /// The attributes the index stores for the entity.
    var attributeSet: CharonSpotlightAttributeSet { get }
    /// The attributes the entity is indexed with when it names none.
    static var defaultAttributeSet: CharonSpotlightAttributeSet { get }
    /// Whether the entity is kept out of the index, added in iOS 18.4.
    static var hideInSpotlight: Bool { get }
}

extension IndexedEntity {
    public static var defaultAttributeSet: CharonSpotlightAttributeSet { return CharonSpotlightAttributeSet() }
    public static var hideInSpotlight: Bool { return false }
}

/// A file, which is an entity whose identifier is the file itself.
public protocol FileEntity: AppEntity where Self.ID == FileEntityIdentifier {
    /// The content types the file may have, added in iOS 18.
    static var supportedContentTypes: [String] { get }
}

extension FileEntity {
    public static var supportedContentTypes: [String] { return [] }
}

/// The identifier of a file entity: the file, or the draft of one that is not a file yet.
public struct FileEntityIdentifier: Hashable, Sendable, Codable {
    public let fileURL: URL?
    /// The identifier of a draft, which is a file that is not written yet.
    public let draftIdentifier: String

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.draftIdentifier = ""
    }

    public init(draftIdentifier: String) {
        self.fileURL = nil
        self.draftIdentifier = draftIdentifier
    }

    /// Whether the identifier is a draft, which is a file that is not written yet.
    public var isDraft: Bool { return fileURL == nil }

    /// The file the identifier names, when it names a file.
    public var file: URL? { return fileURL }

    /// The identifier as the framework's own `EntityIdentifierConvertible` writes it: the path of the
    /// file, or the identifier of the draft.
    public var entityIdentifierString: String { return fileURL?.path ?? draftIdentifier }

    /// The identifier as a string, which is what the framework's own `entityIdentifierString` names.
    public var identifierString: String { return entityIdentifierString }

    public static func entityIdentifier(for entityIdentifierString: String) -> FileEntityIdentifier? {
        if entityIdentifierString.hasPrefix("draft:") {
            return FileEntityIdentifier(draftIdentifier: String(entityIdentifierString.dropFirst("draft:".count)))
        }
        return FileEntityIdentifier(fileURL: URL(fileURLWithPath: entityIdentifierString))
    }

    /// The file an identifier names, which is what the framework's own `file(url:)` factory makes.
    public static func file(url: URL) -> FileEntityIdentifier {
        return FileEntityIdentifier(fileURL: url)
    }

    /// A draft of a file that is not written yet, which is what the framework's own `draft(identifier:)`
    /// factory makes.
    public static func draft(identifier: String) -> FileEntityIdentifier {
        return FileEntityIdentifier(draftIdentifier: identifier)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let path = try container.decodeIfPresent(String.self, forKey: .fileURL) {
            self.init(fileURL: URL(fileURLWithPath: path))
        } else {
            self.init(draftIdentifier: try container.decode(String.self, forKey: .draftIdentifier))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fileURL?.path, forKey: .fileURL)
        try container.encode(draftIdentifier, forKey: .draftIdentifier)
    }

    private enum CodingKeys: String, CodingKey {
        case fileURL
        case draftIdentifier
    }

    public static func == (a: FileEntityIdentifier, b: FileEntityIdentifier) -> Bool {
        return a.fileURL == b.fileURL && a.draftIdentifier == b.draftIdentifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL)
        hasher.combine(draftIdentifier)
    }
}

extension FileEntityIdentifier: EntityIdentifierConvertible {}

extension FileEntityIdentifier: _IntentValue {
    public typealias ValueType = FileEntityIdentifier
    public typealias UnwrappedType = FileEntityIdentifier
    public typealias Specification = EmptyResolverSpecification<FileEntityIdentifier>
    public static var defaultResolverSpecification: Specification { return Specification() }
}

/// The attributes the index stores for an entity, which is the port's own store: the release runs
/// no `CoreSpotlight`, and this is the record the port's own index keeps beside its journal.
public struct CharonSpotlightAttributeSet: Codable, Hashable {
    public var title: String
    public var contentDescription: String?
    public var contentType: String
    public var keywords: [String]
    /// The entity the record stands for, which is what `associateAppEntity` writes.
    public var appEntityIdentifier: String?

    public init(title: String = "", contentDescription: String? = nil, contentType: String = "",
                keywords: [String] = [], appEntityIdentifier: String? = nil) {
        self.title = title
        self.contentDescription = contentDescription
        self.contentType = contentType
        self.keywords = keywords
        self.appEntityIdentifier = appEntityIdentifier
    }

    public static func == (a: CharonSpotlightAttributeSet, b: CharonSpotlightAttributeSet) -> Bool {
        return a.title == b.title && a.contentDescription == b.contentDescription
            && a.contentType == b.contentType && a.keywords == b.keywords
            && a.appEntityIdentifier == b.appEntityIdentifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(contentType)
        hasher.combine(appEntityIdentifier)
    }
}

/// A value whose options are asked of the app when the caller has to choose.
public protocol DynamicOptionsProvider {
    associatedtype Item: _IntentValue
    associatedtype ItemCollection: ResultsCollection
    associatedtype ItemSection: ResultsCollection
    associatedtype DefaultValue: _IntentValue
    typealias ParameterDependency = IntentParameterDependency
    func results() async throws -> ItemCollection
    /// The options the provider offers when the caller has to choose.
    func defaultResult() async throws -> ItemCollection
}

extension DynamicOptionsProvider {
    public func defaultResult() async throws -> ItemCollection {
        return try await results()
    }
}

/// A collection of results the caller chooses from: a list, or a list in sections.
public protocol ResultsCollection {
    associatedtype Result: _IntentValue
    /// What the framework shows above the list, which is what the app wrote.
    var promptLabel: LocalizedStringResource? { get }
    /// Whether the list is shown with the section index of the release's own table view.
    var usesIndexedCollation: Bool { get }
    /// The values the list carries.
    var items: [Result.ValueType] { get }
    /// A list with nothing in it.
    static var empty: Self { get }
}

/// How many values a collection parameter may carry: exactly so many, or between so many.
public struct IntentCollectionSize: ExpressibleByIntegerLiteral, Equatable {
    // The framework's own `IntentCollectionSize` exposes neither `min` nor `max` - measured on the
    // host, where its printed form is `IntentCollectionSize(min: 3, max: 3)` and neither is a member -
    // and its `max` is not optional: `init(exactly:)` sets both ends and `init(min:max:)` takes both.
    public typealias IntegerLiteralType = Int

    let min: Int
    let max: Int

    public init(exactly: Int) {
        self.min = exactly
        self.max = exactly
    }

    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    public init(integerLiteral value: Int) {
        self.init(exactly: value)
    }

    public static func == (a: IntentCollectionSize, b: IntentCollectionSize) -> Bool {
        return a.min == b.min && a.max == b.max
    }

    /// How the size is written when it is printed, which is the release's own form (measured on the
    /// host for both spellings: `IntentCollectionSize(min: 3, max: 3)` and `IntentCollectionSize(min: 1, max: 4)`).
    public var description: String {
        return "IntentCollectionSize(min: \(min), max: \(max))"
    }
}

extension IntentCollectionSize: _IntentValue {
    public typealias ValueType = IntentCollectionSize
    public typealias UnwrappedType = IntentCollectionSize
    public typealias Specification = EmptyResolverSpecification<IntentCollectionSize>
    public static var defaultResolverSpecification: Specification { return Specification() }
}

import Foundation

public protocol AppEntity: AppValue, DisplayRepresentable, Identifiable
    where ValueType == Self, ID: EntityIdentifierConvertible {
    associatedtype DefaultQuery: EntityQuery where DefaultQuery.Entity == Self

    typealias Property = EntityProperty<Self>

    static var defaultQuery: Self.DefaultQuery { get }
}

extension AppEntity {
    public static var defaultResolverSpecification: EmptyResolverSpecification<Self> {
        return EmptyResolverSpecification()
    }
}

public protocol AppEnum: AppValue, StaticDisplayRepresentable, RawRepresentable where RawValue: LosslessStringConvertible {}

public protocol EntityIdentifierConvertible {
    var entityIdentifierString: String { get }
    static func entityIdentifier(for entityIdentifierString: String) -> Self?
}

extension EntityIdentifierConvertible where Self: LosslessStringConvertible {
    public var entityIdentifierString: String { return description }

    public static func entityIdentifier(for entityIdentifierString: String) -> Self? {
        return Self(entityIdentifierString)
    }
}

public struct EntityIdentifier: Hashable, Sendable, CustomStringConvertible {
    public let identifier: String
    public let entityType: String

    public init(for identifier: String) {
        self.identifier = identifier
        self.entityType = ""
    }

    public init<Identifier>(for value: Identifier, identifier: String) where Identifier: LosslessStringConvertible {
        self.identifier = identifier
        self.entityType = RevenantNames.simple(Identifier.self)
    }

    public init?(activityIdentifier: String) {
        self.init(for: activityIdentifier)
    }

    public init<Identifier>(for value: Identifier) where Identifier: LosslessStringConvertible {
        self.identifier = value.description
        self.entityType = RevenantNames.simple(Identifier.self)
    }

    public var description: String { return identifier }

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

public protocol EntityQuery: DynamicOptionsProvider, PersistentlyIdentifiable, Sendable {
    associatedtype Entity: AppEntity
    associatedtype Result: ResultsCollection = [Entity] where Result.Result == Entity
    init()
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity]
    func suggestedEntities() async throws -> Result
}

extension EntityQuery {
    public func suggestedEntities() async throws -> Result {
        return try await results()
    }

    public func results() async throws -> Result {
        return try await suggestedEntities()
    }
}

public protocol EnumerableEntityQuery: EntityQuery {
    func allEntities() async throws -> Result
    var findIntentDescription: IntentDescription? { get }
}

extension EnumerableEntityQuery {
    public var findIntentDescription: IntentDescription? { return nil }

    public func suggestedEntities() async throws -> Result {
        return try await allEntities()
    }
}

public protocol EntityStringQuery: EntityQuery {
    func entities(matching string: String) async throws -> [Entity]
}

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
        guard let raw: Entity.RawValue = RevenantIntentValueParser.parse(string, as: Entity.RawValue.self) else {
            return []
        }
        let one: Entity? = Entity(rawValue: raw)
        return one.map { [$0] } ?? []
    }

    public func suggestedEntities() async throws -> [Entity] {
        return []
    }
}

public protocol TransientAppEntity: AppEntity {}

extension TransientAppEntity {
    @available(*, unavailable, message: "A transient entity is made by the app, not by the framework")
    public init() {
        fatalError("a transient entity is made by the app")
    }

    public var id: String { return String(describing: Self.self) }

    public static var defaultQuery: _TransientAppEntityQuery<Self> { return _TransientAppEntityQuery() }
}

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

public protocol UniqueAppEntity: AppEntity where Self.DefaultQuery: UniqueAppEntityQuery {
    var id: String { get }
    var displayRepresentation: DisplayRepresentation { get }
}

public protocol UniqueAppEntityQuery: EnumerableEntityQuery where Entity: UniqueAppEntity {
    func uniqueEntity() async throws -> Entity?
}

extension UniqueAppEntityQuery {
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

public struct UniqueAppEntityProvider<Entity>: UniqueAppEntityQuery where Entity: UniqueAppEntity {
    public typealias Result = [Entity]
    public typealias Entity = Entity
    public typealias Unique = Entity

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
            RevenantUnset.fatal("a unique-entity provider with no entity has no result")
        }
        return entity
    }

    public func defaultResult() async throws -> Entity { return try await results() }
}

public protocol IndexedEntity: AppEntity {
    var attributeSet: RevenantSpotlightAttributeSet { get }
    static var defaultAttributeSet: RevenantSpotlightAttributeSet { get }
    static var hideInSpotlight: Bool { get }
}

extension IndexedEntity {
    public static var defaultAttributeSet: RevenantSpotlightAttributeSet { return RevenantSpotlightAttributeSet() }
    public static var hideInSpotlight: Bool { return false }
}

public protocol FileEntity: AppEntity where Self.ID == FileEntityIdentifier {
    static var supportedContentTypes: [String] { get }
}

extension FileEntity {
    public static var supportedContentTypes: [String] { return [] }
}

public struct FileEntityIdentifier: Hashable, Sendable, Codable {
    public let fileURL: URL?
    public let draftIdentifier: String

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.draftIdentifier = ""
    }

    public init(draftIdentifier: String) {
        self.fileURL = nil
        self.draftIdentifier = draftIdentifier
    }

    public var isDraft: Bool { return fileURL == nil }

    public var file: URL? { return fileURL }

    public var entityIdentifierString: String { return fileURL?.path ?? draftIdentifier }

    public var identifierString: String { return entityIdentifierString }

    public static func entityIdentifier(for entityIdentifierString: String) -> FileEntityIdentifier? {
        if entityIdentifierString.hasPrefix("draft:") {
            return FileEntityIdentifier(draftIdentifier: String(entityIdentifierString.dropFirst("draft:".count)))
        }
        return FileEntityIdentifier(fileURL: URL(fileURLWithPath: entityIdentifierString))
    }

    public static func file(url: URL) -> FileEntityIdentifier {
        return FileEntityIdentifier(fileURL: url)
    }

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

public struct RevenantSpotlightAttributeSet: Codable, Hashable {
    public var title: String
    public var contentDescription: String?
    public var contentType: String
    public var keywords: [String]
    public var appEntityIdentifier: String?

    public init(title: String = "", contentDescription: String? = nil, contentType: String = "",
                keywords: [String] = [], appEntityIdentifier: String? = nil) {
        self.title = title
        self.contentDescription = contentDescription
        self.contentType = contentType
        self.keywords = keywords
        self.appEntityIdentifier = appEntityIdentifier
    }

    public static func == (a: RevenantSpotlightAttributeSet, b: RevenantSpotlightAttributeSet) -> Bool {
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

public protocol DynamicOptionsProvider {
    associatedtype Item: _IntentValue
    associatedtype ItemCollection: ResultsCollection
    associatedtype ItemSection: ResultsCollection
    associatedtype DefaultValue: _IntentValue
    typealias ParameterDependency = IntentParameterDependency
    func results() async throws -> ItemCollection
    func defaultResult() async throws -> ItemCollection
}

extension DynamicOptionsProvider {
    public func defaultResult() async throws -> ItemCollection {
        return try await results()
    }
}

public protocol ResultsCollection {
    associatedtype Result: _IntentValue
    var promptLabel: LocalizedStringResource? { get }
    var usesIndexedCollation: Bool { get }
    var items: [Result.ValueType] { get }
    static var empty: Self { get }
}

public struct IntentCollectionSize: ExpressibleByIntegerLiteral, Equatable {
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

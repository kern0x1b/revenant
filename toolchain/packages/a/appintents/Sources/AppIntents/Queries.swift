import Foundation

public enum HasValueComparisonOperator{
    case hasNoValue
    case hasAnyValue

    var ordinal: Int {
        switch self {
        case .hasNoValue: return 0
        case .hasAnyValue: return 1
        }
    }

    public static func == (a: HasValueComparisonOperator, b: HasValueComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

public enum EquatableComparisonOperator{
    case equalTo
    case notEqualTo

    var ordinal: Int {
        switch self {
        case .equalTo: return 0
        case .notEqualTo: return 1
        }
    }

    public static func == (a: EquatableComparisonOperator, b: EquatableComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

public enum OneOfComparisonOperator{
    case oneOf

    var ordinal: Int {
        switch self {
        case .oneOf: return 0
        }
    }

    public static func == (a: OneOfComparisonOperator, b: OneOfComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

public enum ComparableComparisonOperator{
    case lessThan
    case lessThanOrEqualTo
    case greaterThan
    case greaterThanOrEqualTo

    var ordinal: Int {
        switch self {
        case .lessThan: return 0
        case .lessThanOrEqualTo: return 1
        case .greaterThan: return 2
        case .greaterThanOrEqualTo: return 3
        }
    }

    public static func == (a: ComparableComparisonOperator, b: ComparableComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

public enum StringComparisonOperator{
    case contains
    case doesNotContain
    case hasPrefix
    case hasSuffix

    var ordinal: Int {
        switch self {
        case .contains: return 0
        case .doesNotContain: return 1
        case .hasPrefix: return 2
        case .hasSuffix: return 3
        }
    }

    public static func == (a: StringComparisonOperator, b: StringComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

public enum EntityQueryComparatorMode{
    case and
    case or

    var ordinal: Int {
        switch self {
        case .and: return 0
        case .or: return 1
        }
    }

    public static func == (a: EntityQueryComparatorMode, b: EntityQueryComparatorMode) -> Bool { return a.ordinal == b.ordinal }

}

public class EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType>
    where PropertyType: _IntentValue, PropertyType: Sendable {
    public let property: Property
    public let value: InputType
    public let comparatorMapping: (any Sendable)?

    public init(property: Property, value: InputType, comparatorMapping: ComparatorMappingType) {
        self.property = property
        self.value = value
        self.comparatorMapping = comparatorMapping
    }
}

public struct AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>
    where PropertyType: _IntentValue, PropertyType: Sendable {
    public let comparator: EntityQueryComparator<Property, PropertyType, Subject, ComparatorMappingType>

    public init(_ comparator: EntityQueryComparator<Property, PropertyType, Subject, ComparatorMappingType>) {
        self.comparator = comparator
    }
}

@resultBuilder
public enum EntityQueryComparatorsBuilder {
    public static func buildBlock(_ comparator: some EntityQueryComparatorProtocol) -> [any EntityQueryComparatorProtocol] {
        return [comparator]
    }

    public static func buildExpression(_ expression: some EntityQueryComparatorProtocol) -> some EntityQueryComparatorProtocol {
        return expression
    }
}

public protocol EntityQueryComparatorProtocol {}

public final class EqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class NotEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class GreaterThanComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class GreaterThanOrEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class LessThanComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class LessThanOrEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class IsBetweenComparator<InputType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where ComparatorMappingType: Any {
    public let lowerBound: InputType
    public let upperBound: InputType
    public let comparatorMapping: (any Sendable)?

    public init(lowerBound: InputType, upperBound: InputType) {
        self.comparatorMapping = nil
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

public final class ContainsComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class HasPrefixComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public final class HasSuffixComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

public class EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>: Copyable, Escapable where Entity: AppEntity {
}

public typealias EntityQueryPropertyValue<Entity> = Entity

public final class EntityQueryProperty<Entity, Subject, Property, PropertyType, ComparatorMappingType>:
    EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>, Copyable, Escapable
    where Entity: AppEntity, Subject: AppEntity, Property: EntityProperty<PropertyType>,
          PropertyType: _IntentValue, PropertyType: Sendable {
    public typealias QueryComparators = [AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>]

    let keyPath: KeyPath<Subject, Property>
    let entityProvider: (Entity) -> Subject
    let comparators: () -> QueryComparators

    public init(_ keyPath: KeyPath<Subject, Property>, entityProvider: @escaping (Entity) -> Subject,
                comparators: @escaping () -> QueryComparators) {
        self.keyPath = keyPath
        self.entityProvider = entityProvider
        self.comparators = comparators
        super.init()
    }

    public convenience init(_ keyPath: KeyPath<Subject, Property>, comparators: @escaping () -> QueryComparators) {
        self.init(keyPath, entityProvider: { _ in
            RevenantUnset.fatal("an entity-property query that names no provider has no entity to read")
        }, comparators: comparators)
    }
}

public struct EntityQueryProperties<Entity, ComparatorMappingType> where Entity: AppEntity {
    private let declarations: [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>]

    public init(@EntityQueryPropertiesBuilder<Entity, ComparatorMappingType>
                properties: () -> [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>]) {
        self.declarations = properties()
    }

    public subscript(index: Int) -> EntityQueryPropertyDeclaration<Entity, ComparatorMappingType> {
        return declarations[index]
    }
}

@resultBuilder
public enum EntityQueryPropertiesBuilder<Entity, ComparatorMappingType> where Entity: AppEntity {
    public static func buildBlock(_ property: EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>)
        -> [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>] {
        return [property]
    }

    public static func buildExpression(_ expression: EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>)
        -> EntityQueryPropertyDeclaration<Entity, ComparatorMappingType> {
        return expression
    }
}

public protocol EntityPropertyQuery: EntityQuery {
    associatedtype Property
    associatedtype QueryProperties
    associatedtype Sort
    associatedtype SizableByProperty
    associatedtype SortableBy
    associatedtype ComparatorMode = EntityQueryComparatorMode
    associatedtype SortingOptions

    associatedtype QueryComparators = [any EntityQueryComparatorProtocol]

    var properties: QueryProperties { get }
    var sortingOptions: SortingOptions { get }
    var findIntentDescription: IntentDescription? { get }
    func entities(matching comparators: QueryComparators, mode: ComparatorMode,
                  sortedBy sort: [Sort], limit: Int?) async throws -> Result
}

@resultBuilder
public enum EntityQuerySortingOptionsBuilder<Entity> where Entity: AppEntity {
    public static func buildBlock(_ option: EntityQuerySortingOptions<Entity>) -> EntityQuerySortingOptions<Entity> {
        return option
    }

    public static func buildExpression(_ expression: EntityQuerySortingOptions<Entity>) -> EntityQuerySortingOptions<Entity> {
        return expression
    }
}

public struct EntityQuerySortingOptions<Entity> where Entity: AppEntity {
    private let options: [EntityQuerySort<Entity>]

    public init() {
        self.options = []
    }

    public init(@EntityQuerySortingOptionsBuilder<Entity> _: () -> Void) {
        self.options = []
    }

    public subscript(index: Int) -> EntityQuerySort<Entity> { return options[index] }
}

public struct EntityQuerySort<Entity> where Entity: AppEntity {
    public enum Ordering: Hashable, Sendable {
        case ascending
        case descending


    }

    public let by: (Entity) -> String
    public let order: Ordering

    public init(by: @escaping (Entity) -> String, order: Ordering) {
        self.by = by
        self.order = order
    }
}

public struct EntityQuerySortableByProperty<Entity> where Entity: AppEntity {
    public init(_ by: @escaping (Entity) -> String) {
        self.by = by
    }

    public let by: (Entity) -> String
}

public enum IntentWidgetFamily: String, _IntentValue, Hashable, Sendable, CaseDisplayRepresentable {
    case systemSmall
    case systemMedium
    case systemLarge
    case systemExtraLarge
    case accessoryCircular
    case accessoryCorner
    case accessoryInline
    case accessoryRectangular

    public static func == (a: IntentWidgetFamily, b: IntentWidgetFamily) -> Bool { return a.rawValue == b.rawValue }

    public static var defaultResolverSpecification: EmptyResolverSpecification<IntentWidgetFamily> {
        return EmptyResolverSpecification()
    }
}

public protocol IntentValueQuery: PersistentlyIdentifiable, _SupportsAppDependencies, Sendable, Escapable, Copyable {
    associatedtype Input
    associatedtype ResultValue
    associatedtype Result

    init()

    func values(for: Input) async throws -> Result
}

public protocol SearchCriteria: _IntentValue, Hashable, Sendable {
    associatedtype SearchScopes = Void
}

public struct StringSearchCriteria: SearchCriteria, Hashable, Sendable {
    public typealias SearchScopes = Set<StringSearchScope>

    public let term: String
    public let scopes: SearchScopes

    public init(term: String, scopes: SearchScopes = []) {
        self.term = term
        self.scopes = scopes
    }

    public static func == (a: StringSearchCriteria, b: StringSearchCriteria) -> Bool {
        return a.term == b.term && a.scopes == b.scopes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(term)
    }

    public static var defaultResolverSpecification: EmptyResolverSpecification<StringSearchCriteria> {
        return EmptyResolverSpecification()
    }
}

public enum StringSearchScope: String, AppEnum {
    case general
    case movies
    case tv
    case freeformVideo

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Search Scope"))
    }

    public static var caseDisplayRepresentations: [DisplayRepresentation] {
        return allCases.map { DisplayRepresentation(title: RevenantLocalized.resource($0.rawValue)) }
    }
}

extension VideoCategory: _IntentValue {
    public typealias ValueType = VideoCategory
    public typealias UnwrappedType = VideoCategory
    public typealias Specification = EmptyResolverSpecification<VideoCategory>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

extension StringSearchScope: _IntentValue {
    public typealias ValueType = StringSearchScope
    public typealias UnwrappedType = StringSearchScope
    public typealias Specification = EmptyResolverSpecification<StringSearchScope>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

public enum VideoCategory: String, AppEnum {
    case movies
    case tv
    case freeform

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Video Category"))
    }

    public static var caseDisplayRepresentations: [DisplayRepresentation] {
        return allCases.map { DisplayRepresentation(title: RevenantLocalized.resource($0.rawValue)) }
    }
}

public enum RevenantUnset {
    public static func fatal(_ what: String) -> Never {
        fatalError("AppIntents: \(what)")
    }
}

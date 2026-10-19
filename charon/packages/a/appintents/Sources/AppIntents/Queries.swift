// The queries' own vocabulary: how entities are compared, sorted and filtered, and the search terms
// and categories the app's own intents ask with.

import Foundation

// MARK: - Comparison operators

/// Whether a parameter has a value at all.
public enum HasValueComparisonOperator{
    case hasNoValue
    case hasAnyValue

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .hasNoValue: return 0
        case .hasAnyValue: return 1
        }
    }

    public static func == (a: HasValueComparisonOperator, b: HasValueComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

/// Whether a value is equal to another.
public enum EquatableComparisonOperator{
    case equalTo
    case notEqualTo

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .equalTo: return 0
        case .notEqualTo: return 1
        }
    }

    public static func == (a: EquatableComparisonOperator, b: EquatableComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

/// Whether a value is one of a list of values.
public enum OneOfComparisonOperator{
    case oneOf

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .oneOf: return 0
        }
    }

    public static func == (a: OneOfComparisonOperator, b: OneOfComparisonOperator) -> Bool { return a.ordinal == b.ordinal }

}

/// Whether a value is above or below another.
public enum ComparableComparisonOperator{
    case lessThan
    case lessThanOrEqualTo
    case greaterThan
    case greaterThanOrEqualTo

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
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

/// How a string is compared to another.
public enum StringComparisonOperator{
    case contains
    case doesNotContain
    case hasPrefix
    case hasSuffix

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
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

/// Whether several comparators are combined with every one of them or with any one of them.
public enum EntityQueryComparatorMode{
    /// Every comparator has to match.
    case and
    /// One comparator matching is enough.
    case or

    /// Which of the type's own cases this is. A query compares the operator a rule wrote
    /// with the one it runs, and an equality that answered `true` for every pair -- or a
    /// hash that told none of them apart -- would match the wrong one and collapse every
    /// value of the type into one bucket, so both are made of this.
    var ordinal: Int {
        switch self {
        case .and: return 0
        case .or: return 1
        }
    }

    public static func == (a: EntityQueryComparatorMode, b: EntityQueryComparatorMode) -> Bool { return a.ordinal == b.ordinal }

}

// MARK: - Comparators

/// The comparison of a property of an entity with a value, which is what an entity-property query
/// filters with. Each of the framework's own comparators is the comparison it names.
public class EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType>
    where PropertyType: _IntentValue, PropertyType: Sendable {
    /// The property compared, and the value it is compared to.
    public let property: Property
    public let value: InputType
    /// Whether the mapping the app gave its own input goes through the framework's own value.
    public let comparatorMapping: (any Sendable)?

    public init(property: Property, value: InputType, comparatorMapping: ComparatorMappingType) {
        self.property = property
        self.value = value
        self.comparatorMapping = comparatorMapping
    }
}

/// The comparison of a property of an entity with a value, without the property's own type.
public struct AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>
    where PropertyType: _IntentValue, PropertyType: Sendable {
    public let comparator: EntityQueryComparator<Property, PropertyType, Subject, ComparatorMappingType>

    public init(_ comparator: EntityQueryComparator<Property, PropertyType, Subject, ComparatorMappingType>) {
        self.comparator = comparator
    }
}

/// The builder of a list of comparators.
@resultBuilder
public enum EntityQueryComparatorsBuilder {
    public static func buildBlock(_ comparator: some EntityQueryComparatorProtocol) -> [any EntityQueryComparatorProtocol] {
        return [comparator]
    }

    public static func buildExpression(_ expression: some EntityQueryComparatorProtocol) -> some EntityQueryComparatorProtocol {
        return expression
    }
}

/// The marker of something an entity query can filter with.
public protocol EntityQueryComparatorProtocol {}

/// Whether the value is equal to the one the caller gave.
public final class EqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is not equal to the one the caller gave.
public final class NotEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is above the one the caller gave.
public final class GreaterThanComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is above or equal to the one the caller gave.
public final class GreaterThanOrEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is below the one the caller gave.
public final class LessThanComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is below or equal to the one the caller gave.
public final class LessThanOrEqualToComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the value is between two values.
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

/// Whether the string contains, or begins with, or ends with, the one the caller gave.
public final class ContainsComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the string begins with the one the caller gave.
public final class HasPrefixComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

/// Whether the string ends with the one the caller gave.
public final class HasSuffixComparator<PropertyType, ComparatorMappingType>: EntityQueryComparatorProtocol
    where PropertyType: _IntentValue, PropertyType: Sendable, ComparatorMappingType: Any {
    /// The value the caller compares with. A comparator declared with a mapping alone has none: the
    /// query reads the property and compares that, which is what the framework's own declaration
    /// means by a comparator with no value.
    public let value: PropertyType?
    public let comparatorMapping: (any Sendable)?

    /// A comparator declared with a mapping but no value: the mapping is held, and the value the
    /// query compares with is whatever the mapping gives the property's own value. There is no value
    /// to compare before the query runs, which is what the framework's own declaration means by it.
    public init(mappingTransform: @escaping (PropertyType) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = nil
    }

    public init<Value>(value: Value, mappingTransform: @escaping (Value) -> PropertyType) {
        self.comparatorMapping = nil
        self.value = mappingTransform(value)
    }
}

// MARK: - The query of a property

/// A property an entity-property query filters on: the declaration the query's property builder collects.
public class EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>: Copyable, Escapable where Entity: AppEntity {
}

/// The property an entity-property query filters on, over the type of the property's value: the
/// property itself is a parameter of that value, which is what the app writes it as.
public typealias EntityQueryPropertyValue<Entity> = Entity

/// A property an entity-property query filters on, and the value the caller is compared with: the key path
/// into the subject, the provider of the subject from the entity, and the comparators.
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

    /// A property declared with no provider: reading its entity stops, as an entity-property query with no
    /// provider has no entity to read.
    public convenience init(_ keyPath: KeyPath<Subject, Property>, comparators: @escaping () -> QueryComparators) {
        self.init(keyPath, entityProvider: { _ in
            CharonUnset.fatal("an entity-property query that names no provider has no entity to read")
        }, comparators: comparators)
    }
}

/// The properties an entity-property query filters on.
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

/// The builder of the properties an entity-property query filters on.
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

/// A query that filters and sorts entities by their properties, which is what a widget or a search
/// result is built from.
public protocol EntityPropertyQuery: EntityQuery {
    associatedtype Property
    associatedtype QueryProperties
    associatedtype Sort
    associatedtype SizableByProperty
    associatedtype SortableBy
    associatedtype ComparatorMode = EntityQueryComparatorMode
    associatedtype SortingOptions

    /// The comparators a caller filters with, which are the framework's own comparator types.
    associatedtype QueryComparators = [any EntityQueryComparatorProtocol]

    var properties: QueryProperties { get }
    var sortingOptions: SortingOptions { get }
    var findIntentDescription: IntentDescription? { get }
    func entities(matching comparators: QueryComparators, mode: ComparatorMode,
                  sortedBy sort: [Sort], limit: Int?) async throws -> Result
}

/// The builder of a query's sorting options.
@resultBuilder
public enum EntityQuerySortingOptionsBuilder<Entity> where Entity: AppEntity {
    public static func buildBlock(_ option: EntityQuerySortingOptions<Entity>) -> EntityQuerySortingOptions<Entity> {
        return option
    }

    public static func buildExpression(_ expression: EntityQuerySortingOptions<Entity>) -> EntityQuerySortingOptions<Entity> {
        return expression
    }
}

/// What a query's results may be sorted by.
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

/// What an entity's results may be sorted by, and in which order.
public struct EntityQuerySort<Entity> where Entity: AppEntity {
    /// Which way round.
    public enum Ordering: Hashable, Sendable {
        case ascending
        case descending


    }

    /// The property sorted by, written as the key path an app names it with.
    public let by: (Entity) -> String
    /// Which way round.
    public let order: Ordering

    public init(by: @escaping (Entity) -> String, order: Ordering) {
        self.by = by
        self.order = order
    }
}

/// A sort of an entity's results by one of its properties, written as the key path an app names it
/// with.
public struct EntityQuerySortableByProperty<Entity> where Entity: AppEntity {
    public init(_ by: @escaping (Entity) -> String) {
        self.by = by
    }

    /// The property sorted by.
    public let by: (Entity) -> String
}

// MARK: - The values a widget's intents ask for

/// The widget families an intent can be asked for, added in iOS 17.
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

/// A query of the values a widget's intent may be given: the app's own values for the input the framework passes.
public protocol IntentValueQuery: PersistentlyIdentifiable, _SupportsAppDependencies, Sendable, Escapable, Copyable {
    associatedtype Input
    associatedtype ResultValue
    associatedtype Result

    init()

    func values(for: Input) async throws -> Result
}

/// What the caller searches the app's own contents for.
public protocol SearchCriteria: _IntentValue, Hashable, Sendable {
    associatedtype SearchScopes = Void
}

/// The term a caller searches with, and the scopes it is searched in.
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

/// Where a string search looks, which is what an app narrows a search with.
public enum StringSearchScope: String, AppEnum {
    case general
    case movies
    case tv
    case freeformVideo

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Search Scope"))
    }

    public static var caseDisplayRepresentations: [DisplayRepresentation] {
        return allCases.map { DisplayRepresentation(title: CharonLocalized.resource($0.rawValue)) }
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

/// What kind of video a caller searches for or plays.
public enum VideoCategory: String, AppEnum {
    case movies
    case tv
    case freeform

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Video Category"))
    }

    public static var caseDisplayRepresentations: [DisplayRepresentation] {
        return allCases.map { DisplayRepresentation(title: CharonLocalized.resource($0.rawValue)) }
    }
}

/// A value the framework has not got, read where the declaration needs one. There is no honest zero
/// for an arbitrary type - `unsafeBitCast` would be a lie the caller reads as data - so the read
/// stops here with the declaration's own name in the message, which is what the framework's own
/// `fatalError("Do not reference schema types directly")` does.
public enum CharonUnset {
    public static func fatal(_ what: String) -> Never {
        fatalError("AppIntents: \(what)")
    }
}

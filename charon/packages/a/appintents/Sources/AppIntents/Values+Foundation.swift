// What the release's own value types are when a parameter carries one, and the builder that turns a
// list of resolvers into the specification a parameter carries.
//
// Each conformance is the real conversion, not a marker: `String`'s resolver is the identity, `Int`'s
// reads the string the release's own `Int.init` reads, `URL`'s is `URL(string:)`, and a parameter that
// asks for a value gets the value the release's type would give.

import Foundation

/// A resolver that hands a value through unchanged, which is what a type that is already its own
/// string form needs.
struct IdentityResolver: Resolver {
    func resolve(from input: String, context: IntentParameterContext<String>) async throws -> String? { return input }
}

/// The specification of the resolvers of a parameter, built by `ResolverSpecificationBuilder` and
/// carrying the resolvers themselves, so that a query reading a parameter runs the same resolvers the
/// parameter was declared with.
@resultBuilder
public enum ResolverSpecificationBuilder<Property> where Property: _IntentValue {}

extension ResolverSpecificationBuilder {
    public static func buildExpression<ResolverType>(_ expression: ResolverType) -> ResolverType
        where Property == ResolverType.Output, ResolverType: Resolver {
        return expression
    }

    public static func buildBlock() -> some ResolverSpecification {
        return EmptyResolverSpecification<Property>()
    }

    public static func buildBlock<R0>(_ r0: R0) -> some ResolverSpecification where R0: Resolver {
        return Specification<Property>([r0])
    }

    public static func buildBlock<R0, R1>(_ r0: R0, _ r1: R1) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver {
        return Specification<Property>([r0, r1])
    }

    public static func buildBlock<R0, R1, R2>(_ r0: R0, _ r1: R1, _ r2: R2) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver {
        return Specification<Property>([r0, r1, r2])
    }

    public static func buildBlock<R0, R1, R2, R3>(_ r0: R0, _ r1: R1, _ r2: R2,
                                                   _ r3: R3) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver {
        return Specification<Property>([r0, r1, r2, r3])
    }

    public static func buildBlock<R0, R1, R2, R3, R4>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3,
                                                       _ r4: R4) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4,
                                                            _ r5: R5) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4,
                                                                _ r5: R5,
                                                                _ r6: R6) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4,
                                                                    _ r5: R5, _ r6: R6,
                                                                    _ r7: R7) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3,
                                                                        _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7,
                                                                        _ r8: R8) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3,
                                                                            _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7,
                                                                            _ r8: R8,
                                                                            _ r9: R9) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3,
                                                                                 _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7,
                                                                                 _ r8: R8, _ r9: R9,
                                                                                 _ r10: R10) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver, R10: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11>(
        _ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10,
        _ r11: R11) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver, R10: Resolver, R11: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12>(
        _ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10,
        _ r11: R11, _ r12: R12) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13>(
        _ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10,
        _ r11: R11, _ r12: R12, _ r13: R13) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver, R13: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13])
    }

    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13, R14>(
        _ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10,
        _ r11: R11, _ r12: R12, _ r13: R13, _ r14: R14) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver,
              R7: Resolver, R8: Resolver, R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver, R13: Resolver,
              R14: Resolver {
        return Specification<Property>([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14])
    }

    /// The specification a set of resolvers makes, carrying them so that a query runs the same
    /// resolvers the parameter was declared with.
    public struct Specification<Output>: ResolverSpecification where Output: _IntentValue {
        public typealias Element = any Resolver

        let resolvers: [any Resolver]

        init(_ resolvers: [any Resolver]) {
            self.resolvers = resolvers
        }

        public func makeIterator() -> [any Resolver].Iterator { return resolvers.makeIterator() }

        public static func == (lhs: Specification<Output>, rhs: Specification<Output>) -> Bool {
            return lhs.resolvers.count == rhs.resolvers.count
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(resolvers.count)
        }
    }
}

extension ResolverSpecificationBuilder {
    public static func buildPartialBlock<R>(first: R) -> ResolverSpecificationBuilder<Property>.Specification<Property>
        where R: Resolver {
        return Specification<Property>([first])
    }

    public static func buildPartialBlock<R>(accumulated: ResolverSpecificationBuilder<Property>
        .Specification<Property>, next: R) -> ResolverSpecificationBuilder<Property>.Specification<Property>
        where R: Resolver {
        return Specification<Property>(Array(accumulated) + [next])
    }
}

// MARK: - The values a parameter can carry

extension String: _IntentValue {
    public typealias ValueType = String
    public typealias UnwrappedType = String
    public typealias Specification = ResolverSpecificationBuilder<String>.Specification<String>

    public static var defaultResolverSpecification: Specification {
        return Specification([IdentityResolver()])
    }

}

extension Int: _IntentValue, RangeComparableProperty {
    public typealias ValueType = Int
    public typealias UnwrappedType = Int
    public typealias Specification = ResolverSpecificationBuilder<Int>.Specification<Int>

    public static var defaultResolverSpecification: Specification {
        return Specification([IntResolver()])
    }

    /// The string an entity identifier of this type is written as, which is the release's own number.
    public static var entityIdentifierString: String { return String(0) }
    /// The entity identifier of a value of this type, which is the value written as a string.
    public static func entityIdentifier(for value: Int) -> EntityIdentifier {
        return EntityIdentifier(for: String(value), identifier: String(value))
    }
}

extension Float: _IntentValue {
    public typealias ValueType = Float
    public typealias UnwrappedType = Float
    public typealias Specification = ResolverSpecificationBuilder<Float>.Specification<Float>

    public static var defaultResolverSpecification: Specification {
        return Specification([FloatResolver()])
    }

    /// The string an entity identifier of this type is written as, which is the release's own number.
    public static var entityIdentifierString: String { return String(Float(0)) }
    /// The entity identifier of a value of this type, which is the value written as a string.
    public static func entityIdentifier(for value: Float) -> EntityIdentifier {
        return EntityIdentifier(for: String(value), identifier: String(value))
    }
}

extension Double: _IntentValue, RangeComparableProperty {
    public typealias ValueType = Double
    public typealias UnwrappedType = Double
    public typealias Specification = ResolverSpecificationBuilder<Double>.Specification<Double>

    public static var defaultResolverSpecification: Specification {
        return Specification([DoubleResolver()])
    }
}

extension Bool: _IntentValue {
    public typealias ValueType = Bool
    public typealias UnwrappedType = Bool
    public typealias Specification = ResolverSpecificationBuilder<Bool>.Specification<Bool>

    public static var defaultResolverSpecification: Specification {
        return Specification([BoolFromStringResolver()])
    }
}

extension URL: _IntentValue, @unchecked Sendable {
    public typealias ValueType = URL
    public typealias UnwrappedType = URL
    public typealias Specification = ResolverSpecificationBuilder<URL>.Specification<URL>

    public static var defaultResolverSpecification: Specification {
        return Specification([URLFromStringResolver()])
    }

}

extension UUID: _IntentValue {
    public typealias ValueType = UUID
    public typealias UnwrappedType = UUID
    public typealias Specification = ResolverSpecificationBuilder<UUID>.Specification<UUID>

    public static var defaultResolverSpecification: Specification {
        return Specification([UUIDResolver()])
    }

    /// The string an entity identifier of this type is written as, which is the release's own
    /// `uuidString`.
    public static var entityIdentifierString: String { return UUID().uuidString }
    /// The entity identifier of a value of this type, which is the value's own `uuidString`.
    public static func entityIdentifier(for value: UUID) -> EntityIdentifier {
        return EntityIdentifier(for: value.uuidString, identifier: value.uuidString)
    }
}

extension Date: _IntentValue, RangeComparableProperty, @unchecked Sendable {
    public typealias ValueType = Date
    public typealias UnwrappedType = Date
    public typealias Specification = ResolverSpecificationBuilder<Date>.Specification<Date>

    public static var defaultResolverSpecification: Specification {
        return Specification([DateResolver()])
    }
}

extension DateComponents: _IntentValue, @unchecked Sendable {
    public typealias ValueType = DateComponents
    public typealias UnwrappedType = DateComponents
    public typealias Specification = ResolverSpecificationBuilder<DateComponents>.Specification<DateComponents>

    public static var defaultResolverSpecification: Specification {
        return Specification([DateComponentsResolver()])
    }
}

/// Reads a `String` into a `UUID`, with the release's own `UUID(uuidString:)`.
struct UUIDResolver: Resolver {
    func resolve(from input: String, context: IntentParameterContext<UUID>) async throws -> UUID? {
        return UUID(uuidString: input)
    }

}

/// Reads a `String` into a `Float`.
struct FloatResolver: Resolver {
    func resolve(from input: String, context: IntentParameterContext<Float>) async throws -> Float? {
        return Float(input)
    }

}

/// Reads a `String` into a `Date`, with the spellings the release's own `Date` parsers take.
struct DateResolver: Resolver {
    func resolve(from input: String, context: IntentParameterContext<Date>) async throws -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: input) { return date }
        }
        return nil
    }

}

/// Reads a `String` into `DateComponents`, by the same parsers `DateResolver` uses.
struct DateComponentsResolver: Resolver {
    func resolve(from input: String,
                 context: IntentParameterContext<DateComponents>) async throws -> DateComponents? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: input) {
                let calendar = Calendar(identifier: .gregorian)
                return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            }
        }
        return nil
    }

}

extension Optional: _IntentValue where Wrapped: _IntentValue {
    public typealias ValueType = Wrapped.ValueType
    public typealias UnwrappedType = Wrapped.UnwrappedType
    public typealias Specification = Wrapped.UnwrappedType.Specification

    public static var defaultResolverSpecification: Wrapped.UnwrappedType.Specification {
        return Wrapped.UnwrappedType.defaultResolverSpecification
    }
}

extension Array: _IntentValue where Element: _IntentValue {
    public typealias ValueType = [Element.ValueType]
    public typealias UnwrappedType = [Element.UnwrappedType]
    public typealias Specification = ResolverSpecificationBuilder<[Element.UnwrappedType]>
        .Specification<[Element.UnwrappedType]>
    public typealias UnderlyingSequence = [Element.ValueType]

    public static var defaultResolverSpecification: Specification {
        return Specification([ElementResolver<Element.UnwrappedType>()])
    }
}

/// Reads the elements of a list parameter out of the string the caller wrote, one element per line and
/// after a comma, which is how a Shortcuts list of values is written.
struct ElementResolver<Element: _IntentValue>: Resolver {
    func resolve(from input: String,
                 context: IntentParameterContext<[Element.UnwrappedType]>) async throws -> [Element.UnwrappedType]? {
        return input.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { CharonIntentValueParser.parse($0, as: Element.UnwrappedType.self) }
    }

}

/// Writing a value of a type back as the string a caller would write for it, which is what the port's
/// own entity and enum identifiers and the resolvers' tests both go through.
public enum CharonIntentValueParser {
    public static func parse<T>(_ text: String, as type: T.Type) -> T? {
        switch type {
        case is String.Type: return text as? T
        case is Int.Type: return Int(text) as? T
        case is Double.Type: return Double(text) as? T
        case is Float.Type: return Float(text) as? T
        case is Bool.Type:
            return CharonRun.await { try await BoolFromStringResolver().resolve(from: text,
                context: IntentParameterContext(title: CharonLocalized.resource(""))) } as? T
        case is URL.Type: return URL(string: text) as? T
        case is UUID.Type: return UUID(uuidString: text) as? T
        case is Date.Type:
            return CharonRun.await { try await DateResolver().resolve(from: text,
                                                                        context: IntentParameterContext(title: CharonLocalized.resource(""))) } as? T
        case is Bool.Type: return nil
        default: return nil
        }
    }
}

/// A set of values, which the framework's own conformance takes over the set's element type rather
/// than the element's value type: a set's value is a set of the values themselves, and its resolver
/// specification is the empty one, the release's own `Set` writing itself out being what a caller
/// reads.
extension Set: _IntentValue where Element: _IntentValue, Element: Hashable {
    public typealias ValueType = Set<Element>
    public typealias UnwrappedType = Set<Element>
    public typealias Specification = EmptyResolverSpecification<Set<Element>>
    public typealias UnderlyingSequence = Set<Element>

    public static var defaultResolverSpecification: Specification {
        return Specification()
    }
}

extension Never: _IntentValue {
    public typealias ValueType = Never
    public typealias UnwrappedType = Never
    public typealias Specification = EmptyResolverSpecification<Never>
    public typealias Intent = Never
    public typealias Dialog = Never
    public typealias OpensAppIntent = Never
    public typealias Snippet = Never
    public typealias Value = Never

    public static var defaultResolverSpecification: Specification { return Specification() }
    public static var title: LocalizedStringResource { return LocalizedStringResource("Never") }
    /// The value of a parameter of this type, added in iOS 17: there is none, and it is asked for as
    /// often as one is.
    public static var value: Never { fatalError("Never has no value") }
}

/// The summary of an intent that is `Never`: there is no such intent, and its summary is the name the
/// framework gives it. It is a type of its own because `IntentParameterSummary<Never>` would need
/// `Never` to be an intent, which is the conformance this is part of.
public struct NeverSummary: ParameterSummary {
    public let summary: String

    public init() {
        self.summary = "Never"
    }
}

extension Never: AppIntent {
    public typealias PerformResult = IntentResultContainer<Never, Never, Never, Never>
    public typealias SummaryContent = NeverSummary
    public typealias Dependency = Never

    /// `Never` is the value an intent result carries when the app returned nothing, and the intent
    /// that runs nothing. There is no value of this type to make, so a call traps: the framework's own
    /// `init()` is the declaration this satisfies.
    public init() {
        fatalError("Never has no value to make")
    }

    public func perform() async throws -> PerformResult { fatalError("Never does nothing") }

    public static var parameterSummary: SummaryContent { return SummaryContent() }
}

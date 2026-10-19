import CoreLocation
import Foundation

extension CLPlacemark: DisplayRepresentable, _IntentValue {
    public typealias ValueType = CLPlacemark
    public typealias UnwrappedType = CLPlacemark
    public typealias Specification = EmptyResolverSpecification<CLPlacemark>

    public static var defaultResolverSpecification: Specification { return Specification() }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Location"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: RevenantLocalized.resource(name ?? "Location"))
    }

    public var localizedStringResource: LocalizedStringResource {
        return RevenantLocalized.resource(name ?? "Location")
    }
}

#if REVENANT_APPINTENTS_ATTRIBUTED_STRING
extension AttributedString: _IntentValue {
    public typealias ValueType = AttributedString
    public typealias UnwrappedType = AttributedString
    public typealias Specification = EmptyResolverSpecification<AttributedString>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

public struct AttributedStringFromStringResolver: Resolver {
    public typealias Input = String
    public typealias Output = AttributedString

    public init() {}

    public func resolve(from input: String,
                        context: IntentParameterContext<AttributedString>) async throws -> AttributedString? {
        return AttributedString(input)
    }

    public static func == (a: AttributedStringFromStringResolver,
                           b: AttributedStringFromStringResolver) -> Bool { return true }

}
#endif

#if REVENANT_APPINTENTS_MEASUREMENT
extension Measurement: _IntentValue {
    public typealias ValueType = Measurement
    public typealias UnwrappedType = Measurement
    public typealias Specification = EmptyResolverSpecification<Measurement>

    public static var defaultResolverSpecification: Specification { return Specification() }
}
#endif

#if REVENANT_APPINTENTS_RECURRENCE_RULE
extension Calendar.RecurrenceRule: _IntentValue {
    public typealias ValueType = Calendar.RecurrenceRule
    public typealias UnwrappedType = Calendar.RecurrenceRule
    public typealias Specification = EmptyResolverSpecification<Calendar.RecurrenceRule>

    public static var defaultResolverSpecification: Specification { return Specification() }
}
#endif

// The values of the port's own Foundation that AppIntents' API is written in, and that the port's
// Foundation does not have yet. Each block is compiled only when the runtime has the type: the package
// measures that with a probe and defines the flag, so a row whose Foundation type is not there is left
// out of the module and the ledger reads it as `missing`, which is what it is.
//
// `AttributedString`, `Measurement` and `Calendar.RecurrenceRule` are Foundation types the Foundation
// band carries (swift-foundation has all three; the ledger's Foundation rows name them
// `missing`/`code`), and `CLPlacemark` is CoreLocation's, which the CoreLocation backports carry. The
// conformances below are what AppIntents adds to them; they are compiled only when the runtime this
// package is built against has the type, which the package measures with a probe before the compile -
// see `xmake.lua`. Nothing here is a second copy of a type the port has: where the type is missing
// the file is left out of the module and the ledger says the row is `missing`, which is the truth.

import CoreLocation
import Foundation

extension CLPlacemark: DisplayRepresentable, _IntentValue {
    public typealias ValueType = CLPlacemark
    public typealias UnwrappedType = CLPlacemark
    public typealias Specification = EmptyResolverSpecification<CLPlacemark>

    public static var defaultResolverSpecification: Specification { return Specification() }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Location"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: CharonLocalized.resource(name ?? "Location"))
    }

    public var localizedStringResource: LocalizedStringResource {
        return CharonLocalized.resource(name ?? "Location")
    }
}

#if CHARON_APPINTENTS_ATTRIBUTED_STRING
extension AttributedString: _IntentValue {
    public typealias ValueType = AttributedString
    public typealias UnwrappedType = AttributedString
    public typealias Specification = EmptyResolverSpecification<AttributedString>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

/// Reads a `String` into an `AttributedString`, for the parameter that carries styled text.
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

#if CHARON_APPINTENTS_MEASUREMENT
extension Measurement: _IntentValue {
    public typealias ValueType = Measurement
    public typealias UnwrappedType = Measurement
    public typealias Specification = EmptyResolverSpecification<Measurement>

    public static var defaultResolverSpecification: Specification { return Specification() }
}
#endif

#if CHARON_APPINTENTS_RECURRENCE_RULE
extension Calendar.RecurrenceRule: _IntentValue {
    public typealias ValueType = Calendar.RecurrenceRule
    public typealias UnwrappedType = Calendar.RecurrenceRule
    public typealias Specification = EmptyResolverSpecification<Calendar.RecurrenceRule>

    public static var defaultResolverSpecification: Specification { return Specification() }
}
#endif

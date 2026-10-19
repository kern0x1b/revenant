// The equality members the digester never prints, and the measurement-typed ones it also does:
// a call site for each in Apple's own spelling. Typechecked twice -- against Apple's AppIntents
// (which proves the spelling is Apple's) and against this port's module (which proves the port
// has it). The measurement-typed rows are listed here and NOT called: their Value is
// Foundation's Measurement, which the port's runtime at 6.1.3 does not have (the recipe's own
// probe says so), so they are the Foundation band's rows and are `missing` here by the truth.
import Foundation
import AppIntents

    _ = AppIntents.IntentParameter<Int>.DateKind.self == AppIntents.IntentParameter<Int>.DateKind.self
    _ = AppIntents.IntentParameter<Int>.DoubleControlStyle.self == AppIntents.IntentParameter<Int>.DoubleControlStyle.self
    _ = AppIntents.IntentParameter<Int>.IntControlStyle.self == AppIntents.IntentParameter<Int>.IntControlStyle.self
    _ = AppIntents.IntentParameter<Int>.PlacemarkDisplayStyle.self == AppIntents.IntentParameter<Int>.PlacemarkDisplayStyle.self
    _ = AppIntents.IntentParameter<Int>.ValueState.self == AppIntents.IntentParameter<Int>.ValueState.self

    _ = AppIntents.IntentPerson.Handle.self == AppIntents.IntentPerson.Handle.self
    _ = AppIntents.IntentPerson.Name.self == AppIntents.IntentPerson.Name.self
    _ = AppIntents.IntentPerson.Identifier.self == AppIntents.IntentPerson.Identifier.self
    _ = AppIntents.IntentPerson.Handle.Value.self == AppIntents.IntentPerson.Handle.Value.self
    _ = AppIntents.IntentPerson.Handle.Label.self == AppIntents.IntentPerson.Handle.Label.self
// measured, not called at this release: the 24 measurement-typed rows
// IntentParameter<Measurement<UnitAcceleration>>.Acceleration and its 23 siblings.

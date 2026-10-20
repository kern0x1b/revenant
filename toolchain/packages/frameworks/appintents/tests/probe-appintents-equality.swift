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

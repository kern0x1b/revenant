import Foundation
import AppIntents

func use<T: Encodable>(_ type: T.Type, line: StaticString = #function) {
    _ = type.encode(to:)
    print(line)
}

use(IntentPerson.Name.self)
use(IntentPerson.Identifier.self)
use(IntentPerson.Handle.Value.self)
use(IntentPerson.Handle.Label.self)

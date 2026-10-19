// The four `encode(to:)` rows the corpus ledger carries for `IntentPerson`'s nested types
// (IntentPerson.Name, .Identifier, .Handle.Value, .Handle.Label). They are declared -- the types are
// `Codable` and the compiler synthesises the coding members -- and the digester does not print a
// synthesised one, so these are measured the way the coordinator set: a **call site in the
// framework's own spelling**, typechecked against this module for armv7-apple-ios6.1.3. A reference
// to the member proves it exists with that name and that signature, without inventing a value to
// encode.
import Foundation
import AppIntents

func use<T: Encodable>(_ type: T.Type, line: StaticString = #function) {
    // The reference is the test: `encode(to:)` must resolve on the type with the framework's spelling.
    _ = type.encode(to:)
    print(line)
}

use(IntentPerson.Name.self)
use(IntentPerson.Identifier.self)
use(IntentPerson.Handle.Value.self)
use(IntentPerson.Handle.Label.self)

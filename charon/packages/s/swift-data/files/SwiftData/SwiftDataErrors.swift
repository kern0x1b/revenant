// The two error types of the framework, and the coding keys a store's snapshot is written with.

import Foundation

/// What a store refuses, and why. The cases are Apple's, so a program that catches one of them
/// keeps working here; the payload is a sentence, because `Error` gives a type name and nothing
/// else and a store that cannot say what it refused has said nothing.
public struct SwiftDataError: Error, Hashable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public static let includePendingChangesWithBatchSize = SwiftDataError(
        "a fetch with a batch size cannot include the context's pending changes")
    public static let unsupportedPredicate = SwiftDataError("the store cannot run this predicate")
    public static let unsupportedKeyPath = SwiftDataError("the store cannot reach through this key path")
    public static let sortingPendingChangesWithIdentifiers = SwiftDataError(
        "a fetch that returns identifiers cannot be sorted by them while the context's pending changes are included")
    public static let unsupportedSortDescriptor = SwiftDataError("the store cannot order by this sort descriptor")
    public static let duplicateConfiguration = SwiftDataError("two configurations of one container name the same store")
    public static let configurationFileNameTooLong = SwiftDataError("the store's file name is longer than a file system takes")
    public static let configurationFileNameContainsInvalidCharacters = SwiftDataError(
        "the store's file name holds a character a file system does not take")
    public static let configurationSchemaNotFoundInContainerSchema = SwiftDataError(
        "the configuration's schema is not one of the container's schemas")
    public static let loadIssueModelContainer = SwiftDataError("the container holds a schema that could not be read")
    public static let modelValidationFailure = SwiftDataError("the schema does not describe a model a store can hold")
    public static let missingModelContext = SwiftDataError("the model has no context")
    public static let backwardMigration = SwiftDataError("the store is newer than the schema it is read with")
    public static let unknownSchema = SwiftDataError("the schema named is not one this store knows")
    public static let historyTokenExpired = SwiftDataError("the history token is older than the history this store keeps")
    public static let invalidTransactionFetchRequest = SwiftDataError(
        "a history fetch needs a date or a token to start from")

    public static func == (lhs: SwiftDataError, rhs: SwiftDataError) -> Bool {
        lhs.message == rhs.message
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(message)
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    /// What a program writes in a `catch`, and what this answers to: the store's own
    /// `SwiftDataError.historyTokenExpired` answers to any error that says the same thing, which
    /// is what lets a caller catch its own error type through this one.
    public static func ~= (lhs: SwiftDataError, rhs: any Error) -> Bool {
        guard let other = rhs as? SwiftDataError else { return false }
        return other == lhs
    }
}

public enum DataStoreError: Error, Equatable, Hashable {
    case unsupportedFeature
    case preferInMemoryFilter
    case preferInMemorySort
    case invalidPredicate
}

/// The keys a store's snapshot is written under: the row's own identifier, and one key per
/// modelled property, named by the property.
public enum DataStoreSnapshotCodingKey: CodingKey {
    case persistentIdentifier
    case modeledProperty(String)

    public var stringValue: String {
        switch self {
        case .persistentIdentifier: return "persistentIdentifier"
        case .modeledProperty(let name): return name
        }
    }

    public init?(stringValue: String) {
        if stringValue == "persistentIdentifier" {
            self = .persistentIdentifier
        } else {
            self = .modeledProperty(stringValue)
        }
    }

    public var intValue: Int? { nil }

    public init?(intValue: Int) { nil }
}

// The errors the datastore raises. The framework names each case and nothing else: Apple's own
// `description` and `errorDescription` are the case's name, measured against Apple's TipKit on the
// host (`.agent-work/host/apple-tipkit.txt`, under `error.`), so those are what this one says.
//
// Which of the three the datastore can raise here: `configure` throws
// `tipsDatastoreAlreadyConfigured` when the app configures its tips a second time, because the
// datastore is the app's own file and the second call would silently drop the first. The other two
// name conditions these releases do not have: a group container needs an app-group entitlement,
// which iOS 6 has no facility for at all, and `invalidPredicateValueType` is raised by the typed
// predicate evaluation, which here reads every donated value as text and so cannot meet a value
// type it does not have. They are declared because the framework declares them, so a port that
// catches one compiles, and `facts/TipKit/Rendering.md` records which are reachable.

import Foundation

/// What TipKit throws when the datastore cannot be set up as the app asked.
public struct TipKitError: Error, LocalizedError, Hashable {
    /// Which of the framework's three conditions this is. Not public: the framework's own cases are
    /// the three static values below, and no other value of this type can be made.
    enum Code: Hashable {
        case invalidPredicateValueType
        case missingGroupContainerEntitlements
        case tipsDatastoreAlreadyConfigured

        /// The case's own name, which is what the framework's error text is.
        var name: String {
            switch self {
                case .invalidPredicateValueType: return "invalidPredicateValueType"
                case .missingGroupContainerEntitlements: return "missingGroupContainerEntitlements"
                case .tipsDatastoreAlreadyConfigured: return "tipsDatastoreAlreadyConfigured"
            }
        }
    }

    let code: Code

    public static func == (a: TipKitError, b: TipKitError) -> Bool { return a.code == b.code }

    public var description: String { code.name }

    public var errorDescription: String? { code.name }

    /// A rule read a donation value of a type the predicate cannot compare.
    public static let invalidPredicateValueType = TipKitError(code: .invalidPredicateValueType)

    /// The app asked for a group container and carries no app-group entitlement, which these
    /// releases have no facility for.
    public static let missingGroupContainerEntitlements = TipKitError(code: .missingGroupContainerEntitlements)

    /// The app configured its tips again, and the datastore it already has would be dropped.
    public static let tipsDatastoreAlreadyConfigured = TipKitError(code: .tipsDatastoreAlreadyConfigured)

    /// Lets a port catch one case by name, as the framework's own `catch` spelling does:
    /// `catch TipKitError.tipsDatastoreAlreadyConfigured { }`.
    public static func ~= (lhs: TipKitError, rhs: any Error) -> Bool {
        (rhs as? TipKitError) == lhs
    }
}

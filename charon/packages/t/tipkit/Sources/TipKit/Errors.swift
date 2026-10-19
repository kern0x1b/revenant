import Foundation

public struct TipKitError: Error, LocalizedError, Hashable {
    enum Code: Hashable {
        case invalidPredicateValueType
        case missingGroupContainerEntitlements
        case tipsDatastoreAlreadyConfigured

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

    public static let invalidPredicateValueType = TipKitError(code: .invalidPredicateValueType)

    public static let missingGroupContainerEntitlements = TipKitError(code: .missingGroupContainerEntitlements)

    public static let tipsDatastoreAlreadyConfigured = TipKitError(code: .tipsDatastoreAlreadyConfigured)

    public static func ~= (lhs: TipKitError, rhs: any Error) -> Bool {
        (rhs as? TipKitError) == lhs
    }
}

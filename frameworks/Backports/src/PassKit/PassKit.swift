import Foundation

extension PKMerchantCapability {
    @available(iOS, deprecated: 17, renamed: "threeDSecure")
    public static var capability3DS: PKMerchantCapability {
        return .threeDSecure
    }

    @available(iOS, deprecated: 17, renamed: "emv")
    public static var capabilityEMV: PKMerchantCapability {
        return .emv
    }

    @available(iOS, deprecated: 17, renamed: "credit")
    public static var capabilityCredit: PKMerchantCapability {
        return .credit
    }

    @available(iOS, deprecated: 17, renamed: "debit")
    public static var capabilityDebit: PKMerchantCapability {
        return .debit
    }
}

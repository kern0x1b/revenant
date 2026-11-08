import PassKit

func request() -> PKPaymentRequest {
    let request = PKPaymentRequest()
    request.supportedNetworks = [.visa, .amex, .masterCard]
    request.merchantCapabilities = [.capability3DS]
    return request
}

func capabilities() -> [PKMerchantCapability] {
    return [.capability3DS, .capabilityEMV, .capabilityCredit, .capabilityDebit, .threeDSecure, .emv, .credit, .debit]
}

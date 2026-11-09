import Foundation
import UIKit
import StoreKit

func openSubscriptions() {
    if #available(iOS 15, *), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        let _ = Task {
            try await AppStore.showManageSubscriptions(in: scene)
        }
    } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

final class PurchaseObserver: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    private var productRequest: SKProductsRequest?

    func begin(identifiers: [String]) {
        SKPaymentQueue.default().add(self)
        let request = SKProductsRequest(productIdentifiers: Set(identifiers))
        request.delegate = self
        request.start()
        self.productRequest = request
    }

    func buy(_ product: SKProduct) {
        let payment = SKMutablePayment(product: product)
        payment.quantity = 1
        payment.applicationUsername = "account"
        SKPaymentQueue.default().add(payment)
        _ = SKPaymentQueue.canMakePayments()
        _ = product.subscriptionGroupIdentifier != nil
        _ = product.subscriptionPeriod != nil
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        _ = response.products.map { $0.productIdentifier }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        _ = error.localizedDescription
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                queue.finishTransaction(transaction)
            case .failed:
                _ = transaction.error as? SKError
            default:
                break
            }
        }
    }
}

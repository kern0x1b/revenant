import Foundation
import UIKit

public enum AppStore {
    @available(iOS 15.0, *)
    public static func showManageSubscriptions(in windowScene: UIWindowScene) async throws {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            return
        }
        UIApplication.shared.openURL(url)
    }
}

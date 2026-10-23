import Foundation
import UIKit

public enum AppStore {
    @available(iOS 15.0, *)
    public static func showManageSubscriptions(in windowScene: UIWindowScene) async throws {
        UIApplication.shared.openURL(AppStoreSubscriptions.url)
    }
}

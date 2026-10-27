import Foundation
import UIKit

public enum AppStore {
    public static func showManageSubscriptions(in windowScene: UIWindowScene) async throws {
        UIApplication.shared.openURL(AppStoreSubscriptions.url)
    }
}

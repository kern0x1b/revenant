import Foundation
import UIKit

public enum AppStore {
    @MainActor
    public static func showManageSubscriptions(in windowScene: UIWindowScene) async throws {
        guard UIApplication.shared.openURL(AppStoreSubscriptions.url) else {
            throw URLError(.unsupportedURL)
        }
    }
}

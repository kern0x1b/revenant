import Foundation

@available(iOS 6.0, *)
extension NSUserActivity {
    public var appEntityIdentifier: String? {
        get {
            return userInfo?["AppIntentsEntityIdentifier"] as? String
        }
        set {
            var info = userInfo ?? [:]
            info["AppIntentsEntityIdentifier"] = newValue
            userInfo = info
        }
    }
}

@available(iOS 6.0, *)
func makeActivity() -> NSUserActivity {
    let activity = NSUserActivity(activityType: "com.example.open")
    activity.title = "Open"
    activity.isEligibleForSearch = true
    activity.isEligibleForPublicIndexing = false
    activity.keywords = ["open"]
    activity.needsSave = true
    activity.targetContentIdentifier = "target"
    activity.persistentIdentifier = "persisted"
    activity.referrerURL = nil
    activity.appEntityIdentifier = "entity"
    activity.becomeCurrent()
    activity.resignCurrent()
    activity.invalidate()
    return activity
}

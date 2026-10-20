import Foundation

print("family-raw-accessory", (5...8).map { WidgetFamily(rawValue: $0).map { "\($0)" } ?? "nil" }.joined(separator: " "))
print("family-raw-9", WidgetFamily(rawValue: 9).map { "\($0)" } ?? "nil")
print("family-accessory-raw", WidgetFamily.accessoryCorner.rawValue, WidgetFamily.accessoryCircular.rawValue,
      WidgetFamily.accessoryRectangular.rawValue, WidgetFamily.accessoryInline.rawValue)
print("detail", LevelOfDetail.default == LevelOfDetail.default, LevelOfDetail.default == LevelOfDetail.simplified)
let locations: [WidgetLocation] = [.homeScreen, .lockScreen, .standBy, .iPhoneWidgetsOnMac, .watchFace, .smartStack, .carPlay]
print("location-equal", locations.map { l in locations.map { l == $0 ? 1 : 0 } })
print("location-set", Set(locations).count)
print("mounting", WidgetMountingStyle.elevated == WidgetMountingStyle.elevated, WidgetMountingStyle.elevated == WidgetMountingStyle.recessed,
      Set([WidgetMountingStyle.elevated, WidgetMountingStyle.recessed]).count)

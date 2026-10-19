import Foundation
#if !OURS
import WeatherKit
#endif

for c in WeatherCondition.allCases {
    print("condition", c.rawValue, "|", c.description, "|", c.accessibilityDescription)
}
print("conditionCount", WeatherCondition.allCases.count)
print("lowercase-rule", WeatherCondition.allCases.allSatisfy { $0.accessibilityDescription == $0.description.lowercased() })
print("condition.init", WeatherCondition(rawValue: "clear").map { "\($0)" } ?? "nil", WeatherCondition(rawValue: "noSuch").map { "\($0)" } ?? "nil")
print("string-interpolation", "\(WeatherCondition.foggy)")
func codable<T: Codable>(_: T.Type) -> Bool { true }
func hashable<T: Hashable>(_: T.Type) -> Bool { true }
func sendable<T: Sendable>(_: T.Type) -> Bool { true }
print("conform", codable(WeatherCondition.self), hashable(WeatherCondition.self), sendable(WeatherCondition.self))
let encoded = try! JSONEncoder().encode(WeatherCondition.hurricane)
print("json", String(decoding: encoded, as: UTF8.self))
let decoded = try! JSONDecoder().decode(WeatherCondition.self, from: encoded)
print("decoded", decoded.rawValue)

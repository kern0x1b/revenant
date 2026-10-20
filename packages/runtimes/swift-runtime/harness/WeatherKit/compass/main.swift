import Foundation
#if !OURS
import WeatherKit
#endif

for c in Wind.CompassDirection.allCases {
    print("direction", c.rawValue, "|", c.description, "|", c.abbreviation, "|", c.accessibilityDescription)
}
print("directionCount", Wind.CompassDirection.allCases.count)
print("init", Wind.CompassDirection(rawValue: "N").map { "\($0)" } ?? "nil", Wind.CompassDirection(rawValue: "north").map { "\($0)" } ?? "nil")
print("string-interpolation", "\(Wind.CompassDirection.northNortheast)")
print("rawValue-of-case", Wind.CompassDirection.eastSoutheast.rawValue)
print("typealiases", Wind.CompassDirection.AllCases.self == [Wind.CompassDirection].self, Wind.CompassDirection.RawValue.self == String.self)
func codable<T: Codable>(_: T.Type) -> Bool { true }
func hashable<T: Hashable>(_: T.Type) -> Bool { true }
func sendable<T: Sendable>(_: T.Type) -> Bool { true }
print("conform", codable(Wind.CompassDirection.self), hashable(Wind.CompassDirection.self), sendable(Wind.CompassDirection.self))
print("accessibility-equals-description", Wind.CompassDirection.allCases.allSatisfy { $0.accessibilityDescription == $0.description })

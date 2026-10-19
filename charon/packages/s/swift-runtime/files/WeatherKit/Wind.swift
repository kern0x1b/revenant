//===--- Wind.swift ---------------------------------------------*- swift -*-===//
//
// The wind of a forecast, and the sixteen points of the compass its direction is named by. Only
// CompassDirection is here: the members of Wind (direction, speed, gust, compassDirection, its
// Equatable and Codable conformances) are not carried yet, so the struct is declared as the
// container the nested type needs and nothing else. The raw values are the case names, the
// descriptions and abbreviations are the English strings the host's WeatherKit gives in the en
// locale (facts/WeatherKit/CompassDirection.md, measured with harness/WeatherKit/compass).
//
//===----------------------------------------------------------------------===//

public struct Wind {
    public enum CompassDirection: String, CaseIterable, Codable, CustomStringConvertible, Hashable, Sendable {
        case north
        case northNortheast
        case northeast
        case eastNortheast
        case east
        case eastSoutheast
        case southeast
        case southSoutheast
        case south
        case southSouthwest
        case southwest
        case westSouthwest
        case west
        case westNorthwest
        case northwest
        case northNorthwest

        public var abbreviation: String {
            switch self {
            case .north: return "N"
            case .northNortheast: return "NNE"
            case .northeast: return "NE"
            case .eastNortheast: return "ENE"
            case .east: return "E"
            case .eastSoutheast: return "ESE"
            case .southeast: return "SE"
            case .southSoutheast: return "SSE"
            case .south: return "S"
            case .southSouthwest: return "SSW"
            case .southwest: return "SW"
            case .westSouthwest: return "WSW"
            case .west: return "W"
            case .westNorthwest: return "WNW"
            case .northwest: return "NW"
            case .northNorthwest: return "NNW"
            }
        }

        public var description: String {
            switch self {
            case .north: return "North"
            case .northNortheast: return "North Northeast"
            case .northeast: return "Northeast"
            case .eastNortheast: return "East Northeast"
            case .east: return "East"
            case .eastSoutheast: return "East Southeast"
            case .southeast: return "Southeast"
            case .southSoutheast: return "South Southeast"
            case .south: return "South"
            case .southSouthwest: return "South Southwest"
            case .southwest: return "Southwest"
            case .westSouthwest: return "West Southwest"
            case .west: return "West"
            case .westNorthwest: return "West Northwest"
            case .northwest: return "Northwest"
            case .northNorthwest: return "North Northwest"
            }
        }

        public var accessibilityDescription: String {
            description
        }
    }
}

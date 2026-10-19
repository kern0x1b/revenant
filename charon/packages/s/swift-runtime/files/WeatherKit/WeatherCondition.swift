//===--- WeatherCondition.swift ---------------------------------------*- swift -*-===//
//
// The condition a forecast is described by. Its raw values are the case names and its descriptions
// are the English strings the host's WeatherKit gives in the en locale (facts/WeatherKit/WeatherCondition.md,
// measured with harness/WeatherKit/main.swift); the accessibility description is the same string
// lowercased for every case, which the same measurement shows.
//
//===----------------------------------------------------------------------===//

import Foundation

public enum WeatherCondition: String, CaseIterable, Codable, CustomStringConvertible, Hashable, Sendable {
    case blizzard
    case blowingDust
    case blowingSnow
    case breezy
    case clear
    case cloudy
    case drizzle
    case flurries
    case foggy
    case freezingDrizzle
    case freezingRain
    case frigid
    case hail
    case haze
    case heavyRain
    case heavySnow
    case hot
    case hurricane
    case isolatedThunderstorms
    case mostlyClear
    case mostlyCloudy
    case partlyCloudy
    case rain
    case scatteredThunderstorms
    case sleet
    case smoky
    case snow
    case strongStorms
    case sunFlurries
    case sunShowers
    case thunderstorms
    case tropicalStorm
    case windy
    case wintryMix

    public var description: String {
        switch self {
        case .blizzard: return "Blizzard"
        case .blowingDust: return "Dust"
        case .blowingSnow: return "Blowing Snow"
        case .breezy: return "Breezy"
        case .clear: return "Clear"
        case .cloudy: return "Cloudy"
        case .drizzle: return "Drizzle"
        case .flurries: return "Flurries"
        case .foggy: return "Fog"
        case .freezingDrizzle: return "Freezing Drizzle"
        case .freezingRain: return "Freezing Rain"
        case .frigid: return "Cold"
        case .hail: return "Hail"
        case .haze: return "Haze"
        case .heavyRain: return "Heavy Rain"
        case .heavySnow: return "Heavy Snow"
        case .hot: return "Hot"
        case .hurricane: return "Hurricane"
        case .isolatedThunderstorms: return "Isolated Thunderstorms"
        case .mostlyClear: return "Mostly Clear"
        case .mostlyCloudy: return "Mostly Cloudy"
        case .partlyCloudy: return "Partly Cloudy"
        case .rain: return "Rain"
        case .scatteredThunderstorms: return "Scattered Thunderstorms"
        case .sleet: return "Sleet"
        case .smoky: return "Smoke"
        case .snow: return "Snow"
        case .strongStorms: return "Severe Thunderstorm"
        case .sunFlurries: return "Sun Flurries"
        case .sunShowers: return "Sun Showers"
        case .thunderstorms: return "Thunderstorm"
        case .tropicalStorm: return "Tropical Storm"
        case .windy: return "Windy"
        case .wintryMix: return "Wintry Mix"
        }
    }

    public var accessibilityDescription: String {
        description.lowercased()
    }
}

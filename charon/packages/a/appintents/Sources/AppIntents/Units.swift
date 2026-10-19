// The units a measurement parameter is asked in, the control styles it is asked with, and the kind
// of a date it takes: the framework's own lists, in the framework's own order, each case the unit
// the release's own `Measurement` writes it as.

import Foundation

extension IntentParameter {
    /// The units of an acceleration a parameter takes.
    public enum Acceleration: Hashable {
        case gravity
        case metersPerSecondSquared

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .gravity: return 0
            case .metersPerSecondSquared: return 1
            }
        }

        public static func == (a: Acceleration, b: Acceleration) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an angle a parameter takes.
    public enum Angle: Hashable {
        case arcMinutes
        case arcSeconds
        case degrees
        case gradians
        case radians
        case revolutions

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .arcMinutes: return 0
            case .arcSeconds: return 1
            case .degrees: return 2
            case .gradians: return 3
            case .radians: return 4
            case .revolutions: return 5
            }
        }

        public static func == (a: Angle, b: Angle) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an area a parameter takes.
    public enum Area: Hashable {
        case acres
        case ares
        case hectares
        case squareCentimeters
        case squareFeet
        case squareInches
        case squareKilometers
        case squareMegameters
        case squareMeters
        case squareMicrometers
        case squareMiles
        case squareMillimeters
        case squareNanometers
        case squareYards

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .acres: return 0
            case .ares: return 1
            case .hectares: return 2
            case .squareCentimeters: return 3
            case .squareFeet: return 4
            case .squareInches: return 5
            case .squareKilometers: return 6
            case .squareMegameters: return 7
            case .squareMeters: return 8
            case .squareMicrometers: return 9
            case .squareMiles: return 10
            case .squareMillimeters: return 11
            case .squareNanometers: return 12
            case .squareYards: return 13
            }
        }

        public static func == (a: Area, b: Area) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a concentration of mass a parameter takes.
    public enum ConcentrationMass: Hashable {
        case gramsPerLiter
        case milligramsPerDeciliter

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .gramsPerLiter: return 0
            case .milligramsPerDeciliter: return 1
            }
        }

        public static func == (a: ConcentrationMass, b: ConcentrationMass) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a dispersion a parameter takes.
    public enum Dispersion: Hashable {
        case partsPerMillion

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .partsPerMillion: return 0
            }
        }

        public static func == (a: Dispersion, b: Dispersion) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a duration a parameter takes.
    public enum Duration: Hashable {
        case hours
        case microseconds
        case milliseconds
        case minutes
        case nanoseconds
        case picoseconds
        case seconds

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .hours: return 0
            case .microseconds: return 1
            case .milliseconds: return 2
            case .minutes: return 3
            case .nanoseconds: return 4
            case .picoseconds: return 5
            case .seconds: return 6
            }
        }

        public static func == (a: Duration, b: Duration) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an electric charge a parameter takes.
    public enum ElectricCharge: Hashable {
        case ampereHours
        case coulombs
        case kiloampereHours
        case megaampereHours
        case microampereHours
        case milliampereHours

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .ampereHours: return 0
            case .coulombs: return 1
            case .kiloampereHours: return 2
            case .megaampereHours: return 3
            case .microampereHours: return 4
            case .milliampereHours: return 5
            }
        }

        public static func == (a: ElectricCharge, b: ElectricCharge) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an electric current a parameter takes.
    public enum ElectricCurrent: Hashable {
        case amperes
        case kiloamperes
        case megaamperes
        case microamperes
        case milliamperes

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .amperes: return 0
            case .kiloamperes: return 1
            case .megaamperes: return 2
            case .microamperes: return 3
            case .milliamperes: return 4
            }
        }

        public static func == (a: ElectricCurrent, b: ElectricCurrent) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an electric potential difference a parameter takes.
    public enum ElectricPotentialDifference: Hashable {
        case kilovolts
        case megavolts
        case microvolts
        case millivolts
        case volts

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .kilovolts: return 0
            case .megavolts: return 1
            case .microvolts: return 2
            case .millivolts: return 3
            case .volts: return 4
            }
        }

        public static func == (a: ElectricPotentialDifference, b: ElectricPotentialDifference) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an electric resistance a parameter takes.
    public enum ElectricResistance: Hashable {
        case kiloohms
        case megaohms
        case microohms
        case milliohms
        case ohms

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .kiloohms: return 0
            case .megaohms: return 1
            case .microohms: return 2
            case .milliohms: return 3
            case .ohms: return 4
            }
        }

        public static func == (a: ElectricResistance, b: ElectricResistance) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an energy a parameter takes.
    public enum Energy: Hashable {
        case calories
        case joules
        case kilocalories
        case kilojoules
        case kilowattHours

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .calories: return 0
            case .joules: return 1
            case .kilocalories: return 2
            case .kilojoules: return 3
            case .kilowattHours: return 4
            }
        }

        public static func == (a: Energy, b: Energy) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a frequency a parameter takes.
    public enum Frequency: Hashable {
        case framesPerSecond
        case gigahertz
        case hertz
        case kilohertz
        case megahertz
        case microhertz
        case millihertz
        case nanohertz
        case terahertz

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .framesPerSecond: return 0
            case .gigahertz: return 1
            case .hertz: return 2
            case .kilohertz: return 3
            case .megahertz: return 4
            case .microhertz: return 5
            case .millihertz: return 6
            case .nanohertz: return 7
            case .terahertz: return 8
            }
        }

        public static func == (a: Frequency, b: Frequency) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a fuel efficiency a parameter takes.
    public enum FuelEfficiency: Hashable {
        case litersPer100Kilometers
        case milesPerGallon
        case milesPerImperialGallon

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .litersPer100Kilometers: return 0
            case .milesPerGallon: return 1
            case .milesPerImperialGallon: return 2
            }
        }

        public static func == (a: FuelEfficiency, b: FuelEfficiency) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an illuminance a parameter takes.
    public enum Illuminance: Hashable {
        case lux

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .lux: return 0
            }
        }

        public static func == (a: Illuminance, b: Illuminance) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of an amount of information a parameter takes.
    public enum InformationStorage: Hashable {
        case bits
        case bytes
        case exabits
        case exabytes
        case exbibits
        case exbibytes
        case gibibits
        case gibibytes
        case gigabits
        case gigabytes
        case kibibits
        case kibibytes
        case kilobits
        case kilobytes
        case mebibits
        case mebibytes
        case megabits
        case megabytes
        case nibbles
        case pebibits
        case pebibytes
        case petabits
        case petabytes
        case tebibits
        case tebibytes
        case terabits
        case terabytes
        case yobibits
        case yobibytes
        case yottabits
        case yottabytes
        case zebibits
        case zebibytes
        case zettabits
        case zettabytes

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .bits: return 0
            case .bytes: return 1
            case .exabits: return 2
            case .exabytes: return 3
            case .exbibits: return 4
            case .exbibytes: return 5
            case .gibibits: return 6
            case .gibibytes: return 7
            case .gigabits: return 8
            case .gigabytes: return 9
            case .kibibits: return 10
            case .kibibytes: return 11
            case .kilobits: return 12
            case .kilobytes: return 13
            case .mebibits: return 14
            case .mebibytes: return 15
            case .megabits: return 16
            case .megabytes: return 17
            case .nibbles: return 18
            case .pebibits: return 19
            case .pebibytes: return 20
            case .petabits: return 21
            case .petabytes: return 22
            case .tebibits: return 23
            case .tebibytes: return 24
            case .terabits: return 25
            case .terabytes: return 26
            case .yobibits: return 27
            case .yobibytes: return 28
            case .yottabits: return 29
            case .yottabytes: return 30
            case .zebibits: return 31
            case .zebibytes: return 32
            case .zettabits: return 33
            case .zettabytes: return 34
            }
        }

        public static func == (a: InformationStorage, b: InformationStorage) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a length a parameter takes.
    public enum Length: Hashable {
        case astronomicalUnits
        case centimeters
        case decameters
        case decimeters
        case fathoms
        case feet
        case furlongs
        case hectometers
        case inches
        case kilometers
        case lightyears
        case megameters
        case meters
        case micrometers
        case miles
        case millimeters
        case nanometers
        case nauticalMiles
        case parsecs
        case picometers
        case scandinavianMiles
        case yards

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .astronomicalUnits: return 0
            case .centimeters: return 1
            case .decameters: return 2
            case .decimeters: return 3
            case .fathoms: return 4
            case .feet: return 5
            case .furlongs: return 6
            case .hectometers: return 7
            case .inches: return 8
            case .kilometers: return 9
            case .lightyears: return 10
            case .megameters: return 11
            case .meters: return 12
            case .micrometers: return 13
            case .miles: return 14
            case .millimeters: return 15
            case .nanometers: return 16
            case .nauticalMiles: return 17
            case .parsecs: return 18
            case .picometers: return 19
            case .scandinavianMiles: return 20
            case .yards: return 21
            }
        }

        public static func == (a: Length, b: Length) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a mass a parameter takes.
    public enum Mass: Hashable {
        case carats
        case centigrams
        case decigrams
        case grams
        case kilograms
        case metricTons
        case micrograms
        case milligrams
        case nanograms
        case ounces
        case ouncesTroy
        case picograms
        case pounds
        case shortTons
        case slugs
        case stones

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .carats: return 0
            case .centigrams: return 1
            case .decigrams: return 2
            case .grams: return 3
            case .kilograms: return 4
            case .metricTons: return 5
            case .micrograms: return 6
            case .milligrams: return 7
            case .nanograms: return 8
            case .ounces: return 9
            case .ouncesTroy: return 10
            case .picograms: return 11
            case .pounds: return 12
            case .shortTons: return 13
            case .slugs: return 14
            case .stones: return 15
            }
        }

        public static func == (a: Mass, b: Mass) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a power a parameter takes.
    public enum Power: Hashable {
        case femtowatts
        case gigawatts
        case horsepower
        case kilowatts
        case megawatts
        case microwatts
        case milliwatts
        case nanowatts
        case picowatts
        case terawatts
        case watts

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .femtowatts: return 0
            case .gigawatts: return 1
            case .horsepower: return 2
            case .kilowatts: return 3
            case .megawatts: return 4
            case .microwatts: return 5
            case .milliwatts: return 6
            case .nanowatts: return 7
            case .picowatts: return 8
            case .terawatts: return 9
            case .watts: return 10
            }
        }

        public static func == (a: Power, b: Power) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a pressure a parameter takes.
    public enum Pressure: Hashable {
        case bars
        case gigapascals
        case hectopascals
        case inchesOfMercury
        case kilopascals
        case megapascals
        case millibars
        case millimetersOfMercury
        case newtonsPerMetersSquared
        case poundsForcePerSquareInch

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .bars: return 0
            case .gigapascals: return 1
            case .hectopascals: return 2
            case .inchesOfMercury: return 3
            case .kilopascals: return 4
            case .megapascals: return 5
            case .millibars: return 6
            case .millimetersOfMercury: return 7
            case .newtonsPerMetersSquared: return 8
            case .poundsForcePerSquareInch: return 9
            }
        }

        public static func == (a: Pressure, b: Pressure) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a speed a parameter takes.
    public enum Speed: Hashable {
        case kilometersPerHour
        case knots
        case metersPerSecond
        case milesPerHour

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .kilometersPerHour: return 0
            case .knots: return 1
            case .metersPerSecond: return 2
            case .milesPerHour: return 3
            }
        }

        public static func == (a: Speed, b: Speed) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a temperature a parameter takes.
    public enum Temperature: Hashable {
        case celsius
        case fahrenheit
        case kelvin

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .celsius: return 0
            case .fahrenheit: return 1
            case .kelvin: return 2
            }
        }

        public static func == (a: Temperature, b: Temperature) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The units of a volume a parameter takes.
    public enum Volume: Hashable {
        case acreFeet
        case bushels
        case centiliters
        case cubicCentimeters
        case cubicDecimeters
        case cubicFeet
        case cubicInches
        case cubicKilometers
        case cubicMeters
        case cubicMiles
        case cubicMillimeters
        case cubicYards
        case cups
        case deciliters
        case fluidOunces
        case gallons
        case imperialFluidOunces
        case imperialGallons
        case imperialPints
        case imperialQuarts
        case imperialTablespoons
        case imperialTeaspoons
        case kiloliters
        case liters
        case megaliters
        case metricCups
        case milliliters
        case pints
        case quarts
        case tablespoons
        case teaspoons

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .acreFeet: return 0
            case .bushels: return 1
            case .centiliters: return 2
            case .cubicCentimeters: return 3
            case .cubicDecimeters: return 4
            case .cubicFeet: return 5
            case .cubicInches: return 6
            case .cubicKilometers: return 7
            case .cubicMeters: return 8
            case .cubicMiles: return 9
            case .cubicMillimeters: return 10
            case .cubicYards: return 11
            case .cups: return 12
            case .deciliters: return 13
            case .fluidOunces: return 14
            case .gallons: return 15
            case .imperialFluidOunces: return 16
            case .imperialGallons: return 17
            case .imperialPints: return 18
            case .imperialQuarts: return 19
            case .imperialTablespoons: return 20
            case .imperialTeaspoons: return 21
            case .kiloliters: return 22
            case .liters: return 23
            case .megaliters: return 24
            case .metricCups: return 25
            case .milliliters: return 26
            case .pints: return 27
            case .quarts: return 28
            case .tablespoons: return 29
            case .teaspoons: return 30
            }
        }

        public static func == (a: Volume, b: Volume) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }


    /// The control an integer parameter is asked with.
    public enum IntControlStyle: Hashable {
        case stepper
        case field

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .stepper: return 0
            case .field: return 1
            }
        }

        public static func == (a: IntControlStyle, b: IntControlStyle) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }

    /// The way a placemark parameter is shown.
    public enum PlacemarkDisplayStyle: Hashable {
        case name
        case address
        case city

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .name: return 0
            case .address: return 1
            case .city: return 2
            }
        }

        public static func == (a: PlacemarkDisplayStyle, b: PlacemarkDisplayStyle) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }

    /// The control a floating-point parameter is asked with.
    public enum DoubleControlStyle: Hashable {
        case stepper
        case field
        case slider

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .stepper: return 0
            case .field: return 1
            case .slider: return 2
            }
        }

        public static func == (a: DoubleControlStyle, b: DoubleControlStyle) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }

    /// What a date parameter takes: a date, a time, or both.
    public enum DateKind: Hashable {
        case date
        case time
        case dateTime

        /// The place of a case in the framework's own list, which is what a case hashes as.
        public var ordinal: Int {
            switch self {
            case .date: return 0
            case .time: return 1
            case .dateTime: return 2
            }
        }

        public static func == (a: DateKind, b: DateKind) -> Bool { return a.ordinal == b.ordinal }

        public func hash(into hasher: inout Hasher) { hasher.combine(ordinal) }

        public var hashValue: Int { return ordinal }
    }



}

// The units whose whole list a caller may choose from, added in iOS 18: the framework's own
// `CaseIterable` conformances, which list every case in the framework's order.
extension IntentParameter.Acceleration: CaseIterable {
    public typealias AllCases = [IntentParameter.Acceleration]

    public static var allCases: [IntentParameter.Acceleration] { return [IntentParameter.Acceleration.gravity, IntentParameter.Acceleration.metersPerSecondSquared] }
}
extension IntentParameter.Angle: CaseIterable {
    public typealias AllCases = [IntentParameter.Angle]

    public static var allCases: [IntentParameter.Angle] { return [IntentParameter.Angle.arcMinutes, IntentParameter.Angle.arcSeconds, IntentParameter.Angle.degrees, IntentParameter.Angle.gradians, IntentParameter.Angle.radians, IntentParameter.Angle.revolutions] }
}
extension IntentParameter.Area: CaseIterable {
    public typealias AllCases = [IntentParameter.Area]

    public static var allCases: [IntentParameter.Area] { return [IntentParameter.Area.acres, IntentParameter.Area.ares, IntentParameter.Area.hectares, IntentParameter.Area.squareCentimeters, IntentParameter.Area.squareFeet, IntentParameter.Area.squareInches, IntentParameter.Area.squareKilometers, IntentParameter.Area.squareMegameters, IntentParameter.Area.squareMeters, IntentParameter.Area.squareMicrometers, IntentParameter.Area.squareMiles, IntentParameter.Area.squareMillimeters, IntentParameter.Area.squareNanometers, IntentParameter.Area.squareYards] }
}
extension IntentParameter.ConcentrationMass: CaseIterable {
    public typealias AllCases = [IntentParameter.ConcentrationMass]

    public static var allCases: [IntentParameter.ConcentrationMass] { return [IntentParameter.ConcentrationMass.gramsPerLiter, IntentParameter.ConcentrationMass.milligramsPerDeciliter] }
}
extension IntentParameter.Dispersion: CaseIterable {
    public typealias AllCases = [IntentParameter.Dispersion]

    public static var allCases: [IntentParameter.Dispersion] { return [IntentParameter.Dispersion.partsPerMillion] }
}
extension IntentParameter.Duration: CaseIterable {
    public typealias AllCases = [IntentParameter.Duration]

    public static var allCases: [IntentParameter.Duration] { return [IntentParameter.Duration.hours, IntentParameter.Duration.microseconds, IntentParameter.Duration.milliseconds, IntentParameter.Duration.minutes, IntentParameter.Duration.nanoseconds, IntentParameter.Duration.picoseconds, IntentParameter.Duration.seconds] }
}
extension IntentParameter.ElectricCharge: CaseIterable {
    public typealias AllCases = [IntentParameter.ElectricCharge]

    public static var allCases: [IntentParameter.ElectricCharge] { return [IntentParameter.ElectricCharge.ampereHours, IntentParameter.ElectricCharge.coulombs, IntentParameter.ElectricCharge.kiloampereHours, IntentParameter.ElectricCharge.megaampereHours, IntentParameter.ElectricCharge.microampereHours, IntentParameter.ElectricCharge.milliampereHours] }
}
extension IntentParameter.ElectricCurrent: CaseIterable {
    public typealias AllCases = [IntentParameter.ElectricCurrent]

    public static var allCases: [IntentParameter.ElectricCurrent] { return [IntentParameter.ElectricCurrent.amperes, IntentParameter.ElectricCurrent.kiloamperes, IntentParameter.ElectricCurrent.megaamperes, IntentParameter.ElectricCurrent.microamperes, IntentParameter.ElectricCurrent.milliamperes] }
}
extension IntentParameter.ElectricPotentialDifference: CaseIterable {
    public typealias AllCases = [IntentParameter.ElectricPotentialDifference]

    public static var allCases: [IntentParameter.ElectricPotentialDifference] { return [IntentParameter.ElectricPotentialDifference.kilovolts, IntentParameter.ElectricPotentialDifference.megavolts, IntentParameter.ElectricPotentialDifference.microvolts, IntentParameter.ElectricPotentialDifference.millivolts, IntentParameter.ElectricPotentialDifference.volts] }
}
extension IntentParameter.ElectricResistance: CaseIterable {
    public typealias AllCases = [IntentParameter.ElectricResistance]

    public static var allCases: [IntentParameter.ElectricResistance] { return [IntentParameter.ElectricResistance.kiloohms, IntentParameter.ElectricResistance.megaohms, IntentParameter.ElectricResistance.microohms, IntentParameter.ElectricResistance.milliohms, IntentParameter.ElectricResistance.ohms] }
}
extension IntentParameter.Energy: CaseIterable {
    public typealias AllCases = [IntentParameter.Energy]

    public static var allCases: [IntentParameter.Energy] { return [IntentParameter.Energy.calories, IntentParameter.Energy.joules, IntentParameter.Energy.kilocalories, IntentParameter.Energy.kilojoules, IntentParameter.Energy.kilowattHours] }
}
extension IntentParameter.Frequency: CaseIterable {
    public typealias AllCases = [IntentParameter.Frequency]

    public static var allCases: [IntentParameter.Frequency] { return [IntentParameter.Frequency.framesPerSecond, IntentParameter.Frequency.gigahertz, IntentParameter.Frequency.hertz, IntentParameter.Frequency.kilohertz, IntentParameter.Frequency.megahertz, IntentParameter.Frequency.microhertz, IntentParameter.Frequency.millihertz, IntentParameter.Frequency.nanohertz, IntentParameter.Frequency.terahertz] }
}
extension IntentParameter.FuelEfficiency: CaseIterable {
    public typealias AllCases = [IntentParameter.FuelEfficiency]

    public static var allCases: [IntentParameter.FuelEfficiency] { return [IntentParameter.FuelEfficiency.litersPer100Kilometers, IntentParameter.FuelEfficiency.milesPerGallon, IntentParameter.FuelEfficiency.milesPerImperialGallon] }
}
extension IntentParameter.Illuminance: CaseIterable {
    public typealias AllCases = [IntentParameter.Illuminance]

    public static var allCases: [IntentParameter.Illuminance] { return [IntentParameter.Illuminance.lux] }
}
extension IntentParameter.InformationStorage: CaseIterable {
    public typealias AllCases = [IntentParameter.InformationStorage]

    public static var allCases: [IntentParameter.InformationStorage] { return [IntentParameter.InformationStorage.bits, IntentParameter.InformationStorage.bytes, IntentParameter.InformationStorage.exabits, IntentParameter.InformationStorage.exabytes, IntentParameter.InformationStorage.exbibits, IntentParameter.InformationStorage.exbibytes, IntentParameter.InformationStorage.gibibits, IntentParameter.InformationStorage.gibibytes, IntentParameter.InformationStorage.gigabits, IntentParameter.InformationStorage.gigabytes, IntentParameter.InformationStorage.kibibits, IntentParameter.InformationStorage.kibibytes, IntentParameter.InformationStorage.kilobits, IntentParameter.InformationStorage.kilobytes, IntentParameter.InformationStorage.mebibits, IntentParameter.InformationStorage.mebibytes, IntentParameter.InformationStorage.megabits, IntentParameter.InformationStorage.megabytes, IntentParameter.InformationStorage.nibbles, IntentParameter.InformationStorage.pebibits, IntentParameter.InformationStorage.pebibytes, IntentParameter.InformationStorage.petabits, IntentParameter.InformationStorage.petabytes, IntentParameter.InformationStorage.tebibits, IntentParameter.InformationStorage.tebibytes, IntentParameter.InformationStorage.terabits, IntentParameter.InformationStorage.terabytes, IntentParameter.InformationStorage.yobibits, IntentParameter.InformationStorage.yobibytes, IntentParameter.InformationStorage.yottabits, IntentParameter.InformationStorage.yottabytes, IntentParameter.InformationStorage.zebibits, IntentParameter.InformationStorage.zebibytes, IntentParameter.InformationStorage.zettabits, IntentParameter.InformationStorage.zettabytes] }
}
extension IntentParameter.Length: CaseIterable {
    public typealias AllCases = [IntentParameter.Length]

    public static var allCases: [IntentParameter.Length] { return [IntentParameter.Length.astronomicalUnits, IntentParameter.Length.centimeters, IntentParameter.Length.decameters, IntentParameter.Length.decimeters, IntentParameter.Length.fathoms, IntentParameter.Length.feet, IntentParameter.Length.furlongs, IntentParameter.Length.hectometers, IntentParameter.Length.inches, IntentParameter.Length.kilometers, IntentParameter.Length.lightyears, IntentParameter.Length.megameters, IntentParameter.Length.meters, IntentParameter.Length.micrometers, IntentParameter.Length.miles, IntentParameter.Length.millimeters, IntentParameter.Length.nanometers, IntentParameter.Length.nauticalMiles, IntentParameter.Length.parsecs, IntentParameter.Length.picometers, IntentParameter.Length.scandinavianMiles, IntentParameter.Length.yards] }
}
extension IntentParameter.Mass: CaseIterable {
    public typealias AllCases = [IntentParameter.Mass]

    public static var allCases: [IntentParameter.Mass] { return [IntentParameter.Mass.carats, IntentParameter.Mass.centigrams, IntentParameter.Mass.decigrams, IntentParameter.Mass.grams, IntentParameter.Mass.kilograms, IntentParameter.Mass.metricTons, IntentParameter.Mass.micrograms, IntentParameter.Mass.milligrams, IntentParameter.Mass.nanograms, IntentParameter.Mass.ounces, IntentParameter.Mass.ouncesTroy, IntentParameter.Mass.picograms, IntentParameter.Mass.pounds, IntentParameter.Mass.shortTons, IntentParameter.Mass.slugs, IntentParameter.Mass.stones] }
}
extension IntentParameter.Power: CaseIterable {
    public typealias AllCases = [IntentParameter.Power]

    public static var allCases: [IntentParameter.Power] { return [IntentParameter.Power.femtowatts, IntentParameter.Power.gigawatts, IntentParameter.Power.horsepower, IntentParameter.Power.kilowatts, IntentParameter.Power.megawatts, IntentParameter.Power.microwatts, IntentParameter.Power.milliwatts, IntentParameter.Power.nanowatts, IntentParameter.Power.picowatts, IntentParameter.Power.terawatts, IntentParameter.Power.watts] }
}
extension IntentParameter.Pressure: CaseIterable {
    public typealias AllCases = [IntentParameter.Pressure]

    public static var allCases: [IntentParameter.Pressure] { return [IntentParameter.Pressure.bars, IntentParameter.Pressure.gigapascals, IntentParameter.Pressure.hectopascals, IntentParameter.Pressure.inchesOfMercury, IntentParameter.Pressure.kilopascals, IntentParameter.Pressure.megapascals, IntentParameter.Pressure.millibars, IntentParameter.Pressure.millimetersOfMercury, IntentParameter.Pressure.newtonsPerMetersSquared, IntentParameter.Pressure.poundsForcePerSquareInch] }
}
extension IntentParameter.Speed: CaseIterable {
    public typealias AllCases = [IntentParameter.Speed]

    public static var allCases: [IntentParameter.Speed] { return [IntentParameter.Speed.kilometersPerHour, IntentParameter.Speed.knots, IntentParameter.Speed.metersPerSecond, IntentParameter.Speed.milesPerHour] }
}
extension IntentParameter.Temperature: CaseIterable {
    public typealias AllCases = [IntentParameter.Temperature]

    public static var allCases: [IntentParameter.Temperature] { return [IntentParameter.Temperature.celsius, IntentParameter.Temperature.fahrenheit, IntentParameter.Temperature.kelvin] }
}
extension IntentParameter.Volume: CaseIterable {
    public typealias AllCases = [IntentParameter.Volume]

    public static var allCases: [IntentParameter.Volume] { return [IntentParameter.Volume.acreFeet, IntentParameter.Volume.bushels, IntentParameter.Volume.centiliters, IntentParameter.Volume.cubicCentimeters, IntentParameter.Volume.cubicDecimeters, IntentParameter.Volume.cubicFeet, IntentParameter.Volume.cubicInches, IntentParameter.Volume.cubicKilometers, IntentParameter.Volume.cubicMeters, IntentParameter.Volume.cubicMiles, IntentParameter.Volume.cubicMillimeters, IntentParameter.Volume.cubicYards, IntentParameter.Volume.cups, IntentParameter.Volume.deciliters, IntentParameter.Volume.fluidOunces, IntentParameter.Volume.gallons, IntentParameter.Volume.imperialFluidOunces, IntentParameter.Volume.imperialGallons, IntentParameter.Volume.imperialPints, IntentParameter.Volume.imperialQuarts, IntentParameter.Volume.imperialTablespoons, IntentParameter.Volume.imperialTeaspoons, IntentParameter.Volume.kiloliters, IntentParameter.Volume.liters, IntentParameter.Volume.megaliters, IntentParameter.Volume.metricCups, IntentParameter.Volume.milliliters, IntentParameter.Volume.pints, IntentParameter.Volume.quarts, IntentParameter.Volume.tablespoons, IntentParameter.Volume.teaspoons] }
}

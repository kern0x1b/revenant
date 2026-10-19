// DateParsing.swift - the date readings of CSV: the parse strategy a caller adds, and the default parser.
//
// The default parser is the host's, and every rule below is measured on the host's TabularData: the cells
// and the answers are in facts/TabularData/DateParsing.md, and tests/backports/host/createml/csvdates.swift
// reads the same cells through both modules. The host's answers are not Foundation's ISO8601FormatStyle
// (which accepts fractions and refuses a date alone), and the port's Foundation carries no parse strategy
// for armv7 iOS 6.1.3 (measured: no ParseStrategy and no ISO8601FormatStyle in its module), so the reader is
// written here. Measured:
//
// - An extended date-time, `YYYY-MM-DDTHH:MM:SS`, or a basic one, `YYYYMMDDTHHMMSS`, and a zone after it.
//   Extended and basic do not mix. A fraction of a second is refused, and so is a lower-case `t`, a space
//   for the `T`, a missing second, a date without a time, and a time without a zone.
// - The zone is `Z`, or a sign and an offset. In the extended form the offset is applied (`+HH:MM`,
//   `+HHMM`, `+HMM`, `+HH`); in the basic form the offset is not applied at all, and the time is UTC.
//   Anything after the zone is ignored, so `Z ` and `ZZ` read as UTC.
// - A day past the end of its month rolls over: `2024-02-30` is 1 March. An hour of 24 rolls over to
//   the next day. A month of 13, a day of 0 or 32, an hour of 25, and a minute or second of 60 do not read.
// - A cell with a leading space does not read; a trailing space does.
//
// Not reproduced: the host reads an offset whose hour is 24 or more, or a one-digit hour before a colon,
// in ways that are not a rule this port can state from the measurements (`+1:00` is +10:00, `+24:30` is
// +02:00). Those offsets do not read here. The facts file has the table, and crutches.md has the entry.

import Foundation

/// A parse strategy a date column is read by: text to a date, or an error when the text is not one. The
/// framework's is Foundation's `ParseStrategy`, which the port's Foundation does not declare; a strategy
/// is written against this protocol and added with `CSVReadingOptions.addDateParseStrategy(_:)`.
public protocol ParseStrategy {
    associatedtype Input
    associatedtype Output
    func parse(_ value: Input) throws -> Output
}

/// The framework's default date reading: an ISO 8601 date-time with a zone, as measured above.
func parseISODateTime(_ text: String) -> Date? {
    let bytes = Array(text.utf8)
    let extended = bytes.count > 4 && bytes[4] == UInt8(ascii: "-")
    let fields: (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, zone: Int)
    if extended {
        // The extended form. Each separator is at a fixed place; anything else is not a date-time.
        guard bytes.count >= 19, bytes[7] == UInt8(ascii: "-"), bytes[10] == UInt8(ascii: "T"),
              bytes[13] == UInt8(ascii: ":"), bytes[16] == UInt8(ascii: ":"),
              let year = digits(bytes, 0..<4), let month = digits(bytes, 5..<7), let day = digits(bytes, 8..<10),
              let hour = digits(bytes, 11..<13), let minute = digits(bytes, 14..<16), let second = digits(bytes, 17..<19)
        else { return nil }
        fields = (year, month, day, hour, minute, second, 19)
    } else {
        guard bytes.count >= 15, bytes[8] == UInt8(ascii: "T"),
              let year = digits(bytes, 0..<4), let month = digits(bytes, 4..<6), let day = digits(bytes, 6..<8),
              let hour = digits(bytes, 9..<11), let minute = digits(bytes, 11..<13), let second = digits(bytes, 13..<15)
        else { return nil }
        fields = (year, month, day, hour, minute, second, 15)
    }
    guard (1...12).contains(fields.month), (1...31).contains(fields.day), fields.hour <= 24,
          (0...59).contains(fields.minute), (0...59).contains(fields.second),
          fields.zone < bytes.count else { return nil }

    let offset: Int
    switch bytes[fields.zone] {
    case UInt8(ascii: "Z"):
        offset = 0
    case UInt8(ascii: "+"), UInt8(ascii: "-"):
        // The basic form reads the zone and does not apply it: measured, `20240102T030405+02:00` is UTC.
        if extended {
            guard let seconds = offsetSeconds(bytes, at: fields.zone) else { return nil }
            offset = seconds
        } else {
            offset = 0
        }
    default:
        return nil
    }
    let days = daysFromCivil(fields.year, fields.month, fields.day)
    let seconds = days * 86400 + fields.hour * 3600 + fields.minute * 60 + fields.second - offset
    return Date(timeIntervalSince1970: TimeInterval(seconds))
}

private func isDigit(_ byte: UInt8) -> Bool {
    byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
}

/// The digits in a range of the bytes, as a number; nil when the range is past the end or holds a non-digit.
private func digits(_ bytes: [UInt8], _ range: Range<Int>) -> Int? {
    guard range.upperBound <= bytes.count else { return nil }
    var value = 0
    for index in range {
        guard isDigit(bytes[index]) else { return nil }
        value = value * 10 + Int(bytes[index] - UInt8(ascii: "0"))
    }
    return value
}

/// The offset a sign at `at` begins, in seconds east of UTC, with the forms that read: `HH:MM`, `HHMM`,
/// `HMM` and `HH`. The hour is below 24 and the minute below 60; anything else does not read.
private func offsetSeconds(_ bytes: [UInt8], at sign: Int) -> Int? {
    let start = sign + 1
    var hours = 0
    var minutes = 0
    if start + 2 < bytes.count, bytes[start + 2] == UInt8(ascii: ":") {
        guard let h = digits(bytes, start..<start + 2), let m = digits(bytes, start + 3..<start + 5) else { return nil }
        (hours, minutes) = (h, m)
    } else {
        // The digits that follow the sign, up to four: `HHMM`, `HMM` or `HH` read as the hour and minute.
        var count = 0
        while count < 4, start + count < bytes.count, isDigit(bytes[start + count]) { count += 1 }
        switch count {
        case 4:
            guard let h = digits(bytes, start..<start + 2), let m = digits(bytes, start + 2..<start + 4) else { return nil }
            (hours, minutes) = (h, m)
        case 3:
            guard let h = digits(bytes, start..<start + 1), let m = digits(bytes, start + 1..<start + 3) else { return nil }
            (hours, minutes) = (h, m)
        case 2:
            guard let h = digits(bytes, start..<start + 2) else { return nil }
            hours = h
        default:
            return nil
        }
    }
    guard (0...23).contains(hours), (0...59).contains(minutes) else { return nil }
    let seconds = hours * 3600 + minutes * 60
    return bytes[sign] == UInt8(ascii: "-") ? -seconds : seconds
}

/// Days since 1970-01-01 of a date, counted in the calendar the host's Gregorian calendar uses: the Julian
/// one before 1582-10-15, the Gregorian one from it. Measured: 0001-01-01 is two days earlier than the
/// proleptic Gregorian count, which is the Julian count. The day is taken as it is, so a day past the end
/// of its month rolls over into the next.
private func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
    let a = (14 - month) / 12
    let y = year + 4800 - a
    let m = month + 12 * a - 3
    let dayNumber = day + (153 * m + 2) / 5 + 365 * y + y / 4
    let julianNumber = dayNumber - 32083
    let gregorianNumber = dayNumber - y / 100 + y / 400 - 32045
    let beforeCutover = (year, month, day) < (1582, 10, 15)
    return (beforeCutover ? julianNumber : gregorianNumber) - 2440588
}

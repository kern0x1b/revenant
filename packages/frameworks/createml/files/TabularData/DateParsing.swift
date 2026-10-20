import Foundation

public protocol ParseStrategy {
    associatedtype Input
    associatedtype Output
    func parse(_ value: Input) throws -> Output
}

func parseISODateTime(_ text: String) -> Date? {
    let bytes = Array(text.utf8)
    let extended = bytes.count > 4 && bytes[4] == UInt8(ascii: "-")
    let fields: (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, zone: Int)
    if extended {
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

private func digits(_ bytes: [UInt8], _ range: Range<Int>) -> Int? {
    guard range.upperBound <= bytes.count else { return nil }
    var value = 0
    for index in range {
        guard isDigit(bytes[index]) else { return nil }
        value = value * 10 + Int(bytes[index] - UInt8(ascii: "0"))
    }
    return value
}

private func offsetSeconds(_ bytes: [UInt8], at sign: Int) -> Int? {
    let start = sign + 1
    var hours = 0
    var minutes = 0
    if start + 2 < bytes.count, bytes[start + 2] == UInt8(ascii: ":") {
        guard let h = digits(bytes, start..<start + 2), let m = digits(bytes, start + 3..<start + 5) else { return nil }
        (hours, minutes) = (h, m)
    } else {
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

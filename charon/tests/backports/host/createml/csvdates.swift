// csvdates.swift - the port's CSV date readings and Apple's, in one process, over the same cells.
//
// Each cell is read as a one-cell column four ways: inferred, forced to a date, and each of those with a
// strategy added. Apple's TabularData and the port's PortTabularData read the same bytes; the column's kind,
// its values as seconds since 1970, and an error's text, row and column must be equal. A mismatch is a
// failure.
//
// The strategy is the same code on both sides (a day-format formatter in UTC), so what is compared is the
// reader's use of a strategy: the order of the parsers, the default kept under an added one, and a cell a
// strategy does not read. The host's own `Date.ParseStrategy(format:)` reads nothing the host was given
// (measured, dateprobe3 in the run notes), so it is not the oracle for a strategy; the host's answers for the
// default parser are.
//
// The KNOWN cells are the host's lenient offsets, which the port refuses (DateParsing.swift says why). They
// are printed with both answers and are not counted as failures: the gap stays visible in every run.

import Foundation
import PortTabularData
import TabularData

/// A parse strategy both modules run: a day in `yyyy-MM-dd`, in UTC, in the POSIX locale.
struct DayStrategy: Foundation.ParseStrategy {
    typealias Input = String
    typealias Output = Date

    func parse(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { throw CocoaError(.formatting) }
        return date
    }
}

extension DayStrategy: PortTabularData.ParseStrategy {}

struct Probe {
    let label: String
    let csv: String
    let forced: Bool
    let strategy: Bool
}

func quoted(_ cell: String) -> String {
    cell.contains(",") || cell.contains("\"") ? "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : cell
}

func appleRead(_ probe: Probe) -> String {
    var options = TabularData.CSVReadingOptions()
    if probe.strategy { options.addDateParseStrategy(DayStrategy()) }
    let types: [String: TabularData.CSVType] = probe.forced ? ["t": .date] : [:]
    do {
        let frame = try TabularData.DataFrame(csvData: Data(probe.csv.utf8), types: types, options: options)
        let column = frame.columns[0]
        let values = (0..<column.count).map { row -> String in
            if let date = column[row] as? Date { return "\(Int(date.timeIntervalSince1970))" }
            return "\(String(describing: column[row]))"
        }
        return "\(column.wrappedElementType) \(values)"
    } catch let error as TabularData.CSVReadingError {
        return "error \(error.description) | row=\(error.row) column=\(String(describing: error.column))"
    } catch {
        return "other \(error)"
    }
}

func portRead(_ probe: Probe) -> String {
    var options = PortTabularData.CSVReadingOptions()
    if probe.strategy { options.addDateParseStrategy(DayStrategy()) }
    let types: [String: PortTabularData.CSVType] = probe.forced ? ["t": .date] : [:]
    do {
        let frame = try PortTabularData.DataFrame(csvData: Data(probe.csv.utf8), types: types, options: options)
        let column = frame.columns[0]
        let values = (0..<column.count).map { row -> String in
            if let date = column[row] as? Date { return "\(Int(date.timeIntervalSince1970))" }
            return "\(String(describing: column[row]))"
        }
        return "\(column.wrappedElementType) \(values)"
    } catch let error as PortTabularData.CSVReadingError {
        return "error \(error.description) | row=\(error.row) column=\(String(describing: error.column))"
    } catch {
        return "other \(error)"
    }
}

/// The cells read one per record in a column named `t`, with a second column of ones so no cell is a
/// missing record.
let cells = [
    // The extended form, with a zone.
    "2024-01-02T03:04:05Z", "2024-01-02T03:04:05+02:00", "2024-01-02T03:04:05-0500", "2024-01-02T03:04:05+0200",
    "2024-01-02T03:04:05+14:00", "2024-01-02T03:04:05+05", "2024-01-02T03:04:05+0530", "2024-01-02T03:04:05-00:00",
    "2024-01-02T03:04:05ZZ", "2024-01-02T03:04:05Zulu", "2024-01-02T03:04:05Z ", "2024-01-02T03:04:05Z\t",
    "2024-01-02T03:04:05+02:00:00", "2024-01-02T03:04:05+02:00x", "2024-01-02T03:04:05+100", "2024-01-02T03:04:05+1000",
    // The basic form: the zone is read and not applied.
    "20240102T030405Z", "20240102T030405+0200", "20240102T030405-0500", "20240102T030405+02:00",
    "20240102T030405Zulu", "20240102T030405+0200x",
    // Refused: fractions, no zone, a date alone, separators, single digits, bounds.
    "2024-01-02T03:04:05.123Z", "2024-01-02T03:04:05.Z", "2024-01-02T03:04:05,123Z", "2024-01-02T03:04:05",
    "2024-01-02", "2024-01-02 03:04:05Z", "2024-01-02t03:04:05z", "2024-01-02T03:04:05z", "2024-01-02T03:04Z",
    "2024-01-02T03:04:5Z", "2024-01-02T03:04:05 Z", "2024-01-02T03:04:05 +02:00", "2024-1-02T03:04:05Z",
    "2024-01-02T3:04:05Z", "2024-001T03:04:05Z", "2024-01-02T030405Z", "20240102T0304Z", "20240102T030405",
    "20240102T030405 Z", "2024-01-02T03:04:05UTC", "2024-W01-1", "not a date", " 2024-01-02T03:04:05Z",
    "2024-01-02T03:04:05Z\u{00A0}", "\u{00A0}2024-01-02T03:04:05Z", "2024-13-01T00:00:00Z", "2024-01-32T00:00:00Z",
    "2024-00-02T00:00:00Z", "2024-01-00T00:00:00Z", "2024-01-02T25:00:00Z", "2024-01-02T03:60:00Z",
    "2024-01-02T03:04:60Z", "0000-00-00T00:00:00Z", "-0001-01-01T00:00:00Z", "2024-01-02T03:04:05-",
    // Rollover: a day past the month, an hour of 24.
    "2024-02-30T00:00:00Z", "2023-02-29T00:00:00Z", "2024-04-31T00:00:00Z", "2024-01-02T24:00:00Z",
    "2024-01-02T24:30:00Z", "2024-01-02T24:00:01Z", "2024-01-02T23:59:59Z", "0001-01-01T00:00:00Z",
    "0000-01-01T00:00:00Z", "9999-12-31T23:59:59Z", "2024-01-31T00:00:00Z",
    // The calendar change of 1582: the Julian calendar before 1582-10-15, the Gregorian from it, and the
    // days between that do not exist in either.
    "1582-10-04T00:00:00Z", "1582-10-05T00:00:00Z", "1582-10-10T00:00:00Z", "1582-10-14T00:00:00Z",
    "1582-10-15T00:00:00Z", "1500-02-29T00:00:00Z", "1700-02-29T00:00:00Z", "1000-01-01T00:00:00Z",
    "0100-03-01T00:00:00Z", "1969-12-31T23:59:59Z", "1970-01-01T00:00:00Z",
    // Locale-dependent text: the default reader does not read it.
    "02/01/2024", "2 Jan 2024", "Jan 2, 2024", "02.01.2024", "2/1/2024", "02/01/2024 10:00", "31/02/2024",
    // Empty and blank.
    "",
]

/// The host's lenient offsets, measured: the host reads them, the port refuses them.
let known = [
    "2024-01-02T03:04:05+1:00", "2024-01-02T03:04:05+1:30", "2024-01-02T03:04:05+0:00",
    "2024-01-02T03:04:05+24:30", "2024-01-02T03:04:05+24:00", "2024-01-02T03:04:05+99:99",
]

var probes: [Probe] = []
for cell in cells {
    let csv = "t,u\n\(quoted(cell)),1\n"
    probes.append(Probe(label: "inferred [\(cell)]", csv: csv, forced: false, strategy: false))
    probes.append(Probe(label: "forced [\(cell)]", csv: csv, forced: true, strategy: false))
    probes.append(Probe(label: "forced+strategy [\(cell)]", csv: csv, forced: true, strategy: true))
    probes.append(Probe(label: "inferred+strategy [\(cell)]", csv: csv, forced: false, strategy: true))
}
// Whole columns: inference over several cells, a missing cell, and a blank record.
let columns = [
    "t\n2024-01-02T03:04:05Z\n2024-01-03T03:04:05Z\n",
    "t\n2024-01-02T03:04:05Z\nnot a date\n",
    "t\n2024-01-02T03:04:05Z\n\n2024-01-03T03:04:05Z\n",
    "t\n2024-01-02T03:04:05Z\n\n",
    "t\n\n2024-01-02T03:04:05Z\n",
    "t\n2024-01-02T03:04:05Z\n20240103T030405Z\n",
    "t\n2024-01-02T03:04:05Z\n1\n",
    "t\n20240102\n",
    "t,u\n,1\n,2\n",
    "t\n\"2024-01-02T03:04:05Z\"\n",
    "t\n2024-01-02T03:04:05Z\n2024-01-02\n",
]
for csv in columns {
    probes.append(Probe(label: "column \(csv.replacingOccurrences(of: "\n", with: "|"))", csv: csv, forced: false, strategy: false))
    probes.append(Probe(label: "column+strategy \(csv.replacingOccurrences(of: "\n", with: "|"))", csv: csv, forced: false, strategy: true))
}
// A quoted cell that fails is reported with its quotes, as the host reports it; a numeric one likewise.
probes.append(Probe(label: "quoted forced date with quotes inside", csv: "t\n\"2024-01-02\"\"x\"\n", forced: true, strategy: false))
probes.append(Probe(label: "quoted forced integer", csv: "t\n\"abc\"\n", forced: false, strategy: false))

var checks = 0
var failures = 0
for probe in probes {
    checks += 1
    let host = appleRead(probe)
    let port = portRead(probe)
    if host == port {
        print("ok    \(probe.label): \(host)")
    } else {
        failures += 1
        print("FAIL  \(probe.label)")
        print("  apple: \(host)")
        print("  port:  \(port)")
    }
}

// The lenient offsets: printed with the host's answer and the port's, not counted.
for cell in known {
    let probe = Probe(label: cell, csv: "t,u\n\(cell),1\n", forced: true, strategy: false)
    print("KNOWN [\(cell)] apple: \(appleRead(probe)) | port: \(portRead(probe))")
}
print("\(checks) checks, \(failures) failures, \(known.count) known gaps")

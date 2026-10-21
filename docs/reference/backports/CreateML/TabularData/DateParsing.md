# Date reading in TabularData: what is measured, and what is carried

Source of every behaviour below: the host's own `TabularData` (macOS 27 SDK, Swift 6.4), run on the same
cells. The parser is `frameworks/Backports/src/TabularData/DateParsing.swift`, and the reader's use of it is in
`frameworks/Backports/src/TabularData/CSVReading.swift`. The comparison (no longer in the repository): each
cell is read inferred and forced, with and without a strategy, and both modules must agree on the column's
kind, its values in seconds since 1970, and an error's text, row and column.

## Carried

- `CSVReadingOptions.dateParsers` (the array, starting with the framework's default parser) and
  `CSVReadingOptions.addDateParseStrategy(_:)`, which appends a parser.
- `ParseStrategy`, the port's protocol for a strategy: `Input`, `Output` and `parse(_:)`. It stands in for
  Foundation's `ParseStrategy`, which the port's Foundation does not declare, so a caller's strategy is a
  type the caller writes against this protocol.
- A column is a date column when every present cell is read by some parser. A forced `.date` column reads
  each cell with the parsers in order, and the first that returns a date reads it; a cell none reads is a
  `failedToParse` error.

## The default parser (measured)

Accepted, with the zone read as written:

- `2024-01-02T03:04:05Z`, and the same with `ZZ`, `Zulu`, or any text after the `Z` (ignored).
- `2024-01-02T03:04:05+02:00`, `+0200`, `+02`, `+100` (one hour and no minutes, read as 01:00), `-05:00`,
  `-0500`, and text after the offset (`+02:00x`, `+02:00:00`, `+02:00 `) which is ignored. A one-digit hour
  before a colon (`+1:00`) is not in this list: see the offsets the port refuses.
- The basic form `20240102T030405Z`, and the same with `+0200`, `-0500`, `+02:00`, `+02`, `+1:00`, `Zulu`,
  `+0200x`: in the basic form the zone is read and not applied, so each is 2024-01-02 03:04:05 UTC.
- Trailing whitespace after the zone: a space, a tab, a newline, two spaces (ignored).
- Days past the month end roll over: `2024-02-30` is 2024-03-01, `2023-02-29` is 2023-03-01, `2024-04-31` is
  2024-05-01. An hour of 24 rolls over to the next day (`24:00:00`, `24:30:00`, `24:00:01`).
- The bounds `0000-01-01` and `9999-12-31T23:59:59Z` read. Year 0001 and year 0000 use the Julian calendar.

Refused (nil):

- A fraction: `03:04:05.123Z`, `03:04:05.Z`, `03:04:05,123Z`, `20240102T030405.5Z`.
- A lower-case `t` or `z`; a space for the `T`; a space before the zone (`03:04:05 Z`).
- A missing second (`03:04Z`); a date alone (`2024-01-02`); a time with no zone (`03:04:05`).
- Single digits (`2024-1-02`, `3:04:05Z`); an ordinal (`2024-001T03:04:05Z`); mixed forms
  (`2024-01-02T030405Z`, `20240102T0304Z`).
- Out-of-range fields: month `00` and `13`, day `00` and `32`, hour `25`, minute `60`, second `60`.
- A negative year (`-0001-01-01T00:00:00Z`), a leading space or a leading tab.
- Locale text: `02/01/2024`, `2/1/2024`, `2 Jan 2024`, `Jan 2, 2024`, `02.01.2024`, `02/01/2024 10:00`.
  The default reader does not read a date in a locale's own format.
- The empty cell is a missing value, not a date (`""` reads as nil in a date column).

The calendar: before 1582-10-15 the host counts in the Julian calendar, from 1582-10-15 in the Gregorian.
Measured on the days 1582-10-04, 10-05, 10-10, 10-14, 10-15, `1500-02-29`, `1700-02-29`, `1000-01-01`,
`0100-03-01`, `1969-12-31T23:59:59Z` and `1970-01-01`, and the port matches on each.

## Inference

A column of only date cells is a date column (measured: `2024-01-02T03:04:05Z`, `20240103T030405Z`, and a
blank line among them). One cell that does not read, a text cell, or a number makes it a string column. A
column with no present cell is a string column. A missing cell in a date column reads as nil.

Inference with a strategy added uses the strategy as well: measured, a column of fractional ISO 8601 cells
is a date column under Foundation's `ISO8601FormatStyle`, which the default parser refuses; and under a day
strategy a column that mixes a date-time with `2024-01-02` is a date column, where without the strategy it is
a string column.

## Strategies (measured on the host)

- `Date.ParseStrategy(format:locale:timeZone:)` read nothing the host was given: every combination of seven
  formats (`yyyy-MM-dd`, `dd/MM/yyyy`, `MM/dd/yyyy`, `d/M/yyyy`, `d MMM yyyy`, `dd.MM.yyyy`,
  `yyyy-MM-dd HH:mm`), seven inputs and three locales (`en_US_POSIX`, `en_US`, `de_DE`) failed with
  "String should adhere to the preferred format of the locale". So the host's answer to a format strategy is
  that error, and the port has no such strategy to match.
- A strategy added to the reader keeps the default parser: `2024-01-02T03:04:05Z` reads under a day strategy.
- A cell that a strategy does not read is an error, and the error is the same as for a cell the default does
  not read.
- `Date.ISO8601FormatStyle()`: reads `2024-01-02T03:04:05.123Z` and `2024-01-02T03:04:05+02:00`; refuses
  `2024-01-02` and `not a date`. Not carried: it is Foundation's type, which the device does not have.

## The offsets the port refuses (measured, and not reproduced)

The host's default parser reads these, and the port returns nil. They are listed here with the host's
answer, and tests/backports/host/createml/csvdates.swift prints each one as a KNOWN gap every run.

| cell (the zone part after `03:04:05`) | host reads as |
| --- | --- |
| `+1:00` | +10:00 |
| `+1:30` | +13:00 |
| `+0:00` | +00:00 |
| `+24:30` | +02:00 |
| `+24:00` | +02:00 |
| `+99:99` | +09:00 |

The sweep (hours 0 to 30, with `+H:30`, `+H:00`, `+HH:30`, `+HH30` and `+HH`, and the negative forms) shows
that an hour of 24 and above reads as its tens digit, and that a one-digit hour before a colon reads as a
two-digit hour made of that digit and the first minute digit (`+1:30` is 13). The minutes of those forms are
not the minutes written. No single rule states every row, so the port refuses them rather than guess. The
well-formed offsets (`HH:MM` with an hour below 24 and a minute below 60, `HHMM` likewise, `HH`, and `HMM` as
measured with `+100`) read as the host reads them, and the differential checks the forms it was given.

## Not carried

- Foundation's `Date.ParseStrategy(format:)` and `Date.ISO8601FormatStyle`: the device's Foundation has no
  such types, and the host's format strategy reads nothing (above).
- The `ColumnID` variants and the JSON readers (the facts file for CSV lists them).
- Device verification: none. The parser is checked on the host by the differential; the sources compile for
  `armv7-apple-ios6.1.3` at the package's flags.

# CSV reading in TabularData: what is measured, and what is carried

Source of every behaviour below: the host's own `TabularData` (macOS 27 SDK, Swift 6.4), run on the same
bytes. The reader is `files/TabularData/CSVReading.swift`; the comparison is
`tests/backports/host/createml/csvreading.swift`, which runs both in one process and fails on any
difference. The declarations are the SDK's, as the spec rows give them
(`the deleted registry package spec/TabularData/swift.tsv`).

## Carried

- `CSVType`, `CSVReadingOptions` (the initialiser and every property, with the framework's defaults),
  `CSVReadingError` (every case, `row`, `column`, `description`, `errorDescription`),
  `DataFrame(csvData:columns:rows:types:options:)` and `DataFrame(contentsOfCSVFile:columns:rows:types:options:)`.
- The rules, each measured:
  - An integer column is one whose every present cell parses as an `Int`; otherwise a double column
    (`floatingPointType` decides `.double` or `.float`) when every cell parses under `strtod`; otherwise a
    boolean column when every cell is a true or false encoding once surrounding spaces are removed; otherwise
    a string column. A column with no present cell is a string column.
  - A column with one cell that is not UTF-8 is a `Data` column, every cell read as its bytes.
  - An unquoted cell whose text is a nil encoding is missing. A quoted cell is never missing: `""` reads as
    the empty string, which is `0.0` in a numeric column and text in a string column.
  - A bare sign reads as the integer zero (`+` and `-`); `-9223372036854775808` does not read as an
    integer and makes the column a double.
  - A blank line is skipped when `ignoresEmptyLines`; a record of spaces and tabs alone is blank too.
  - A byte-order mark is removed; `\r\n` and a lone `\r` both end a record.
  - A duplicated header name becomes `name.1`, `name.2`, and so on; an empty one becomes `Column N`.
  - `hasHeaderRow: false` names the columns `Column 0`, `Column 1`, and so on.
  - `usesEscaping` makes the escape character read the byte after it, inside a quoted field and outside one.
  - Errors: the row counts from 1 over the records after the header, the column from 0. A request for
    rows past the end names the row asked for and the number of records in the file, the header included.
  - `badEncoding`: a string column (forced) with a cell that is not UTF-8.
  - Dates: a column of date cells reads as a date column, and a forced date column reads each cell through the
    parsers. The rules, the calendar and the strategies are in `facts/TabularData/DateParsing.md`.
  - `failedToParse` carries the cell as it is in the file, with its quotes (measured on a quoted date cell and a
    quoted integer); its text reads `Cell contents are '...'` when the cell is UTF-8,
    `Cell contents bytes are [...]` when it is not.
  - UTF-16 with a byte-order mark is `unsupportedEncoding`, named `Unicode (UTF-16LE)` or `Unicode (UTF-16BE)`.

## Not carried yet (rows the spec has, the port does not)

- The `ColumnID` variants of both readers (`repeat each T`, iOS 18.4).
- JSON: `JSONType`, `JSONReadingError`, `JSONReadingOptions`, `JSONWritingOptions`, the JSON initialisers
  and writers.
- A line of spaces among the records: the host folds it into the header; with blank lines kept it reads the
  line as a missing cell. Printed by the suite as OPEN, not counted.
- Device verification: none yet. The module compiles for `armv7-apple-ios6.1.3` with the port's compiler; no
  run on a device or in the emulator has been made for this reader.

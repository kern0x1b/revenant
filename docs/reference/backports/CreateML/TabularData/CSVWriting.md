# CSV writing in TabularData: what is measured, and what is carried

Source of every behaviour below: the host's own `TabularData` (macOS 27 SDK, Swift 6.4), run on the same
frames. The writer is (a file of an earlier layout, not in the repository); the comparison is
(a file of an earlier layout, not in the repository), which builds each frame in both modules, writes it with each
module's options, and fails on any difference in the bytes, or in the error's case, row, column, cell bytes
and text. The declarations are the SDK's, as the spec rows give them
(`the deleted registry package spec/TabularData/swift.tsv`).

## Carried

- `CSVWritingOptions` (every initialiser and property, with the framework's defaults), `CSVWritingError`
  (`badEncoding`, `row`, `column`, `description`), `DataFrame.csvRepresentation(options:)` and
  `DataFrame.writeCSV(to:options:)`.
- The rules, each measured:
  - The header is the column names, written raw: a name with a comma or a quote is not quoted or escaped.
    It is not written for a frame with no columns, and a frame with no rows writes the header alone.
  - A cell is quoted when its text holds the delimiter, a quote, a line feed or a carriage return; a quote
    inside it is doubled. A tab does not need quotes.
  - A missing cell is the nil encoding, and so is a cell past the end of a shorter column.
  - A string is written as itself; an integer in decimal; a double as the host's description (`1e+22`,
    `1e-07`, `-0.0`, `nan`, `inf`, `0.30000000000000004`); a float the same way, at its own precision.
  - A boolean is the true or false encoding.
  - A date is written by the default formatter, ISO 8601 with a `Z` and the fraction dropped
    (`1970-01-02T00:00:00Z` for 86400.5), in UTC; or by the format the options were made with, in UTC,
    in the POSIX locale (`1970/01/02 00:00`).
  - A `Data` cell is written as its UTF-8 text, quoted by the same rule. Bytes that are not UTF-8 make the
    write fail with `badEncoding`: `row` is the 0-based index of the data row, `column` is the column's
    name, and the description is `Bad UTF8 encoding at row R column 'C': [bytes].`
  - A column of an element type the writer does not name (a `UUID`, measured) is written by the value's
    description.
  - `CSVWritingOptions(...)` stores a line feed whatever `newline` it is given, in both initialisers, with
    and without a date format. Assigning `newline` afterwards is honoured. The `delimiter` argument and
    property are honoured, as are the nil, true and false encodings, and `dateFormatter` assigned as a
    property.

## Not carried (rows the spec has, the port does not)

- `DataFrameProtocol`: the spec declares `csvRepresentation(options:)` and `writeCSV(to:options:)` on the
  protocol. The port's are on `DataFrame` itself, so a caller written against the protocol does not compile.
- The JSON writer (`jsonRepresentation(options:)`, `writeJSON(to:options:)`, `JSONWritingOptions`).
- Device verification: none yet. The TabularData sources compile for `armv7-apple-ios6.1.3` with the port's
  compiler, at the flags the package passes; the package's own xmake build has not run for this writer, and
  no run on a device or in the emulator has been made.

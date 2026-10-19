# NSScanner scanUnsignedLongLong:, iOS 7

Source: the host's own Foundation, asked eleven strings twice each and held against the backport by the
`scanner.*` records of `tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3 on the emulator, an
iPhone 4S and an iPad 2, through `tests/backports/device/foundation2.m`.

The scanner skips the characters it is told to skip (whitespace and newlines by default), takes an optional plus
sign and then decimal digits. It answers YES and moves its location past the digits it read, or answers NO and
leaves both the location and the result where they were:

| string | first call | second call |
|---|---|---|
| `18446744073709551615` | YES, 18446744073709551615, location 20 | NO, result untouched |
| `0` | YES, 0 | NO |
| `  42  7` | YES, 42, location 4 | YES, 7, location 7 |
| `-5` | NO, location 0 | NO |
| `99999999999999999999999` | YES, 18446744073709551615, location 23 | NO |
| `12abc` | YES, 12, location 2 | NO |
| `abc`, the empty string | NO | NO |
| `0012` | YES, 12, location 4 | NO |
| `+7` | YES, 7, location 2 | NO |
| `9223372036854775808` | YES, 9223372036854775808 | NO |

A number too big for 64 bits does not fail: it answers the biggest value, `ULLONG_MAX`, and the location is past every
digit. A minus sign is not part of an unsigned number, so `-5` is not scanned at all. The result pointer may be
NULL, and the scanner then only moves.

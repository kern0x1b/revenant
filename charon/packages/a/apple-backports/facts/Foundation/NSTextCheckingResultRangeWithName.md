# Named capture ranges, iOS 11.0

Introduced in iOS 11.0 on iOS: `-rangeWithName:` answers the range a named capture
group matched, given the group's name.

Source: the SDK 16.4 headers; the armv7 caches under `$HOME/.charon/dyld/<release>/`
for the ICU data version and the `uregex_*` exports; `tests/backports/host/rangewithname`
against the host's own method.

## Where named groups come from

The method is a lookup on top of the regular expression engine: name to group
number, then `-rangeAtIndex:`. Whether a pattern can carry a name at all is the
engine's business, and the engine is the release's `libicucore`. Measured on the
cache ladder, `icudt` version and whether `uregex_groupNumberFromName` is exported:

| releases | ICU | `uregex_groupNumberFromName` |
| --- | --- | --- |
| 3.1.3 – 8.4.1 | 40 – 53 | absent |
| 9.0 – 10.3.4 | 55, 57 | exported |

ICU 55 added `(?<name>...)` and the lookup together. Below it, `(?<x` parses only as
a look-behind, so a pattern that names a group does not compile. From iOS 9 on it
compiles, and the method is the only thing missing.

## What the package does

`-rangeWithName:` asks the release's own ICU for the number: it opens the result's
`regularExpression` pattern with `uregex_open`, the `NSRegularExpressionOptions`
mapped to their ICU flags, calls `uregex_groupNumberFromName`, and answers
`-rangeAtIndex:` of that number. The numbers are kept per expression, since an
expression never changes. This is what swift-corelibs-foundation's
`range(withName:)` does through `_CFRegularExpressionGetCaptureGroupNumberWithName`.

A name the pattern does not carry, a result of no expression and a `nil` name answer
`{NSNotFound, 0}`, as the system's does. On 6.x–8.x `uregex_groupNumberFromName` is
not exported and no pattern there carries a name, so the method answers
`{NSNotFound, 0}` for every name, which is what iOS 11 answers for a name absent from
the pattern.

## An earlier version was wrong from iOS 9 on

The first version answered `{NSNotFound, 0}` unconditionally, reasoning from 6.1.3's
ICU 49 alone that no pattern could ever carry a name. The file serves every band
below 11.0, and 9.0–10.3.4 compile named groups: there it answered "no such group"
for a group the pattern has. `host/rangewithname` fails 48 of its 98 checks against
that version. A wall measured on one release is not a wall on the range the file
covers: measure it on every band the object goes into.

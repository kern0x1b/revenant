# NSDateIntervalFormatter, iOS 8.0

The class arrived in iOS 8.0 and the port carries it from **5.0**, and the class is the release's own
`DateIntervalFormat` underneath: the port calls `udtitvfmt_open`, `udtitvfmt_format`,
`udtitvfmt_setAttribute` and `udtitvfmt_close`, the four entry points of ICU's date-interval formatter,
the way the release's own class calls them.

## Why 5.0 and not 6.0, and not 4.3

Measured on the armv7 caches, `_udtitvfmt_*` in `/usr/lib/libicucore.dylib`:

| release | libicucore exports | `_udtitvfmt_*` |
| --- | --- | --- |
| **4.3** | 4727 | **0** |
| 5.0 | 5187 | 4 |
| 6.0 | 5311 | 4 |
| 6.1.3 | 5311 | 4 |
| 7.0 | 5459 | 4 |
| 8.0 | 6195 | 4 |
| 9.0 | 6472 | 4 |
| 10.0.1 | 6710 | 4 |

The four are `udtitvfmt_open`, `udtitvfmt_format`, `udtitvfmt_setAttribute` and `udtitvfmt_close`.
6.1.3 links `icudt49_dat`, so its `udtitvfmt_open` is **ICU 49's** six-argument form, with a
`const char *locale` first, then the skeleton as `UChar` and its length, then the zone the same way,
then the status. That is the signature the port calls; the four symbols are imported weakly and the
gate places them at 5.0.

**4.3 does not carry the class**, and the reason is that table: its `libicucore` exports no
`udtitvfmt_*`. A 4.3 path would mean vendoring ICU into the package, which is a later item and not
this one.

**And the whole library links `libicucore` in every band, strongly, including 4.3.** The link is a
property of `FoundationBackports` and not of a band, and `modules/apple/deps.lua` turns a library name
into `-l<name>` with no weak form, so a 4.3 band that does **not** use this class still carries an
LC_LOAD_DYLIB for `libicucore`, whose four symbols the 4.3 release exports none of. What is weak is
the three **imports**: they are declared `__attribute__((weak_import))` and bind NULL on 4.3, which is
what `-[NSDateIntervalFormatter charon_intervalFrom:to:]` checks for before its first call. So the
cost is one load command a band does not need and one library on a release whose libicucore holds
none of the four symbols, and not a fault: the import check passes because 4.3 *has* a libicucore, and
the release is never asked for a symbol it does not have. A weak form in `deps.lua` would fix it and
that file is shared with every package, so it is a change for the coordinator and not for this file.

## What comes from the release and what comes from the port

From the **release**, which is the point of the route: the join between a date and a time and
between the two ends of a range, the collapse of a shared day, the way each style pairs its fields,
and every locale's own choice of all of it. The header's own examples need nothing reproduced — the
release's `DateIntervalFormat` produces them, `MMMd` giving "Mar 4" in en_US and "4 Mar" in en_GB for a
range inside one day, and `jm` giving "7:56 AM - 7:56 PM" against "7:56 - 19:56".

From the **port**: the six properties, the two methods, the two styles and the template turned into
one **skeleton** for the release, and the two defaults the header states wrongly. The header says both
styles are `NSDateIntervalFormatterNoStyle` and the template is the empty string; the host reads
**both styles back as 1, the short style**, and the template back as `dd/MM/y, HH:mm` - the combined
short pattern, not an empty string. Both are measured in the golden file, as the `defaults` lines
beside the 3375 cases, and the port answers the measured answers (the review's finding E).

A skeleton's **repetitions are the width, and they are kept**: `yMMMd` is the abbreviated month and `yMMMMd`
the full one, `jmms` a two-digit minute and `jmmszzzz` a long zone name. An earlier version dropped
the repeats and collapsed 21 of the 25 style pairs onto a handful of skeletons - the review's finding
A - and the 25 are now checked against the review's own no-dedup reference, line for line.

A `dateTemplate` is a **template, not a skeleton**, so the release expands it:
`+[NSDateFormatter dateFormatFromTemplate:options:locale:]`, the same 5.0 floor, gives the **pattern**,
and a pattern is not a skeleton either — `h:mm a` is three fields and a meridiem where the skeleton is
`jm`, `M/d/y, h:mm a` where it is `yMdjm`, `MMMM d, y` where it is `yMMMMd`. So the pattern is
**reduced** to a skeleton: every run of one field letter becomes a count, the fields are put in CLDR's
order, `h`/`k`/`K` become the locale's hour symbol `j`, and the meridiem goes as implied by the hour. The
26.2 header calls `jm` and `MMMd` skeletons and says they give "7:56 AM - 7:56 PM" and "Mar 4", and the
105 template cases are what holds it. Before this
the template was handed to `udtitvfmt_open` verbatim, which asks the release for a skeleton and gives
it a pattern - the review's finding D. The golden file carries 105 template cases, the header's own
examples (`jm`, `MMMd`, `yMdjm`, `yMMMMd`, `jmv`, `MMMdjmss`, `Hm`) over five locales, so the row is
held.

`udtitvfmt_format` is called with **six** arguments, which is ICU 49's own declaration and the
version 6.1.3 links (`icudt49_dat`). A seventh `const void *position` appears in Apple's ICU in later
builds; the port does not pass one, and with the wrong arity the status lands in the wrong register,
ICU answers an error and the class returns nil rather than misbehaving - a missing answer, not a crash.
Read out of the 6.1.3 cache the function is at `0x38b03420` and reaches its stack arguments through a
frame pointer the prologue builds before the sp alignment, so the count is not readable off the first
instructions alone; the device program is what settles it (the review's finding B).

The skeleton of a style pair is the date skeleton and the time skeleton joined, the date's fields
first and each field letter once:

| style | date | time |
| --- | --- | --- |
| short | `yMd` | `jm` |
| medium | `yMMMd` | `jmms` |
| long | `yMMMMd` | `jmmsz` |
| full | `yMMMMdE` | `jmmszzzz` |

A `dateTemplate` names the skeleton instead, which is what the release's
`+[NSDateFormatter dateFormatFromTemplate:options:locale:]` would expand and what its interval
formatter expects. The four symbols are asked weakly: a release without them answers nil rather than
faulting, and 4.3 is below the floor anyway.

## device-unverified

**This path is not held by a macOS differential and none is claimed.** The host's own `libicucore`
refuses the call the port makes — `udtitvfmt_open` answers a handle and
`U_ILLEGAL_ARGUMENT_ERROR` (-128) for every skeleton, zone and locale tried, and the seven- and
three-argument forms segfault — so the host's `NSDateIntervalFormatter` and the port's call do not meet
anywhere on this machine. That is not a defect in the port: the release's ICU 49 is what the port runs
on, and the host's is a different build.

What holds it instead is a **golden file** and a device run:

- `tests/backports/device/dateinterval/make-expected.m` writes the host's own
  `NSDateIntervalFormatter` over **fifteen locales** x the **twenty-five pairs** of the five styles x
  **three zones** (UTC, America/New_York, Europe/Warsaw) x **three date pairs** (an hour inside one
  day, across midnight, into the next year), plus the `defaults` of a formatter nothing was set on and
  **105 template cases** over five locales, into
  `tests/backports/device/dateinterval/expected.txt` — **3480 cases**, one line each, tab-separated, in
  a fixed order so a diff means something;
- `tests/backports/device/dateinterval.m` runs the port on the device, asks each case, and compares
  line by line, printing the first twenty that differ and then the count. It also checks that
  `-stringFromDateInterval:` and `-stringFromDate:toDate:` agree, and says whether the class it got
  is the port's or the release's.

A 4.3 run has no such class - the floor is 5.0 and `band()` leaves the object out below it - so the
program says so and stops rather than failing, and the `below6` entry carries a waiver for it.

**That run has not happened.** Until it does, the registry's `source` for every row of this class
says `device-unverified`, and so does the commit that carries it.

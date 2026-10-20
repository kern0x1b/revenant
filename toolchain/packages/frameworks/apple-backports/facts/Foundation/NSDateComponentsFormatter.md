# NSDateComponentsFormatter, iOS 8

Introduced in iOS 8: a formatter that writes a span of time as text - "1h 2m 5s", "about 5 days remaining",
"one hour, two minutes" - in five styles (positional, abbreviated, short, full, spelled out).

Source: the host's own Foundation, asked for every answer and held against the port by two runs. The `datecomponentsformatter`
group of `tests/backports/host/uikit2/run.sh` compiles the port with its names changed and puts it beside the system's
class, and compares 3000 random configurations at twelve intervals each. `tests/backports/host/datecomponents` records
the system's answers for a fixed set of cases into `device/datecomponents-expectations.h`, and `device/datecomponents.m`
compares the port to them on the device. The shared caches of iOS 6.0 and 7.0 have no such class.

## What the port does as the system does

The units it may show are years, months, weeks of the month, days, hours, minutes and seconds; any other unit raises
`NSInternalInconsistencyException` with the system's reason, a time interval that is not a number raises
`NSInternalInconsistencyException`, and empty components answer `nil`. A negative span is written as its magnitude with the
sign on the first unit shown, and by the number formatter, so a spelled-out one reads "minus one hour". Positional
units must be contiguous or the system's `NSInvalidArgumentException` is raised. The zero-formatting bits drop leading,
middle and trailing zeros or pad, and the default drops all of them (leading ones only for a positional style).
The maximum unit count keeps the largest units and rounds the remainder into the last one kept, with the carry into the
next larger allowed unit; the largest unit collapses into the next one when that is below a tenth or above nine tenths
of it, for month to day, day to hour, hour to minute and minute to second. The approximation and time-remaining
phrases, fractional units and the calendar and reference date are honoured. Numbers go through the number formatter of
the current locale.

## What it cannot do

The words are English. The system has its own table of unit names for every language it ships; the port carries none,
so a device in another language reads the same English words with that language's digits. `formattingContext` is kept
and not acted on.

Rare combinations differ: with negative spans, with weeks together with years or months, and with a collapse that
meets a year or a week, the system's own answer follows from its calendar arithmetic and the port's is the nearest
whole reading. The random comparison measures 3.6% of 36000 answers differing.

## The reference date, iOS 11

`referenceDate` is the date the formatter counts from when it is asked for a span of time and not for two dates
(`stringFromTimeInterval:` and `stringFromDateComponents:`), so 45 days written as months and days is one month and 14
days from the first of January and one month and 16 from the first of February. Set to `nil`, it is the reference date of
the system, 1 January 2001, in every time zone, and not the current date: the port counted from the current date until
`tests/backports/host/referencedate` asked the system, over 2773 configurations, what nil stands for.

A span that is negative is counted backwards from the reference date, so that -45 days from 1 March 2020 is one month and
two weeks and two days, where counting forwards from the date 45 days earlier gives another number of days; the
magnitudes are written with the sign on the first unit shown. A copy of the formatter takes its units style, allowed units,
zero formatting behaviour, calendar, maximum unit count and the flags, and not the reference date or the formatting
context, as `-copyWithZone:` of iOS 12.0 does.

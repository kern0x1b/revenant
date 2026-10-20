# NSCalendar, the units of iOS 8

Source: the host's own Foundation, through the differential run of
`tests/backports/host/foundation2/run.sh`, which holds the backport and the system to the same 12702
answers; the identifiers were read from the system's own constants.

## The quarter

`NSCalendarIdentifierGregorian` is the string `gregorian` and `NSCalendarIdentifierISO8601` is
`iso8601`; the deprecated `NSGregorianCalendar` carries the same `gregorian`. The backport compares the
calendar's identifier with those strings rather than with the constants, which a release older than
iOS 4.0 does not export at all: a comparison against a null constant answers no for every calendar, and
the quarter would be silently zero everywhere.

A quarter is computed only for those two calendars, as `(month - 1) / 3 + 1`. For any other calendar the
answer is zero, which is what Foundation itself answers - the differential run holds the two side by side
on the Hebrew calendar and both say zero. Zero is not the undefined value of a date component, and that
difference is Apple's, not ours.

## The nanosecond

A date carries its time as a double of seconds, so the nanosecond is read back from the fraction and
rounded, and it is capped at 999999999 so that a rounded fraction never reads as a whole second. Around
2026 a double holds about 240 nanoseconds of resolution, so the low digits of the answer are not the ones
a release with a nanosecond field of its own would give.

## Setting a time the clock skips

Europe/Berlin moves its clocks forward on 29 March 2026, so 02:30 does not happen that day. The system
answers `-dateBySettingHour:minute:second:ofDate:options:` for 02:30 of that day with **03:00**, the instant
the clock jumps to, and the same for `NSCalendarMatchNextTime`; with `NSCalendarMatchStrictly` it answers
**02:30 of the next day**, the first day the time exists again. The start of that day is 00:00 as on any
other day.

The backport used to set the components and hand back whatever the calendar made of them, which is 03:30 -
the requested minutes carried into the shifted hour - for all three options. It now checks that the time it
reached is the time it asked for, and, when it is not, answers the daylight saving transition of that day,
or, for a strict match, walks the following days until the time exists.

Checked against the host across five zones with real daylight saving rules - New York, Moscow, Lord Howe
Island, São Paulo, Apia - every hour from January 2020 to October 2024, setting every third hour of the day
(00:30, 03:30, 06:30, ..., 21:30) on each: 1666680 answers, none of them different from the host's. The
device test holds iOS 6 to five of them, the half hours from 00:30 to 04:30 the day before New York's
spring transition of 2023, which answer the instants themselves, including the jump at 02:30 to 03:00.

## Setting a unit, and searching for one

`-dateBySettingUnit:value:ofDate:options:`, `-nextDateAfterDate:matchingComponents:options:` and
`-enumerateDatesStartingAfterDate:matchingComponents:options:usingBlock:` do not do what a plain reading of
the header suggests - "take the date's components, change the one field, hand them back." Measured against
the host, era down to second all share one shape: every field coarser than the one being fixed is kept from
the date; the field itself becomes the requested value; every field finer than it - given or not - is reset
to its period's base, day and month to 1, everything else to 0. If that candidate is not strictly on the
correct side of the date (later, for a forward search or a set that would otherwise sit in the past; earlier,
for a backward search), it steps out by one unit of the next coarser period - a month for a day, a year for a
month - and tries again there. A request that already holds returns the date untouched, with no truncation
at all; that is how `-dateBySettingUnit:value:ofDate:options:` answers a weekday that already matches, and
how a `date`/`hour` search whose fields already equal the date's own answers too.

Two measured exceptions, both narrow enough to state exactly:

- A day search stepping backward, whose day already ties the date's own, always steps out to the previous
  month regardless of what a finer given field says - checked against the host on New York, Berlin, Tokyo,
  Kolkata and Sydney, forward and backward, tied and untied, alone and paired with an hour or a minute: this
  is the one combination where the finer field's own sign does not decide it.
- A day that does not exist in the month it would land in - the 31st rolled back into a thirty-day month, the
  30th forward into February - does not carry the overflow arithmetically the way `-dateByAddingComponents:`
  would. It lands exactly on the first of the following month, with every finer given field dropped, no
  matter how far past the month's end the requested day sits. Checked on the host across Gregorian and
  Buddhist calendars in six zones: the 29th, 30th and 31st rolled into every month from 28 to 31 days long,
  forward and backward, always land on the 1st that follows, never a carried day count.

One divergence is recorded rather than chased: a backward day search whose day ties the date's own, in a
zone with daylight saving rules (New York, Sydney) and a date before some year the host does not name,
answers with a fixed, unrelated date - 4 April 1975 for every New York query checked from 1970 through 2005,
regardless of the year asked from; from 2010 on the host answers the plain previous month. This is the
host's own `-nextDateAfterDate:` doing it, not the backport's construction of the candidate - probed directly
against the system class, outside the backport entirely, with the same fixed answer for every year up to the
boundary. It reads as an internal cache or lookup table in the host's own Foundation that the backport has no
reason to reproduce; iOS 6.1.3 predates the host that exhibits it. `tests/backports/host/foundation2` holds 17
of 14954 checks against it, all `nextMatch`'s `backwardMatch` field, all in New York or Sydney, all four fixed
dates - 4 April 2001, 3 April 2006, 21 September 1984 and 1995, 3 April 1982 - that land inside the boundary.

## Granularity

`-isDate:equalToDate:toUnitGranularity:` and `-compareDate:toDate:toUnitGranularity:` were measured against
the system for noon and eight in the evening of one day: equal to the day, not equal to the hour, and **not
equal to a mask of both**, which behaves as the finer of the two. A unit that names no field of a date -
`NSCalendarUnitCalendar`, `NSCalendarUnitTimeZone` - answers equal and orders the same, since there is
nothing to tell the two dates apart by. The backport answers each of those as the system does.

## A calendar whose months repeat

`NSCalendarIdentifierChinese`, `Dangi`, `Gujarati`, `Kannada`, `Marathi`, `Telugu`, `Vietnamese` and
`Vikram` number a leap month the same as the month it follows, so two dates can carry the same era, year
and month and still fall in different months - one in the ordinary one, one in its leap repeat. Read from
swift-foundation's own `Calendar.compare(_:to:toGranularity:)`: when the numeric fields it has already
compared are equal and the granularity has reached the month, a date whose month is not the leap one orders
before one whose month is; the Hebrew calendar's own leap month, Adar I, is a month of its own number and
is not in this list, and needs no such tie-break. Checked against the host's own Foundation on Chinese: of
every pair of dates within 900000000 - 600000000 seconds of the reference date that share an era, year and
month and differ only in the leap flag - 9880 comparisons at 13 granularities - the backport orders none of
them differently. The device test holds iOS 6 to one such pair, a date in an ordinary seventh month and one
29 days later in that month's leap repeat, at seven granularities from the quarter to the week of the
month: the ordinary one compares before the leap one, and the two are not equal.

## Weekends

`-nextWeekendStartDate:interval:options:afterDate:` follows the locale, not the calendar: from that Sunday
an `en_US_POSIX` calendar answers the following Saturday at 00:00 with an interval of 48 hours, and a
`he_IL` one answers the Friday before it, also 48 hours. The weekend of a locale comes from ICU, which the
release carries as `libicucore`; where that library does not answer, `-isDateInWeekend:` says no and the
library says so once in the log.

## Whether components name a date

`-isValidDateInCalendar:` asks the calendar to make a date of the components and to give back the same components;
it answers yes only when everything the components hold comes back unchanged. `-isValidDate` is the same with the
components' own calendar, and answers no when there is none, even for components the calendar would accept.
Measured on the host and held by `calendar.edges.validity`, over fourteen cases and the Gregorian calendar:

- 29 February 2024 and 31 December 2026 are valid; 29 February 2023, 31 February and 31 April 2026, month 13, month 0,
  month -1 and day 0 are not;
- components that leave things out are valid as far as they go: a year alone, a year and a month, and components
  with nothing set are valid, while a day and a month with no year that cannot exist in any year (30 February) are not;
- an hour of 25, a minute of 61 and a week of the year, 53, in 2026, which has 52, are not valid;
- a time zone on the components and an era of 0 leave a valid date valid; components read in another calendar are read
  by that calendar, and 30 February 2026 is no date in the Japanese calendar either;
- 10 October 1582 is not valid on the host, whose Gregorian calendar skips 5 to 14 October 1582, and is valid on iOS 6.0
  and 6.1.3, whose Gregorian calendar has no gap: the date makes the same components back. That is the one
  record of the fourteen where the release differs, and it is the release's calendar rather than the backport's.

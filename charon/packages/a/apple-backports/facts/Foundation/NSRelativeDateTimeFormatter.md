# NSRelativeDateTimeFormatter, iOS 13

Introduced in iOS 13: a formatter that writes the distance between two dates as a phrase - "in 2 hours", "3 days ago",
"yesterday", "next week" - in two styles (numeric, named) and four unit styles (full, spelled out, short, abbreviated).

Source: the host's own Foundation, asked for every answer and held against the port by two runs. The
`relativedatetimeformatter` group of `tests/backports/host/uikit2/run.sh` puts the port beside the system's class and
compares 56000 random answers, none differing. `tests/backports/host/relativedatetime` records the system's answers for
1600 fixed cases into `device/relativedatetime-expectations.h`, and `device/relativedatetime.m` compares the port to them
on the device, where the calendar is iOS 6's own. The shared caches of iOS 6.0 and 7.0 have no such class.

## What the port does as the system does

The distance between the two dates is cut into years, months, weeks of the month, days, hours, minutes and seconds by the
formatter's calendar, and the first of them that is not zero is the phrase; the sub-second part of the distance is dropped
toward zero. A distance of nothing reads "in 0 seconds", and named "now". A past distance is written "N units ago", a future
one "in N units"; the number goes through the number formatter of the formatter's locale, spelled out for the spelled-out
style and grouped otherwise.

The named style writes "tomorrow" and "yesterday" for one day, "next"/"last" and the unit for one week, month or year, and
the zero of a unit as "today", "this week", "this month", "this year", "this hour", "this minute" and "now"; everything else
is numeric. The short style abbreviates the units ("2 hr. ago", "in 3 wk.") and the abbreviated style writes them without a
space ("2h ago", "in 3mo"); the named phrases use the short unit for weeks, months and years, and the full "hour" and
"minute" for the two zeros. The formatting context of the beginning of a sentence puts the first letter in capitals.

`localizedStringFromDateComponents:` takes the first of the components that is defined and not zero, in the order above,
and when all defined ones are zero, the smallest of them, so a components object with only a day of zero reads "in 0 days"
and named "today"; components with nothing defined answer `nil`. The week of the year, the week and every unit above a year
are ignored, as they are by the system. `localizedStringFromTimeInterval:` reads the interval from now and
`stringForObjectValue:` answers only for a date, relative to now. The calendar starts as the current one, the locale as the
current one, a copy keeps every setting, and the class writes nothing into an archive, as the system's does not.

## What it cannot do

The words are English. The system has its own phrases for every language it ships; the port carries none, so a device in
another language reads the English phrases with that language's digits and spelled-out numbers. `getObjectValue:forString:`
is not answered, as the system's is not: it raises the same exception the abstract class does.

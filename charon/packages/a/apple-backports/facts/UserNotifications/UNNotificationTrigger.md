# UNNotificationTrigger, UNTimeIntervalNotificationTrigger, UNCalendarNotificationTrigger

Introduced in iOS 10.0. When a notification fires.

Source: UserNotifications of the armv7s cache of iOS 10.3.4 for the checks and
their texts, and the host's own UserNotifications for every date, asked through
the triggers' own `-nextTriggerDateAfterDate:withRequestedDate:`, which 10.3.4
has too and which the port carries under the same name.

## Checks

A time interval trigger checks, in this order, with `NSAssert` - so
`NSInternalInconsistencyException`:

- repeating and under 60 seconds: `time interval must be at least 60 if repeating`;
- not greater than 0, which NaN is not either: `time interval must be greater than 0`.

`-nextTriggerDateAfterDate:withRequestedDate:` asserts `date must not be nil` of
a time interval trigger and `afterDate must not be nil` of a calendar one, and
`requestedDate must not be nil` of both.

## Time interval

The trigger fires at the requested date plus the interval. Asked after a date
before that, it answers that; after it, a trigger that does not repeat answers
nil and one that repeats answers the next multiple of the interval from the
requested date, strictly after the date asked about. `-nextTriggerDate` asks
with now for both, so it answers now plus the interval, afresh every time.

## Calendar

The dates are found as `NSCalendarMatchNextTimePreservingSmallerUnits` finds
them, in the components' own calendar and zone, or the current calendar:

- only the units above the highest one given are free; every unit below it that
  is not given takes its least value, even one standing between two that are
  given - `day 30, minute 10` fires at 00:10 of the 30th, not at every hour's
  tenth minute;
- a day the month lacks is not skipped: the 31st of a month of 30 days, or the
  29th of February in a common year, fires on the day after, at the time of day
  of the date it was asked after;
- a year that has passed answers nil at once.

A trigger that repeats answers the next such date after the date asked about.
One that does not fires once, at the first such date after the requested date:
asked after that, it answers nil.

iOS 6 has no `-nextDateAfterDate:matchingComponents:options:` (it arrived in
iOS 8), so the search is carried: day by day from the start, the time of day
tried within each matching day, each candidate read back to throw out a wall
time a change of clocks leaves out. Held to the host on 5760 dates - 24
component sets in GMT, Tokyo, New York, Berlin and Lord Howe, which moves its
clocks by half an hour, both repeating and not, around two changes of clocks -
and then on iOS 6.1.3 itself with the same 5760.

## Where the dates differ

- **A week of the month.** Asked for the second Tuesday after the 9th of
  February 2022, the newest release answers the 1st of March, a Tuesday of the
  first week, where the second Tuesday of March is the 8th. The port answers
  the 8th, the date the components describe; `weekOfMonth` is left out of the
  held set for this reason.
- **The clocks of the release.** iOS 6.1.3's zone rules are those of 2013: to
  them Moscow is four hours ahead of Greenwich, as it was from 2011 to 2014, so
  a notification there fires at the wall time the device's own clock shows.
  That is the release, not the port, and a zone whose rules have not changed
  since - Tokyo - is held instead.

## Archiving

| key | class | coded as |
|---|---|---|
| `repeats` | all | `-encodeBool:forKey:` |
| `timeInterval` | time interval | `-encodeDouble:forKey:` |
| `matchingDateComponents` | calendar | `-encodeObject:forKey:` |

The system's archives read back into the port's triggers and the other way.

## Describing

`<%@: %p; repeats: %@, timeInterval: %lf>` and
`<%@: %p; dateComponents: %@, repeats: %@>`, the texts of 10.3.4, which the
newest release still writes.

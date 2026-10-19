# NSDateInterval

Introduced in iOS 10.0. A closed interval `[startDate, endDate]`.

Source: the host's Foundation, the armv7s shared cache of iOS 10.0.1 and 10.3.4,
and the arm64 ones of 11.0 and 18.0 where the releases differ.

## Behaviour

| member | behaviour |
|---|---|
| `-init` | the current date, duration 0. |
| `-initWithStartDate:duration:` | designated; the start date is copied. A nil start raises `NSInvalidArgumentException` `Start date is nil!`, a duration below 0 raises it with `Duration is less than 0!`. The test is `< 0`, so NaN passes, in 10.3.4 (`0x1b861bb4`), 11.0 and 18.0 alike. |
| `-initWithStartDate:endDate:` | a nil start or end raises `NSInvalidArgumentException` with `Start date is nil!` or `End date is nil!`; a start later than the end, by `-compare:`, raises `NSGenericException` with `Start date cannot be later in time than end date!`. Otherwise the duration is `[endDate timeIntervalSinceDate:startDate]`. The reasons are the bare texts. |
| `-endDate` | derived, never stored: the start date plus the duration. |
| `-copyWithZone:` | returns the receiver. |
| `-compare:` | the start dates first; equal start dates are ordered by duration. |
| `-isEqualToDateInterval:` | the start dates with `-isEqualToDate:` and the durations with `==`. |
| `-containsDate:` | nil answers NO. Closed on both ends: a date equal to the start or the end is contained. An interval of duration 0 contains its own instant. |
| `-intersectsDateInterval:` | nil answers NO; otherwise either interval contains an end of the other. |
| `-intersectionWithDateInterval:` | `nil` for nil and when they do not intersect; otherwise the later start to the earlier end. Intervals that only touch at an instant intersect in an interval of duration 0, not in `nil`. |
| `-hash` | the start and end dates. |
| `-description` | `%@ (Start Date) %@ + (Duration) %f seconds = (End Date) %@`, opened by `[super description]`. |
| `+supportsSecureCoding` | `YES`. |

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.startDate` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSDate class] forKey:` |
| `NS.endDate` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSDate class] forKey:` |
| `NS.duration` | `-encodeDouble:forKey:` | `-decodeDoubleForKey:` |

10.3.4 writes the two dates only; 11.0 and 18.0 write the duration beside them,
and that is carried, so an archive made here reads the same on every release.

Decoding, as 11.0 does it (`0x1816cc9f0`): a missing start fails the coder with
`NSCocoaErrorDomain` 4865, `NSCoderValueNotFoundError`, no user info, and the
answer is nil. If the archive has a duration, the interval is built from the
start and the duration. Otherwise the end date is read; if the coder has an
error by then it fails the same way, if there is no end date the duration is 0,
and if there is one the interval goes through `-initWithStartDate:endDate:`.
10.3.4 knew no duration and failed on a missing end as on a missing start.

Non-keyed coders raise `NSInvalidArgumentException`. The encoding text is
Apple's own, and it says the opposite of what it means; it is reproduced as it
is because the text is observable:

- encoding: `Encoder does not allow keyed coding!`
- decoding: `NSDateInterval cannot be decoded by non-keyed archivers`

## What Charon does not carry

Foundation makes `NSDateInterval` a class cluster: `+allocWithZone:` hands back
a private `_NSConcreteDateInterval` when the class asked is exactly
`NSDateInterval`. Charon implements the class directly, so `-class` answers
`NSDateInterval` where Foundation answers `_NSConcreteDateInterval`. Everything
reachable through the declared API is the same; only the private class name a
program has no business reading differs.

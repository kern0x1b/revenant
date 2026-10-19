# NSISO8601DateFormatter

Introduced in iOS 10.0. Writes and reads the shapes of ISO 8601.

Source: `CFDateFormatterCreateISO8601Formatter` and the class itself, in the
armv7s cache of iOS 10.3.4, and the host's Foundation for the option iOS 11 added;
the pattern for every one of the 2048 combinations of the options is checked
against the answers the real function gives.

## Why it is assembled rather than asked for

`CFDateFormatterCreateISO8601Formatter` arrived after iOS 6, but everything it is
built out of was there already - `CFDateFormatterCreate`, `CFDateFormatterSetFormat`,
`CFDateFormatterCreateStringWithDate`, `CFDateFormatterGetAbsoluteTimeFromString`
and `kCFDateFormatterTimeZone`. So the formatter is put together here out of the
same parts, from the same fragments Apple's function uses.

## The pattern

| field | fragment |
|---|---|
| year | `yyyy`, or `YYYY` where a week is asked for beside it |
| month | `MM` |
| week of year | `'W'ww` |
| day | `dd` with a month, `DDD` without one, `ee` with a week |
| time | `HHmmss`, or `HH:mm:ss` with the colon |
| fractional seconds (iOS 11) | `.SSS` after the seconds, and only where the time is asked for |
| zone | `XXXX`, or `XXXXX` with the colon |

The fields are joined by `-` where dashes were asked for and by nothing where they
were not. A date and a time are parted by `'T'`, or by a space where that was
asked for.

Three rules are not obvious and each of them came out of the table of answers:

- **One option alone writes nothing.** Not even the field it names: asked for the
  year and nothing else, the real formatter answers an empty pattern. Two options
  are enough - the year with a dash writes `yyyy`.
- **The parting letter belongs to the time, not to the zone.** A date followed by
  an offset alone runs straight on: `yyyyMMXXXX`, with no `T`.
- **The whole internet date and time drops a week asked for beside it.** Of all
  1024 combinations exactly two do this, and both are supersets of
  `NSISO8601DateFormatWithInternetDateTime`; they answer `yyyy-MM-dd…` and leave
  the week out.

## The week rule, and where it has to come from

Apple's formatter runs on `en_US_POSIX` over a gregorian calendar whose week
starts on Monday and whose first week is the one with four days in it - the ISO
rule. That calendar cannot be handed to a formatter here:
`CFDateFormatterSetProperty` with `kCFDateFormatterCalendar` does not take, and
the calendar reads straight back as starting on Sunday with one day in the first
week, whatever order it is set in.

So the rule is asked for in the locale instead. Asking for the ISO calendar by
name (`@calendar=iso8601`) brings the rule but changes what a pattern without a
date reads back as - the year comes out as 12000 - and asking only for the first
weekday (`@fw=mon`) leaves the first week at one day, so the last Sunday of a year
lands in a week of its own. What is used is `en_GB_POSIX`, the POSIX-invariant
locale whose own week rule is already the ISO one. Every pattern here is numeric,
so nothing else of a locale shows through.

## The zone, on an older ICU

The letter `X` is younger than iOS 6. An ICU that does not know it writes **nothing
at all** where the zone should be - no error, just an empty place - so a date
formatted there would silently lose its offset.

Measured on iOS 6.0: `XXXX` and `XXXXX` write nothing; `ZZZZZ` writes `Z` at
Greenwich and `+09:00` elsewhere, which is what `XXXXX` means; `Z` and `ZZ` write
`+0000` and `+0900`, which is the basic shape but says `+0000` where ISO 8601
wants `Z`.

So the formatter asks once whether this ICU writes `X` at all, and where it does
not it uses `ZZZZZ` and takes the colon out again for the basic shape, putting it
back before a string is read. The offset is the last thing in any of these
patterns, so there is nothing else it could be mistaken for.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.formatOptions` | `-encodeInteger:forKey:` | `-decodeIntegerForKey:` |
| `NS.timeZone` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSTimeZone class] forKey:` |

A missing zone fails the decode with `Timezone has been corrupted!`. A coder that
does not allow keyed coding raises `NSInvalidArgumentException`:
`Encoder does not allow key encoding`. `-setFormatOptions:` asserts that no bit
outside the known ones is set, and the assertion is Apple's own, silent in a
release.

A fresh formatter is in GMT and writes the internet date and time.

## Fractional seconds

`NSISO8601DateFormatWithFractionalSeconds` arrived in iOS 11; the pattern gains
`.SSS`, so a date is written to the nearest millisecond - 1.0005 seconds as
`.001`, 1.9999 as `02.000`, a quarter of a second before the epoch as
`23:59:59.750`. It is strict both ways: asked for, a time without a fraction is
not read; not asked for, a time with one is not read either. One, two or six
digits are read, to the millisecond. The ICU of iOS 6.1.3 rounds and reads the
same, which the device check holds on an iPhone4,1.

The assertion of `-setFormatOptions:` names the bits it allows, this one among
them, and its reason is the expression itself:
`Invalid parameter not satisfying: formatOptions == 0 || !(formatOptions &
~(NSISO8601DateFormatWithYear | … | NSISO8601DateFormatWithInternetDateTime))`,
written out in full as Foundation writes it.

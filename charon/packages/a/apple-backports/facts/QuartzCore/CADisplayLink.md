# CADisplayLink.targetTimestamp and .preferredFramesPerSecond, iOS 10

iOS 10 added two members to a class iOS 3.1 already had: the timestamp a frame should be drawn for, and the frame rate
an application asks for in place of the frame interval it asked for before. The armv7 caches of iOS 6.0 through 9.0
have neither; the armv7s cache of iOS 10.3.4 has both. Everything below the class already has - `timestamp`, `duration`,
`frameInterval` and `setFrameInterval:` - is the release's own, so the port adds three methods and stores one number.

Read from: the armv7 shared caches of iOS 6.0, 6.1.3, 7.0.1, 8.0 and 9.0 and the armv7s cache of iOS 10.3.4, for which
release has which method, and the method type encodings on 6.1.3, where `frameInterval` is `i` and `timestamp` and
`duration` are `d`; the arm64 shared cache of iOS 12.0, disassembled, for what the new members do and for the constants
they use; the header of iOS 16.4 for the documented default.

## targetTimestamp

`-[CADisplayLink targetTimestamp]` on iOS 12 reads the link's timestamp, its frame interval and its duration and ends in
one `fmadd`: `timestamp + duration * frameInterval`. `duration` is the duration of one display frame, not of one
callback, on iOS 6 as on iOS 10, so the port computes the same expression from the release's own three values. Before
the link has fired, the release answers zero for the timestamp and the duration, and the target timestamp is zero too,
which is what the newer release does with the same zeroes.

## preferredFramesPerSecond

On iOS 10 the rate is a number of its own beside the frame interval, not a reading of it. Both setters end in one
helper, which stores the rate it was given and works the frame interval out from it:

- `setPreferredFramesPerSecond:` hands the rate straight to the helper.
- `setFrameInterval:n` turns the interval into a rate first - `(NSInteger)(60.0 / max(n, 1))`, truncated, with 60.0 a
  literal in QuartzCore and not a reading of the display - and hands that to the helper, which then works the interval
  out again from the rate. That is why `setFrameInterval:7` leaves an interval of 8 on iOS 10.
- The helper, for a rate that is not zero, takes the display's nominal frame duration, falls back to 1/60 second where
  the display does not say, and stores `max(1, round(1 / (duration * rate)))`, rounded half away from zero in single
  precision. For a rate of zero it stores an interval of 1.
- Nothing sets the rate when a link is made, so it starts at zero, which is what the header says: zero is the default
  and means the native cadence of the display.

The port keeps the rate beside the link as an associated object, together with the frame interval it set for it, and
sets the release's own `frameInterval` from it by the same arithmetic. The display of an iPhone 4S and of an iPad 2 runs
at 60 Hz, and the port reads the release's `duration` where it has one and falls back to 1/60 second before the link has
fired, as the newer release falls back.

Asked for the rate, the port answers the rate it was given while the frame interval is still the one it set; where the
application has moved the frame interval since, it answers `(NSInteger)(60.0 / max(frameInterval, 1))`, the same
conversion iOS 10 makes inside `setFrameInterval:`.

## What differs, and why

- The port does not touch `setFrameInterval:`. On iOS 10 setting the interval to a number that is not a divisor of 60
  moves the interval, because the rate is worked out and the interval worked back; here the release's own interval is
  left exactly as the application set it, and only the rate that is read back is the one iOS 10 would report. Changing
  what the release's own method of iOS 3.1 does to the frames it draws is a worse answer than reporting the rate the
  newer release would report.
- A link whose frame interval was set to 1 and whose rate was never set answers 0, the documented default, where iOS 10
  would answer 60 after an explicit `setFrameInterval:1`. The port cannot tell an untouched link from one set to the
  interval it already had without taking over the release's setter, and the default is the answer that matters: an
  application asks a fresh link what it prefers, and the honest answer is that it prefers nothing in particular.
- The `60.0` of the conversion is a literal in QuartzCore on iOS 10 as well, so a display of another rate would read
  back the same way there.

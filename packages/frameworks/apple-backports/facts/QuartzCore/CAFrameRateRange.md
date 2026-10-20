# CAFrameRateRange, iOS 15

Rank 121 of `coordination/corpus/crash-demand-top.tsv` is a `LOAD-FAIL` on `_CAFrameRateRangeMake`
for `provenance`: a hard, non-weak import, so the application fails to launch at all without the
symbol, not merely crash on first use. Rank 123, `CAAnimation.preferredFrameRateRange`, is the same
application's `CRASH-ON-USE` beside it. Both are class-confirmed at 3 (1 crash, 2 soft), the highest
confirmed exposure in this pass's domain filter of `coordination/corpus/crash-demand-top.tsv`.

## What this is

`CAFrameRateRange` is a plain three-float struct (`minimum`, `maximum`, `preferred`) with no OS
dependency whatsoever: the two C functions that operate on it (`CAFrameRateRangeMake`,
`CAFrameRateRangeIsEqualToRange`) only construct and compare the value, and `CAFrameRateRangeDefault`
is a constant of it. "It arrived in iOS 15" names when Apple added the type, not a wall any of the
three functions/constant needs iOS 15 itself to cross.

## What the port does

`CAFrameRateRangeMake()` and `CAFrameRateRangeIsEqualToRange()` are the header's own definitions,
carried verbatim. `CAFrameRateRangeDefault` is `{-1, -1, -1}`, the value Apple's own documentation
gives for `CAFrameRateRange.default` - the sentinel meaning "no preference," not a value this port
invented.

`CAAnimation.preferredFrameRateRange` is kept and returned faithfully (starting at
`CAFrameRateRangeDefault`) but never messaged further: CoreAnimation on this release commits at the
one rhythm the render server drives, and a real device with no ProMotion display answers this
property the same way - there is nothing here for a per-animation range to throttle, on this release
or on a real, current, non-ProMotion iPhone.

`CADisplayLink.preferredFrameRateRange` is not a second, disconnected store beside the
`preferredFramesPerSecond` this port already carries (`ios10framerate.json`,
`facts/QuartzCore/CADisplayLink.md`) - the real header deprecates `preferredFramesPerSecond` in favor
of this property, so setting a range drives the same `frameInterval` mechanism: the target rate is
`preferred` (or `maximum`, if `preferred` is unset), clamped to `[minimum, maximum]` when both are
given, and `0`/unset answers the same as `preferredFramesPerSecond = 0` (the release's own default
interval). The getter reads back the exact range last set, not a value recomputed from the interval,
since a caller that sets a range with `preferred == 0` and only `minimum`/`maximum` given is entitled
to read those back exactly - the same contract `preferredFramesPerSecond` already keeps for the
values it can represent exactly.

## What is not proven

Real ProMotion behavior - genuinely picking a rate within a range moment to moment based on content -
does not exist on this release's hardware or on the 4S/iPad 2 this port targets; nothing exists on
this device for that behavior to differ from Apple's own, since Apple's own current, non-ProMotion
devices answer this property identically: stored, returned, and inert beyond driving the one fixed
rate this hardware has. Not measured on device this pass - the fix is a value type and two property
accessors with no private surface, host-syntax-checked and gate-verified only.

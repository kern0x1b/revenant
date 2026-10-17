# `-[AVPlayer sourceClock]` is `masterClock` under a new name

`packages/a/apple-backports/AVFoundation/AVPlayerSourceClock15.m`, two accessors on `AVPlayer`:
`-sourceClock` and `-setSourceClock:`.

## The SDK header answers the question the cache cannot

The row arrived as `introduced 15.0`, which reads as "the capability came in 15.0". The header says
otherwise, and says it about the property rather than about a name:

```objc
/// Use sourceClock instead.
@property (nonatomic, retain, nullable) __attribute__((NSObject)) CMClockRef masterClock
    API_DEPRECATED_WITH_REPLACEMENT("sourceClock", macos(10.8, 15.0), ios(6.0, 18.0), ...)
```

`API_DEPRECATED_WITH_REPLACEMENT` names two releases: the one the old spelling **arrived**, and the one
it was **replaced**. For `masterClock` those are `ios(6.0, 18.0)` — available from iOS 6.0, replaced in
18.0. So this release has the property, `15.0` is the introduction of the new spelling in the SDK
surface, and the port's job is to answer the new name from the old one.

This is the shape the rulebook calls out: *a selector's rung says nothing about its own owner*, and the
mirror of it — a row's `introduced` says nothing about whether the release has the capability. Both were
checked here and neither is the answer.

## Measured on the band ends, class-scoped

`xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`, then the
selector looked up on `AVPlayer` itself (140 instance selectors declared there):

| accessor | 6.1.3 | 4.3 |
| --- | --- | --- |
| `-[AVPlayer masterClock]` | **yes** | no |
| `-[AVPlayer setMasterClock:]` | **yes** | no |
| `-[AVPlayer sourceClock]` | no | no |
| `-[AVPlayer setSourceClock:]` | no | no |

The 4.3 `no` in the first two rows is why the registry row keeps `minimum` `6.0` and not `4.0`.
`minimums()` (`modules/apple/backports.lua:2024`) reads `entry.minimum` and never `entry.status`, so that
field is the placement record for every band whether or not the status claims a capability.

`xmake l tools/cache-index/first-rung.lua masterClock sourceClock` agrees on the shape and is worth
reading for the hole it exposes: `masterClock` answers **6.0** and `sourceClock` answers **8.0** — but
nothing is held between 12.0 and 16.0, so a 16.0 answer bounds an arrival between 13.0 and 16.0 rather
than dating it. The `8.0` here is the same ladder artefact seen from the other end: the name exists at
8.0 as **some other class's** selector, which is why the row is settled from the cache and the header
and not from first-rung alone.

### The control

`xmake l tools/corpus/cache-census.lua AV 6.1.3 4.3`, one run: `images 524, of which naming AV 16 /
classes 11378, of which AV* 301` at 6.1.3, `images 354, of which naming AV 15 / classes 7187, of which
AV* 231` at 4.3, closing with
`control: 558 name(s) beginning AV found in this run, so a zero on another rung is the release's and not
the reader's`.

## The forward goes through `objc_msgSend`

Both accessors send the release's own selector through `objc_msgSend` rather than writing
`return [self masterClock];`. The reason is that this package compiles against an SDK that declares
`masterClock` `API_DEPRECATED_WITH_REPLACEMENT`, and a direct call imports that deprecation into the
port's own object — a deprecation warning in a backport whose whole point is to call the release's own
method — for a call that is identical. Sending the selector by name asks the release what it answers
and does not ask the header to agree.

## What a caller gets

The `CMClockRef` the release's own `-masterClock` returns, held the way the header declares it
(`retain, nullable`, an object under ARC), or nil when the release answers nil — which a player with no
playback clock set gives, and which is why the property is nullable in Apple's own header rather than
being a promise. The setter stores through `-setMasterClock:`, so a program that mixes the two
spellings across releases sees one clock, not two.

Measured on the host (`AVFoundation` of macOS 26, `tests`-style differential by hand): `AVPlayer`
answers **both** selectors, and on a player with an item and a running play both answer **nil** on this
host — `CMClock` is not present in the host's `CoreMedia`, so there is no clock object for either name
to return. That is the nullable case, not a stub: the getter forwards to the release's own accessor
and returns whatever that returns, on any release.

## Not carried

`-cancelLoading`-style teardown is not involved here, but the *other* clock property in this slice is a
different thing and is not in this file: `AVCaptureSession.synchronizationClock` is the rename of
`AVCaptureSession.masterClock` in the same way (the SDK surface has `AVCaptureSession.masterClock`
introduced 7.0 and deprecated 15.4, against `synchronizationClock` introduced 15.4), and **neither
accessor is on `AVCaptureSession` at 6.1.3** — measured, both `no`. That row is absent because the
release has no clock property there to forward to, not because the rename pattern did not apply.
`registry/AVFoundation/absent_AVFoundation.json` says so.
# The metric event surface: 132 rows, 19 classes, one protocol

`AVFoundation/AVFoundationMetrics18.m` (the 18.0 band, 121 rows) and
`AVFoundation/AVFoundationMetrics26.m` (the 26.0 band, 11 rows). Registry:
`registry/AVFoundation/metrics180.json` and `metrics260.json`.

The whole surface is one header. SDK 16.4 ships **no `AVMetrics.h` at all**, so
`CharonAVMetrics18.h` transcribes 26.2's own file - 498 lines, nineteen classes, two protocols - with one
stated change: all 26 `, visionos(<version>)` are dropped, because SDK 16.4's `availability.h` does not know
the word and expanding it there is `error: expected ','`.

## What is actually implemented, and what is honestly not

**`AVMetricEventStream` is real.** It keeps the publishers it was given, the subscriber and its queue, and
the set of event classes the caller subscribed to. Its two `BOOL` returns are answered by the header's own
rules, not always `YES`:

- `-addPublisher:` answers **NO** when the argument does not conform to `AVMetricEventStreamPublisher`, and
  **NO** when the same publisher is already in the set - there is no way to remove one, so adding it twice
  would leave a set the caller cannot shrink.
- `-setSubscriber:queue:` answers **NO** when the argument does not conform, and **NO** when a *different*
  subscriber is already set - one subscriber at a time, because there is no way to remove one either.
- `-subscribeToMetricEvent:` stores the class only if it is an `AVMetricEvent` subclass, read with
  `isSubclassOfClass:` rather than from a list of sixteen names, so a class added to the file is subscribed
  by `-subscribeToAllMetricEvents` with no second edit and a class the port does not carry cannot be
  subscribed by accident. That method walks `objc_copyClassList()` and takes every `AVMetric*` class that
  is an `AVMetricEvent`.
- `+eventStream` answers a working stream: no publisher, no subscriber, an empty subscription set.

**The stream delivers nothing, and that is a real limit of the release, not a missing piece.** The publisher
protocol has no method at all in 26.2, so there is no call to hand an event in, and no `AVPlayerItem` on
iOS 6.1.3 raises any of the notifications these events are built from (`AVPlayerItemPlaybackStalled` is iOS
10). So the subscriber's `-publisher:didReceiveEvent:` is never called by this port. Every event class
exists with the members the header declares, and nothing here constructs one.

**The event classes are containers, and their empty answers are real answers.** The header's properties are
`@property (readonly)`, so each is a getter over an ivar. An event this port has not filled reads:

| member | answer | why that is the honest value |
| --- | --- | --- |
| `date` | the moment the instance was created | a real measurement, taken where the object exists |
| `mediaTime` | `CMTimeMake(0, 1)` | the zero of the timeline: this port observes no media time |
| `sessionID` | `nil` | what the header documents for "If not available, value is nil" |
| every object-typed member | `nil` | the same |
| every count, flag and duration | the zero of its type | what a container nobody has filled holds |

`+new` and `-init` answer through `NSObject`, which the release has; the header marks them
`AV_INIT_UNAVAILABLE`, so an application written against a newer SDK cannot reach them either.

**`NSSecureCoding` is implemented on both roots.** `+supportsSecureCoding`, `-encodeWithCoder:` and
`-initWithCoder:` are on `AVMetricEvent` and on `AVMetricMediaRendition` - the roots of the two hierarchies,
not seventeen copies - and every subclass inherits all three, because none of them declares the conformance
itself. Encoding goes through `packages/c/charon-coding/files/CharonCoding.h`, whose walker reads each
class's own ivar list from the object's class up to `NSObject`, so a subclass carries its parent's state
without either naming it and a property added later is carried by the same code rather than by an edit to an
archive method. All three objects build with **0 errors and 0 warnings**.

## Why the 26.0 part is a category, and why its storage is an association

The three rendition properties each variant-switch class gained - `videoRendition`, `audioRendition`,
`subtitleRendition` - are 26.0, so they are not in the 18.0 object, which would put 26.0 API in an 18.0 band.
They are two categories in `AVFoundationMetrics26.m`. The 18.0 implementations mark them `@dynamic`,
without which clang synthesizes getters there and the 26.0 category has nothing to add.

A category may not declare instance variables - `instance variables may not be placed in categories`, six
errors - so each getter reads an object association keyed by `ClassName.propertyName`, which is what the
tree already does wherever a category must carry state. The alternatives were an ivar block in the 18.0
object (the thing the one-release rule exists to prevent) or a non-fragile-ABI class extension the 16.4
SDK's runtime cannot rely on.

## The bands, measured

| object | rows | how the band was decided |
| --- | --- | --- |
| `AVFoundationMetrics18.m` | 112 | the `_OBJC_CLASS_$_` symbol of each of its sixteen classes is at 18.0 (`tools/symbol-first-release.lua`) |
| `AVFoundationMetrics18b.m` | 9 | **not chosen - measured.** `AVMetricDownloadSummaryEvent` is the one class of this surface the 18.0 cache does not export, so nothing places it at 18.0 and it falls back to 26.2's own annotation, which is `ios(18)` without the minor. Beside the others' measured 18.0 that is two releases in one object, and the gate says so by name: `AVFoundationMetrics18.m defines AVMetricDownloadSummaryEvent from iOS 18 and AVMetricContentKeyRequestEvent ... from iOS 18.0; an object carries API that arrived in one release, so split it` |
| `AVFoundationMetrics26.m` | 11 | no held cache places any of it - the ladder ends at 18.0 - so the registry row's own `introduced` places it, which is the tree's rule for a name no held release exports |

The registry writes `18` for that one class's rows and `18.0` for the rest. That is not a slip: `18` is the
band the gate measures for it and `18.0` is the band it measures for the others, and writing one form for
both is what produced the refusal above.

Every **method** and **property** row answers `none` over the ladder, and that is expected rather than a
gap: a dyld shared cache exports class symbols, not the selectors inside them. So those rows are placed by
their own `introduced`, and the class symbols are what put the objects in a band at all.

## The host differential

`tests/backports/host/avf-globals/metrics.m`. The host **has** this surface - iOS 18 added it, this macOS is
27 - so this is a real structural differential: every class, its superclass, and one member per property
row, 89 names in all, listed **from the two registry files** so the probe cannot ask about something the
registry does not carry.

```
$ sh tests/backports/host/avf-globals/run.sh
the metric probe is asked about 89 classes, protocols and members
the host build's prologue declares 18 renamed classes
ok  control AVMetricNoSuchClass = ABSENT
ok  control AVMetricEvent = HAS
ok  control AVMetricEventStreamSubscriber = HAS
ok  control -[AVMetricEvent date] = yes
ok  18 classes resolve on both sides with the same superclass, and 71 members were asked of the host
note: 1 of those members the host's own class does not answer
```

and the plant, which is the part that makes it a check:

```
$ AVFGLOBALSMUTANT=metrics sh tests/backports/host/avf-globals/run.sh
ok  the mutation was noticed: 1 hierarchy row(s) differ
SUPERCLASS	AVMetricPlayerItemStallEvent	host=AVMetricPlayerItemRateChangeEvent	port=AVMetricEvent	DIFFERENT
```

The plant is a wrong transcription of `AVMetrics.h` - one class made to inherit from the wrong parent -
which is exactly the mistake a hand-written header makes and exactly what the `SUPERCLASS` row catches.

### The one member the host's own class does not answer

```
RESPONDS	-[AVMetricMediaResourceRequestEvent readFromCache]	host=no	port=declared
```

The port carries it because 26.2 declares it; the host's class does not answer it. That is the direction
the policy asks for - the port answering MORE than the host - and it is printed by the run rather than
exempted in silence. It is the only such row of the 71.

### What it took to get the host build to compare the port and not itself

The macOS SDK ships `AVMetrics.h` of its own, so `CharonAVMetrics18.h`'s guard excludes every declaration in
the host build and an unrenamed copy would compile the port's `@implementation AVMetricEvent` against
Apple's declarations - **the probe would then compare the host against itself and report every row equal**.
So the classes are renamed to `charon_host_*`, which needs three things, each of which failed first in a
way that read as a pass:

1. **A prologue that copies the header's `@interface` blocks with the name prefixed, bodies included.** An
   empty `@interface charon_host_X : NSObject @end` is not enough: the copy's `@synthesize` lines then have
   no declaration and clang stops with `property implementation must have its declaration in interface`.
2. **The rename must reach `@interface` and `@implementation` and the categories**, not just the
   `@implementation` lines. Renaming only the implementation leaves the class extension with the old name,
   and clang sees a root class: `no known class method for selector 'alloc'`.
3. **`-x objective-c`, because the copy is named `.rn`.** The driver does not recognise that suffix and
   with `-c` it exits 0 having written nothing at all - no error, no log line, no object. The object-exists
   guard in the script turns that into a red instead of a link error about a missing file. This is the
   second time this harness hit that, and the guard is now in both places.
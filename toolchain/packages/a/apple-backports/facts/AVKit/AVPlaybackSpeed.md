# AVPlaybackSpeed and the 16.0 speed control on AVPlayerViewController

Three rows: `AVPlaybackSpeed`, `AVPlayerViewController.speeds`, `AVPlayerViewController.selectedSpeed` and
`-[AVPlayerViewController selectSpeed:]` - four, with the seam the play path calls. Every value below is
either the host's own answer or a measurement of this release; nothing is a number typed from memory.

## What was checked before writing code

The release, in the armv7 shared cache of 6.1.3 (568965 names, `armv7`, read from
`dyld_shared_cache_armv7`, mtime 1362840566, size 244881694):

| name | in 6.1.3 | first held rung |
| --- | --- | --- |
| `rate` | yes | 3.0 |
| `canPlayFastForward`, `canPlaySlowForward` | yes | 5.0 |
| `currentTime`, `duration`, `play`, `pause` | yes | 3.0 / 4.0 |
| `defaultRate` | **no** | 16.0 |
| `automaticallyWaitsToMinimizeStalling`, `maximumForwardPlaybackRate`, `playImmediatelyAtRate` | no | 16.0 |

`rate` is the substrate and the port already stands on it: `AVPlayerViewController.m:685` reads
`self.player.rate != 0` to decide whether to draw play or pause. So a selected speed is a real rate set
on a real `AVPlayer`, not a number the port keeps to itself.

`defaultRate` is the one thing the header names that the release does not have. That is the whole
deviation, and it is stated rather than papered over.

## The values, from the host

`tests/backports/host/avkitspeeds/host.m`, built and run against the host's own AVKit through
`coordination/heavy.sh`, at locale `en_US@rg=plzzzz`:

```
locale: en_US@rg=plzzzz
count: 5
speed: rate=2 name=Double numeric=2x
speed: rate=1.5 name=Faster numeric=1,5x
speed: rate=1.25 name=Fast numeric=1,25x
speed: rate=1 name=Normal numeric=1x
speed: rate=0.5 name=Half numeric=0,5x
made: rate=1.75 name=port probe numeric=1,75x
```

(the `x` above is U+00D7; the source of the probe and of the port are both ASCII and write it as an escape)

Three things in that output are the implementation, and none of them is a guess:

1. **The order.** `+systemDefaultSpeeds` answers fastest first, not ascending and not in the order the
   rates are written in a header. The port's list is in the host's order.
2. **The numeric name is computed, not stored.** The last line builds a speed through the public
   initialiser with the name `"port probe"` and rate `1.75`, and it answers the numeric name `1,75x`.
   Had the host stored a numeric name, that value would have come from somewhere else; it is derived
   from the rate, and the digits come out in the *current locale's* format. So
   `-localizedNumericName` here goes through the release's own `NSNumberFormatter` and appends the
   sign, and the comma in the measurement is the measured locale's separator rather than a constant in
   this file.
3. **The five names are the host's English names.** `Double`, `Faster`, `Fast`, `Normal`, `Half`.

## What is not proven, and is the open end of the class row

`localizedName` is localized by the system, and **only the `en_US` names are measured**. A caller on a
French or Japanese locale gets the English word from this port, where the host would answer otherwise.
Nothing in this tree can measure that: the host answers in the host's locale and the release has no
AVKit at all, so there is no second oracle here. The row of `AVPlaybackSpeed` says so in its `effect`.

The `localizedNumericName`, by contrast, is correct in any locale, because it is computed rather than
carried - which is the one part of the name surface that is not locale-bound.

## The deviation, in the header's own words

`AVPlaybackSpeed.h:51`: the rate "will be set in response to the play button being pressed".
`AVPlayerViewController.h:187`: `selectedSpeed` reflects the associated `AVPlayer`'s `defaultRate` "and
vice versa", and is nil when `defaultRate` matches no speed in the list.

The release has no `defaultRate`, so the port cannot track one. It does the next best thing that the
header's own model describes: the selection is kept, and the rate is set on the player on the play
press, which is the event the first of those two sentences names. `-selectSpeed:` therefore takes
effect at once when the player is already playing and on the next play when it is not, and
`selectedSpeed` answers from the rate the player is really running at - which is also what makes the
header's nil rule work: a rate that matches no speed in the list answers nil.

The consequence worth naming: a rate set on the `AVPlayer` from outside the controller shows up in
`selectedSpeed`, because it is read from the rate. On the system, setting `defaultRate` from outside
would not change which speed the playback UI shows until play. That is a real difference and it is the
price of a release with no `defaultRate`; it is not papered over with a stored copy that would drift
from the player.

## The seam, and why it is its own row

`AVPlayerViewController.m`'s play path ends in `[_player play]`, and the play press is where the rate
belongs. That object is 8.0 API and must not define 16.0 API, so the call goes through
`-[AVPlayerViewController charon_applySelectedSpeed]`, implemented in
`AVPlayerViewControllerSpeeds16.m` (the object that owns the 16.0 API) and declared in
`CharonAVKitSpeeds.h`. The call site asks for it with `respondsToSelector:` first, because the 8.0
object also links in the bands that do not carry the 16.0 object.

A seam the port owns is still API the port exports, so it is registered: the row
`-[AVPlayerViewController charon_applySelectedSpeed]` in `registry/AVKit/ios16speeds.json`, with no SDK
header declaring the name and the `source` saying so.

## Two defects this family caused and then fixed, both measured

Both were found by `otool -ov` of the four objects, not by reading the source, and both are the kind
that compile clean and answer nothing.

1. **`@dynamic` must STAY on the names another object now implements.** The 8.0 and 9.0 objects listed
   `speeds`, `selectedSpeed` and `contentSource` as `@dynamic` because nothing implemented them. Taking
   them off that line is not neutral: with no `@dynamic`, clang **synthesizes** the accessors into the
   8.0/9.0 object, and a class's own synthesized methods beat a category's, so the 16.0 and 15.0
   implementations would never be reached. Measured: with the names removed, `otool -ov` of
   `AVPlayerViewController.o` lists `-speeds` and `-selectedSpeed`, and the 16.0 object's category lists
   neither. With `@dynamic` restored, each name is listed by exactly one object, and it is the right one.
2. **The public getter has to be spelled as the header spells it.** The first version of the 16.0
   category named its getter `charon_speeds` and compiled without a warning. `otool -ov` of that object
   then showed a category holding `setSpeeds:` and **no** `-speeds`: the property would have answered
   nothing at all, and `respondsToSelector:@selector(speeds)` would have said NO while the setter said
   YES. It is `-speeds` now, and the otool output of the 16. object lists `speeds`, `setSpeeds:`,
   `selectedSpeed`, `selectSpeed:` and the seam.

## One object, one release, measured

`release-split` refuses an object whose registry entries name different minimums, so each of these
lives in its own file and no file carries two releases' API:

| object | release | what it defines |
| --- | --- | --- |
| `AVPlayerViewControllerSpeeds16.m` | 16.0 | `AVPlaybackSpeed` and its six methods, and the `AVPlayerViewController(CharonSpeeds16)` category: `speeds`, `setSpeeds:`, `selectedSpeed`, `selectSpeed:`, `charon_applySelectedSpeed` |
| `AVPlayerViewController.m` | 8.0 | its own API; no 16.0 name (checked with `otool -ov`, which lists none of the five) |
| `AVPictureInPictureControllerContentSource15.m` | 15.0 | `AVPictureInPictureControllerContentSource`, `initWithPlayerLayer:`, `playerLayer`, and the `CharonContentSource15` category: `initWithContentSource:`, `contentSource`, `setContentSource:` |
| `AVPictureInPictureController.m` | 9.0 | its own API; no 15.0 name |

## Not measured on device

No iPad 2 or iPhone 4S pass this. The four objects compile against the pinned toolchain
(`armv7-apple-ios6.1.3`, the SDK of iOS 16.4, the gate's own `PROBE_CC`) and the placement above is
read out of the resulting objects. What a device pass would add, and what it would not: that
`player.rate = 1.5` on this release really decodes at 1.5 (the release's own rate control, not this
port's), that a 1.25x item's audio does not fall apart on the 6.1.3 decoder, and that
`AVSampleBufferDisplayLayer`-free presentation keeps A/V in step at 2x. None of those is a claim this
row makes; the row claims the API answers, and it is measured that it does.

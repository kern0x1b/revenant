# AVPictureInPictureControllerContentSource, iOS 15.0

Three rows: the class, `-[AVPictureInPictureController initWithContentSource:]` and
`AVPictureInPictureController.contentSource`. What makes them real is that the player-layer half of a
content source is exactly what this port's picture-in-picture already does.

## What the class is, from the SDK 26.2 header

`AVPictureInPictureController.h:180-205` declares it `ios(15.0)`, `NS_UNAVAILABLE` for `init`/`new`,
with exactly two members: `-initWithPlayerLayer:` and a readonly `playerLayer`. A category in
`AVPictureInPictureController_AVSampleBufferDisplayLayerSupport.h:109-131` adds the other half:
`-initWithSampleBufferDisplayLayer:playbackDelegate:`, `sampleBufferDisplayLayer` and
`sampleBufferPlaybackDelegate`.

So a content source is a box for one of two things, and this port carries one of them.

## The half that is carried, and why it is not a stub

`AVPictureInPictureController.m` floats picture-in-picture by reparenting a real `AVPlayerLayer` - the
caller's own layer, still attached to the caller's `AVPlayer`, still decoding - into a `UIWindow` at
`UIWindowLevelAlert - 1`, and puts it back exactly where it came from on
`-stopPictureInPicture`. That is the whole mechanism, and it is documented with its one honest limit in
`facts/AVKit/AVPictureInPictureController.md`: it does not outlive the application leaving the
foreground, because that would need a SpringBoard-side companion this tree does not build.

A content source holding a player layer is therefore not a new capability. It is the same layer, named
the way the 15.0 API names it:

- `-initWithContentSource:` builds the controller over `contentSource.playerLayer`, so the window floats
  the very layer the caller put in the box.
- `contentSource` reports the source back, and is settable. A source handed in later has its layer
  adopted as the one to float, because changing the layer under a controller that is already floating
  would strand the old layer in the window with nothing pointing at it.
- A source made with no layer is still a source, and the controller built from it reports no content
  source at all - consistently with the class that already answers `-isPictureInPicturePossible` from
  that layer's real `readyForDisplay` and `player`.

The release's substrate, measured in the armv7 shared cache of 6.1.3: `AVPlayerLayer` is present with
its class symbol, and so is `readyForDisplay`. `-initWithPlayerLayer:` is what the port already
implements, and it already answers nil for a nil layer; `-initWithContentSource:` answers nil for a
source with no layer, so the two initialisers agree rather than one of them inventing a controller with
nothing to show.

## The half that is not carried, and which row says so

`AVPictureInPictureSampleBufferPlaybackDelegate` is registered **absent**, and this is the measured
reason rather than a shrug:

| name | in the armv7 cache of 6.1.3 | first held rung |
| --- | --- | --- |
| `AVSampleBufferDisplayLayer` (class **and** metaclass symbol) | **yes** | 6.0 |
| `AVPictureInPictureSampleBufferPlaybackDelegate` | no | 16.0 |
| `AVPictureInPictureController` | no | 9.0 |

The finding that matters is the first row, and it is the opposite of what the header suggests: the
sample-buffer display layer is *not* a 14.0-or-later class, it has been on the release ladder since
6.0. So the absence of the sample-buffer half of picture-in-picture is **not** a missing class - it is
that no release before 15.0 ever asks such a layer to play. Picture-in-picture itself arrives at 9.0,
and the six-method protocol that would drive a sample-buffer layer inside it is 15.0 API that this
release has no concept of.

That is the honest shape of the row, and it is why this file exists: a reader who assumed the
sample-buffer half was blocked by a missing `AVSampleBufferDisplayLayer` would be wrong, and would go
looking for a class to add. The port's floating window drives an `AVPlayerLayer`; making it drive a
sample-buffer display layer instead would be a different mechanism (a decode-to-display loop the port
would own), not a missing symbol.

## One object, one release, measured

`AVPictureInPictureControllerContentSource15.m` is 15.0 API only. It could not have gone into
`AVPictureInPictureController.m`: that object is 9.0 API, and `minimums()` in
`modules/apple/backports.lua` refuses an object whose entries name two releases.

The 15.0 state lives in associated storage rather than in an ivar for the same reason - a category
cannot add an ivar, and putting one in the 9.0 object would make that object define 15.0 API. The
`playerLayer` property is redeclared readwrite in the category, because the SDK header has it readonly
and the 9.0 object's class extension, which is where the setter really is, is not visible from here.

`otool -ov` of the two objects, which is the check that matters for this claim:

```
AVPictureInPictureControllerContentSource15.o
  -[AVPictureInPictureControllerContentSource initWithPlayerLayer:]
  -[AVPictureInPictureControllerContentSource playerLayer]
  -[AVPictureInPictureController(CharonContentSource15) initWithContentSource:]
  -[AVPictureInPictureController(CharonContentSource15) contentSource]
  -[AVPictureInPictureController(CharonContentSource15) setContentSource:]
AVPictureInPictureController.o
  -[AVPictureInPictureController initWithPlayerLayer:]      <- and no 15.0 name
```

`contentSource` stays on the 9.0 object's `@dynamic` line even though it is now implemented: taking it
off lets clang synthesize a `contentSource`/`setContentSource:` pair into the 9.0 object, and a class's
own methods beat a category's. That is measured, not assumed - see
`facts/AVKit/AVPlaybackSpeed.md`, which has the same defect in the same shape and the output that
caught it.

## Not measured on device

The two objects compile against the pinned toolchain (`armv7-apple-ios6.1.3`, the SDK of iOS 16.4) and
the placement above is read out of them. No device pass has floated a video through a content source
yet. What it would add: that a caller building a controller from a content source gets the same
reparenting, restore and delegate callbacks as one built from `-initWithPlayerLayer:`. The mechanism
underneath is the one `facts/AVKit/AVPictureInPictureController.md` already describes as
host-syntax-checked and gate-verified only, so this row does not claim more than that.

# MPVolumeView.volumeWarningSliderImage, the 7.0 property

One row that arrived saying the property "arrived in iOS 7, and nothing in iOS 6 gives MPVolumeView a
property like it". It is carried, and the reason it differs from the two MPVolumeView rows beside it in the
same file is the whole content of this page.

## The read

Class-scoped, `tools/corpus/objc-inventory.lua` over the armv7 cache of 6.1.3 (commands in
`LanguageOptions.md`, controls as that page records). `MPVolumeView` is **PRESENT** with **54 own instance
methods** and **0 own class methods**:

| selector | in the 54 |
| --- | --- |
| `-volumeWarningSliderImage` | **no** |
| `-setVolumeWarningSliderImage:` | **no** |
| `-volumeThumbImageForState:` | yes |
| `-setVolumeThumbImage:forState:` | yes |
| `-minimumVolumeSliderImageForState:` | yes |
| `-setMinimumVolumeSliderImage:forState:` | yes |
| `-showsVolumeSlider` / `-setShowsVolumeSlider:` | yes |
| `-volumeSlider` | yes |

Across all **11378** classes of the whole 6.1.3 cache exactly **zero** declare
`-volumeWarningSliderImage`, so no category in any framework supplies it either.

## Why this one is `implemented` and the two wireless-route rows stay `absent`

`AbsentRows.md` keeps `MPVolumeView.wirelessRoutesAvailable` and `MPVolumeView.wirelessRouteActive` absent,
and a reader will ask what is different here. The difference is **whose answer the property is**.

- Those two need a **state that does not exist on this release**: the route state behind the AirPlay UI is
  `MPAudioDeviceController`'s private tables, and no public API on 6.1.3 reads it. `AVAudioSession` exists
  and reports the *audio* route, and reporting that as "a wireless route is available" would be a different
  API's answer under this property's name.
- This one is `@property (nonatomic, strong, nullable) UIImage *volumeWarningSliderImage MP_API(ios(7.0));`
  — a readwrite image **the caller supplies**. There is nothing to discover. There is something to store, and
  what to store is the caller's own `UIImage`.

That is the whole distinction between a property whose answer the device must know and one whose answer the
caller brings, and it is why the same class yields two absent rows and one implemented row.

## It is not `inert`, and the check is what shows the difference

A stored image nothing drew would be an accessor pair that loads and does nothing — `inert`, or a claim of
more than is true. It is not that. The release's own `-setVolumeThumbImage:forState:` and
`-volumeThumbImageForState:` are among its 54, and they are how a caller already customises the image on
this release's volume slider. So the value is stored on a view whose slider machinery is already equipped to
hold a custom image.

What this file does **not** claim is that the release draws it automatically. Nothing in the release's 54
methods reads a property of that name — the property *is* the 7.0 one and the release predates it. The row's
`effect` says exactly that: the value is stored, and the release's own thumb accessors are how it would be
drawn.

## A category cannot have an ivar, and that is why this is an associated object

The first draft used `@synthesize volumeWarningSliderImage = _volumeWarningSliderImage;` in the category,
and clang answered:

```
error: @synthesize not allowed in a category's implementation
error: use of undeclared identifier '_volumeWarningSliderImage'
```

The alternative — a subclass — would claim a class the release already owns. So the value is held as an
**associated object**, which is the tree's own idiom for this shape and not a new mechanism:
`UIKit/CADisplayLink+FrameRate.m` stores its two values the same way, with a `static const char` key and
`OBJC_ASSOCIATION_RETAIN_NONATOMIC`. A distinct file-scope `static const char` per associated object is what
keeps two ports' categories on one class from colliding.

`OBJC_ASSOCIATION_RETAIN_NONATOMIC` is `strong` for the property the header declares, and **not** `copy`: a
`UIImage` is immutable by contract, and copying one would produce a second object the release's own drawing
code would not recognise as the one the caller supplied.

## The check, and one mutation it cannot catch

`tests/backports/host/mediaplayeritem/volumeview.m` — 6 checks, 0 failures. Both stand-ins are load-bearing:
this Mac has an `MPVolumeView` and a `MediaPlayer`, and **UIKit does not exist on macOS at all**, so
`standin/UIKit/UIKit.h` declares the one class the property's type names. The stand-in classes need
`@implementation`s as well as `@interface`s, or the link fails with `_OBJC_CLASS_$_UIImage` undefined — the
same class of defect as `MPSystemMusicPlayerController` in `QueueDescriptors.md`.

| mutation | verdict |
| --- | --- |
| the getter returns nil always | `RED` ×5 |
| `RETAIN_NONATOMIC` → `ASSIGN` | **`OK (0 failures)`** |

**The second does not fail, and the reason is ARC rather than the check.** Under ARC the local variable in
the test still holds a reference for the duration of its scope, so the association is not the only owner
while that local is alive, and an unsafe association is masked. An MRR build of the same check would see it.

So the honest statement is that **this check does not establish the retention**; the property's `strong` is
implemented by the association flag, and the flag is asserted by the source rather than by this file. The
check's header says so, so a reader is not left believing a line it cannot earn.

Two smaller fixes the check forced, both measured rather than assumed:

- the retention case cannot send `-release` under ARC (`ARC forbids explicit message send of 'release'`), so
  it is written as an autorelease pool whose local goes out of scope — the association is then the only
  owner, which is the fact under test;
- a stand-in class with a subclass of its own needs the **superclass implemented** too, or the link fails
  naming `_OBJC_METACLASS_$_MPVolumeView` as well as the class.

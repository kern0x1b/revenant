# The preferred format and the format for a trait collection, iOS 11.0

iOS 11 added two class factories to the renderer formats: `+preferredFormat`,
on `UIGraphicsRendererFormat` and overridden by `UIGraphicsImageRendererFormat`,
and `+[UIGraphicsImageRendererFormat formatForTraitCollection:]`. iOS 12 added
`preferredRange`. The classes belong to the iOS 10 range, and these members
belong to this one. The two factories are categories that depend on nothing but
the classes' own `+defaultFormat`, `scale` and `prefersExtendedRange`.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372):
- `+[UIGraphicsRendererFormat defaultFormat]` at `0x18a654eb0`;
- `+[UIGraphicsRendererFormat preferredFormat]` at `0x18a654ef4`;
- `+[UIGraphicsImageRendererFormat preferredFormat]` at `0x18a9e88c0`;
- `+[UIGraphicsImageRendererFormat formatForTraitCollection:]` at `0x18a9e88cc`.

The same methods were read in UIKitCore of 12.0 and of 18.0 (arm64e,
`formatForTraitCollection:` at `0x185a8292c`). Behaviour that can be watched
from outside comes from the differential test against the host's UIKit
(`tests/backports/host/rendererformat`).

## The preferred format is the default one

On the base class, `+preferredFormat` is not built from `+defaultFormat`. It is
a second copy of the same body: allocate the receiver, `-init`, and set the
bounds to zero. On the image format, `+preferredFormat` is a single message: it
sends `+defaultFormat` to the receiver and returns what that answers. The two
are the same in 11.0, 12.0 and 18.0.

So the preferred format is not a separate decision. What makes it right for the
screen - the main screen's scale and whether the device can show an extended
range - is decided in `+defaultFormat`, which the iOS 10 range already carries.
On an iPhone 4S or an iPad 2 that means the main screen's scale and no extended
range (`facts/UIKit/UIGraphicsImageRendererFormat.md`). The port's categories
keep both shapes: the base class allocates and initialises the receiver, and
the image format asks its own `+defaultFormat`. A subclass that overrides
`+defaultFormat` therefore sees the same thing it would see on iOS 11.

## The format for a trait collection

- **A nil trait collection is refused.** The release goes to the assertion
  handler, with the reason
  `Invalid parameter not satisfying: traitCollection`. The port raises
  `NSInternalInconsistencyException` with the same reason.
- **The rest starts from the receiver's `+preferredFormat`.**
- **The display scale.** If the magnitude of the trait collection's
  `displayScale` is not below a small threshold, it becomes the format's
  `scale`; otherwise the preferred format's scale stays. The threshold is
  where the releases differ. In 11.0 it is `FLT_EPSILON` (the double
  `0x3E80000000000000` at `0x18ad101e0`). In 18.0 it is `DBL_EPSILON` (built in
  place as `0x3CB0000000000000`). The host agrees with 18.0: a display scale of
  `1e-9` becomes the format's scale, and `1e-17` does not. This package carries
  the newest behaviour, so the port uses `DBL_EPSILON`.
- **A negative scale is taken as it is.** The comparison reads the magnitude, so
  `-2` becomes the format's scale on the host and in the port alike.
- **The display gamut.** If it is `UIDisplayGamutUnspecified`, the preferred
  format's `prefersExtendedRange` stays. Otherwise `prefersExtendedRange`
  becomes whether the gamut is anything but `UIDisplayGamutSRGB` - that is, YES
  for P3.
- Nothing else is read. `opaque` and the bounds are those of the preferred
  format.

A trait collection that says nothing about the display - an empty one, or one
with only a size class - has a display scale of zero and an unspecified gamut.
It gives the preferred format unchanged.

`displayGamut` is an iOS 10 trait. The system's `UITraitCollection` of iOS 8
and 9 does not answer it, and the one this package carries for iOS 6 and 7
declares it without implementing it. On those releases, a trait collection
that does not answer `displayGamut` is read as having an unspecified gamut: a
release without the trait has no gamut to specify. Asking it anyway would end
the process on an unrecognised selector for every trait collection but nil.

On an iPhone 4S or an iPad 2 no trait collection the system builds carries P3.
If an application builds one, the format stores `prefersExtendedRange` YES as
the release would. What the renderer then draws is the iOS 10 range's business,
and it never draws an extended range (see below).

## `preferredRange`, iOS 12

`preferredRange` is stored as the value given: automatic (0) by default, and the three set values and unspecified (-1) are kept
as they are. A copy keeps the range it had when it was made, and later changes to the original do not reach it. The deprecated
`prefersExtendedRange` is the same value seen as a flag: YES makes the range extended, and NO takes an extended range down to
standard and leaves automatic, standard and unspecified alone. The host does this (`tests/backports/host/storage-config`).

The range does not change what the port draws. No context the port builds is of extended range, so a renderer draws in the colour
range it always did whatever the property says. That is the one difference between the property and the host, which does draw
extended where it is asked to.

## How far this is checked

`tests/backports/host/rendererformat` holds the port to the host's UIKit, 18
checks, and adds a nineteenth that only the port answers: a trait collection
that knows its scale but not its gamut. The eighteen checks cover:
- both preferred formats and the default one;
- a nil trait collection;
- an empty one;
- scales of 3, 1, 0, `1e-9`, `1e-17` and -2;
- each gamut;
- scale and gamut together;
- a collection with nothing about the display.

The same cases ran on an iPhone 4S on 6.1.3 through a tweak loaded into
Preferences. The system cannot build a P3 trait collection there, so the two
gamut cases used an object that answers a display gamut. Every answer of the
two factories matched the host's. The run also showed that this release's
trait collections do not answer `displayGamut`, which is the case the port
reads as unspecified.

Two checks of that run belong to the classes rather than to these members:
- `preferredRange` answered YES, because the compiler synthesises the property
  the SDK declares on the class;
- an image drawn by the renderer came out empty, because `kCGColorSpaceSRGB`
  gives no space on this release.
Both are for the owner of the classes.

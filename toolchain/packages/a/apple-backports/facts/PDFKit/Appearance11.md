# PDFAppearanceCharacteristics as the value object the header declares

## What the class is, and where it comes from

`PDFAppearanceCharacteristics` is a class neither band carries - `objc.inventory` reports it as carried
by neither 6.1.3 nor 4.3 - so it is the port's own, like `PDFDocument`, `PDFPage` and `PDFBorder`.

What makes it different from those three is that **nothing in the 26.2 SDK hands one out**. There is no
`-[PDFAnnotation appearanceCharacteristics]`, and `grep -rn appearanceCharacteristics` across
`PDFKit.framework/Headers` in `charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk` finds this class's own
key-values property at `PDFAppearanceCharacteristics.h:69` and nothing else anywhere. So there is no
document to read it out of, and no path in the API that returns one.

That makes the class a **value object** and the comparison object against object: both sides build one
with `-init` (the header declares no initializer, so `NSObject`'s is what each has), set members, and
read them back. Every rule below was measured by doing exactly that on the host and then on the port.

## Why a third binary, and what it costs

The two colour members are `PDFKitPlatformColor`, which is `UIColor` on iOS and `NSColor` on macOS. A
macOS process has no `UIColor`, so the port's own objects cannot be asked there with a real colour - and
a stand-in colour object would be exactly the sort of thing that makes a differential look green while
proving nothing.

Mac Catalyst has both: UIKit backed by AppKit, and the same CoreGraphics the port reads a PDF with.
`tests/backports/host/pdfkit-document/color.m` is the port's objects built
`-target arm64-apple-ios15.0-macabi -iframework "$sdk/System/iOSSupport/System/Library/Frameworks"` -
the same shape `tests/backports/host/uikit2/run.sh` uses - and it prints **only** the appearance block,
in the same order and the same keys `host.m` prints it.

So the two printing helpers are written out twice, once per binary, and that is forced rather than
tidy: `host.m` includes `<PDFKit/PDFKit.h>` and `color.m` includes `"CharonPDFKit.h"`, and a
translation unit holding both would have two `@interface PDFDocument` definitions that disagree -
which is the reason this harness is separate processes in the first place. Their shapes stay identical
on purpose, because `run.sh` compares by key and a key only one side prints is not a fact at all.

`run.sh` merges those `appearance.` keys into the port's map and only those, and it refuses the merge
in two cases rather than half-doing it:

* if the Catalyst side printed a key that is **not** an `appearance.` key, the merge is refused - that
  would mean `color.m` had grown a `printf` beyond its block and the override would be reaching facts it
  was not built for;
* if it printed **nothing**, the merge is refused - otherwise every appearance key would silently be
  compared against the macOS port side, which has no `UIColor` to answer the two colour members with.

The verdict line carries the size of the move: `of which 72 compared from the Catalyst side`.

What the comparison is: the host sets `NSColor redColor` and reads `1 0 0 1` back; the port sets
`UIColor redColor` and reads `1 0 0 1` back. `-getRed:green:blue:alpha:` is on both classes, so the four
components are what each platform's own colour class answers. The colour classes differ; the colours do
not, and the comparison is of the colour.

## The rules, each with what fixes it

| fact | measured |
| --- | --- |
| a fresh object | `-controlType` -1, `-rotation` 0, both colours nil, all three captions nil |
| `appearanceCharacteristicsKeyValues` on a fresh object | **one** key: `R = 0` |
| `R` is unconditional | one key on a fresh object, two with only a caption set (`CA`, `R`), one with `-rotation` set to 0 explicitly |
| `-controlType` is not published | set to each value from -1 to 3 and read back exactly, and the key values stay at one key throughout; six members set at once give six keys, none of them this one |
| setting nil **clears** | caption and background colour set, then set to nil: the key values fall from three keys back to the one `R` |
| an empty string is a value | caption and down caption both set to `@""` answer three keys, so the test is nil and not "has characters" |
| a negative rotation is kept | `-rotation -90` is read back as -90 and the key values hold one key, so the value is not clamped into a range |

So the port keeps one `NSMutableDictionary` of the six `/MK` keys and one ivar for `-controlType`, and
`-appearanceCharacteristicsKeyValues` is a **copy** of that dictionary - a caller holding it must not be
able to change the object through it.

## What is NOT here, and why

* **Reading an annotation's `/MK`.** The host exposes no path from an annotation to one of these
  objects, so there is nothing to compare a reading against. The port does not invent one: it does not
  add an accessor the 26.2 header does not declare, because an invented accessor is an invented API.
* **The colour ARRAYS of `/BG` and `/BC`.** What those arrays mean - no colour, gray, RGB, CMYK, and a
  component count that is none of those - is measured, and the measurement is what
  `-[PDFAnnotation border]` uses to decide a widget's border (`Border11.md`, "What the class is"). It is
  not turned into a colour parser here, because there is no host object to parse it into and no
  `-[PDFAnnotation color]`, which is the row that would need it, is `inert` on main.
* **`PDFWidgetControlType`'s other rows.** `-controlType` is the whole of the enum's surface in this
  class. `PDFAnnotation`'s own `widgetControlType`, `widgetFieldType` and the rest are rows of
  `PDFAnnotation`'s own family.

## The run

The appearance facts are 72 of the run's 3632, and four of the eleven red controls name one of them -
`appearance.full.key.BG`, `appearance.fresh.key.R`, `appearance.cleared.keys` and
`appearance.controlType2.keys` - so the block has its own mutants and not only the harness's automatic
one. See `Border11.md`, "The run", for the verdict lines and for why each named control is planted in
the side that printed its key.
# CIImageAccumulator, carried for iOS 6

11 rows, `registry/CoreImage/accumulator9.json`.

iOS 6 has no `CIImageAccumulator`: the 6.1.3 armv7 cache's whole selector table has no
`imageAccumulatorWithExtent:format:` and no `setImage:dirtyRect:`. The class arrived in iOS 9.

An accumulator is a piece of memory at an extent and a pixel format, that an image is rendered into
and read back out of. `image` is a `CIImage` over the accumulator's own bytes, so what was set into
them is what comes out; `setImage:` renders over the whole extent, `setImage:dirtyRect:` over the
rectangle that changed and no other, and `clear` empties them. The bytes a format takes a pixel to
are the format's own width, read from the header's declaration of it, and the row of them is the
extent's width in pixels.

## What the two-process probe measured, and what it found

`tests/backports/host/ciimage/pixel/` is the same shape as the ModelIO one: one probe built twice, once
against the framework the host carries and once against the port's own accumulator, each run over the
same script, each writing the extent, the format, the image's extent, and the length and checksum of
the RGBA bytes the image renders to, with four pixels spelled out. The port's copy is built under a
name of its own, because it re-implements a class the framework has; the framework's accumulator is in
that process and is never asked, so the two never touch the same object.

**The tree's own run, and the count this page's family is inside it:**

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)

Forty differences in all, and the accumulator family is **one** of them: `odd set pixels`, the
fractional-extent case below. The other accumulator measurements are equal, and four of them are
byte-identical to the system's:

    rgba set pixels 128 4fcd0585      the system and the port
    bgra set pixels 128 4fcd0585      the system and the port
    spaced pixels 128 4fcd0585        the system and the port
    dirty after 128 c2bab905          the system and the port

This page used to carry a per-page count of its own - `93 measurements, 90 the same, 2 different, 2 one
side only` - and then the whole run as `539 measurements, 454 the same, 77 different, 42 one side
only`, which was the previous pass's run. Neither is a number this page can be held to: the probe asks
about every family in one run, so a per-page figure can only be one somebody subtracted by hand, and a
hand-subtracted one drifted - the first was a count of a comparator that read only the first number of a
line, and the second belonged to a tree two fixes ago. What is quoted here is the run, the group, and
the command that prints the group out of the run, so the number cannot be restated by hand:

    # the page writer (removed) made the table from the two diffs:
    | `odd set` | 1 | `odd set pixels` | odd set pixels 60 f6009964 | odd set pixels 60 f1fc1875 |

**Three defects it found on its first run, all fixed.**

  1. **A double release.** The colour space was retained by hand on the way in and released on the way
     out, and under ARC an object ivar is managed already - so it was released twice, and a caller that
     let an accumulator go trapped inside CoreFoundation. The ivar is a strong reference and its
     refcount is not touched.
  2. **The format is normalised, not stored as asked.** The host answers `kCIFormatBGRA8` for an
     `kCIFormatRGBA8` request and for a `kCIFormatBGRA8` one alike, and the accumulator stores and
     reports that. The *bytes* are red first, and this file first said otherwise: it said `setImage:`
     swapped the two outer channels as it wrote, and the whole-tail comparison is what showed that
     claim was wrong - `-image` reads the buffer through a `CGBitmapContext` made with
     `kCGImageAlphaPremultipliedLast`, which is red first, so the buffer is red first and swapping
     made a picture with red and blue exchanged. Measured, with the swap in place, `rgba set pixels` was
     `128 915d7485` where the system's is `128 4fcd0585`; without it, `128 4fcd0585` on both sides.
  3. **The extent is the caller's, whole pixels or not.** The port integralised it; the host answers
     exactly what it was given, and answers the *image* over the whole pixels at the origin, which is
     `0 0 5 3` for an extent of `1.5 -2.25 5.5 3.5`. The accumulator now answers the extent it was
     given and the image over the whole pixels.

**Still different, one measurement, and its cause is measured:** the rendered bytes of the
accumulator whose extent is `1.5 -2.25 5.5 3.5`, where the system writes nothing at all into the
buffer - `60 f6009964`, and its four pixels `0 0 0 0` - and the port writes something into it. Every
other accumulator measurement on this file matches exactly: the extent, the format, the image's
extent, `rgba set`, `bgra set`, `clear`, an accumulator nothing was set into, one with a colour space,
and the dirty-rect case (`dirty after` is `128 c2bab905` on both sides).

The cause is the rectangle, and it was found by writing it the other way round twice. A rectangle that
is not a whole number of pixels at a whole pixel is now left alone, as the system does. Clipping it
into the whole pixels inside it first put a row of red into a buffer the system leaves empty - the
port's own `60 73191c6b` said so against the system's `60 f6009964` - and it also wrote
`ceil(3.5) = 4` rows into a buffer of 3 and ran off the end of it. Neither is what the system does, and
the rule that is left is the one the measurement gives.

## What is not measured, and what is reasoned

- The header does not say which byte order a format the accumulator normalises away from BGRA was asked
  for in, and the probe cannot see it either, because the accumulator answers BGBA for both. That part
  of the contract is unmeasurable through the public surface, and this file says so rather than
  implying the question is settled.
- Nothing here has run on a device or under `xmake emulate`. What that adds is the one thing the host
  cannot answer: that the selectors resolve against the release's own runtime and the port's dylib
  loads beside it.

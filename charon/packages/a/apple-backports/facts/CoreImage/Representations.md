# CIContext's representations, carried for iOS 6

8 rows, `registry/CoreImage/representations10.json`.

iOS 6's CoreImage can represent an image as TIFF, PNG and JPEG. It spells it the way it was spelt
then: no format to ask for, no destination URL, and no error out. What a caller of a later SDK wants
is one encoding step with the format and the destination in it.

The answer is the same bytes either way, and they are made in the two steps that make them: the image
is rendered to a `CGImage` of the format asked for — the format is what decides how wide a pixel is and
what the bytes are read back as — and `CGImageDestination` writes that image. No encoder is invented
here and nothing the release already encoded is re-encoded. A format the encoders cannot carry has no
representation, which is `nil` rather than a file of something else. `clearCaches` is the release's
own `reclaimResources`, which is what it did before the name changed.

## What the pixel probe measured

`tests/backports/host/ciimage/pixel/`: for each of RGBA8, L8 and RGBAf, the PNG and the TIFF
representation, and the JPEG representation, printing the length and checksum of the encoded bytes, the
UTI, the width, the height and the bit depth of the image those bytes decode to, and the checksum and
four pixels of the decoded picture. Plus the `CGImage` the deferred form gives, by its size and bit
depth, and the file `writePNGRepresentationOfImage:…` writes — its bytes read back from disk.

**`ciimage: 398 measurements, 398 the same, 0 different, 0 one side only`**, at a tolerance of 5e-4. The
encoded bytes are the same, and so is the picture they decode to.

**And four lines of this family are different in the tree's own run**, over

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)

against the `0 different` above, which is what the old comparator - the one that read only the first
number of a line - reported. They are the two `rgba8` formats and the write:

    repr rgba8 png none              the port repr rgba8 png 161 155f579e
    repr rgba8 png tiff none          the port repr rgba8 png type public.png size 6 4 bits 8 32
    repr write png 0                  the port repr write png 1
    repr write png file 0 811c9dc5    the port repr write png file 161 155f579e

**The direction is the other way round from what this page first said, and it matters: the PORT
encodes and the SYSTEM answers that it cannot.** `repr rgba8 png` is `none` on the system and 161
bytes in the port; `writePNGRepresentationOfImage:` answers 0 on the system and 1 in the port. **33
further `repr` lines one-sided on the port's side** - the port has bytes, a decoded picture and four
named pixels for `rgba8`, `rgbaf` and `jpeg` in PNG and TIFF, where the system has none of them - and
**3 further `repr` lines one-sided on the system's side**, which are the three that keep the sentence
from being one-way: `repr rgbaf png none`, `repr rgbaf png tiff none` and `repr jpeg none`, the only
lines in the family where the system answers and the port is silent. So the port is not simply
louder than the system: it is louder for the byte formats it writes and quiet for the two it cannot
read back. The bytes the port does produce decode to the same picture the sentence above is about,
and that is still true of them.

Both figures are counted by the page writer (removed), which refuses a page that
quotes either of them wrong, and it read 30 for the port's side until this was written.

## Not carried here, and named

- `+[CIContext contextWithCGContext:options:]` needs a context that draws into a `CGContext`, which is a
  larger piece than the representations: a bitmap render and a draw per call, and the question of what
  the drawing means for a context that is asked to draw the same image twice.
- `workingColorSpace` and `workingFormat` are the two properties that answer what a context was made
  with, which means remembering the options it was made with. Not carried yet.
- The Metal spellings, the HEIF and OpenEXR encoders, the depth-blur filters and the HDR statistics
  are separate families and none of them is here.
- Nothing has run on a device or under `xmake emulate`.

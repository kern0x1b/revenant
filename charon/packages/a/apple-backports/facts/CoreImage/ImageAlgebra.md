# CIImage's algebra, carried for iOS 6

19 rows, `registry/CoreImage/algebra10.json`.

iOS 6 has the filters this is made of and not the operation. Read out of the release's own 6.1.3 cache:
`CIAffineClamp`, `CIAffineTransform`, `CIColorMatrix`, `CIMultiplyBlendMode`, `CIGaussianBlur`,
`CISourceOverCompositing`, `CICrop`, `CIConstantColorGenerator`, `CIMaskToAlpha` and
`CILanczosScaleTransform` are all there, and `CIDivideBlendMode`, `CIPremultiplyAlpha`,
`CIUnpremultiplyAlpha`, `CIIdentity`, `CIInsertIntermediate` and `CIRenderDestination` are all absent.
So each of these is the release's own filter composed into the operation, and the composition is the
whole of it.

`-imageByInsertingIntermediate:` takes a **BOOL cache flag**, not a filter name, and the header's
spelling is what the port answers.

## What the pixel probe measured

`tests/backports/host/ciimage/pixel/`: a field with an alpha in it, and from it the blur at a sigma, the
clamp to the extent and to a rectangle, both spellings of the intermediate, the premultiply, the alpha
set to one over the whole extent and over half of it, the transform with and without the high-quality
flag, the properties, and all ten constant colour images. For each, the extent of what comes out and
the bytes it renders to.

**`ciimage: 530 measurements, 530 the same, 0 different, 0 one side only`**, at a tolerance of 5e-4.

**And the tree's own run gives twenty-three differences in this family**, over

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)

against the `0 different` above, which is what the old comparator - the one that read only the first
number of a line - reported. Twenty of them are two groups: the eight `alg clamped` lines, where the
system's clamped image is the infinite extent and 96 bytes and the port's is `0 0 3 2` and 24, and the
twelve `alg intermediate` lines, off by one unit in the green channel of every pixel in both spellings
of `-imageByInsertingIntermediate:`. The other five are `alg transformed hq`, the high-quality
downsample, one or two units in two channels.

Two rows that used to be here are not, and the reasons are the rows' own: `-imageByPremultiplyingAlpha`
(d255cf714) and `-imageBySettingAlphaOneInExtent:` (78b6730f2) are both `absent`, the port answers
neither, and the probe does not ask them. The second of those was the worst of the differences - an
infinite extent where the system's is `0 0 6 4` - and it is gone with the row.

## Not carried, and why - read the release's own selector table

- **`+[CIContext contextWithCGContext:options:]`.** Checked rather than assumed: the 6.1.3 selector
  table has `contextWithOptions:`, `contextWithEAGLContext:` and `contextWithEAGLContext:options:`, and
  **no `contextWithCGContext:` at all**, in either spelling. There is nothing on the release for it to
  extend. Carrying it means a context of the port's own that draws into a `CGContext`: a bitmap render
  and a draw per call, and a real question of what drawing means for a context asked to draw the same
  image twice.
- **`-imageBySettingProperties:`** needs a way to put properties on an image, and the release has none:
  the header's `properties` is readonly with no setter, so the only implementations are a touch of the
  private ivar behind it - a crutch - and a call back into the method for a new image, which is a stack
  overflow (measured under `-fsanitize=address`, and `setValue:forKey:@"properties"` on a `CIImage`
  raises `NSUnknownKeyException`). The row is not carried.
- Together with the unpremultiply and the clamps, **three of this family are methods the framework
  calls on an image while it renders it**, not conveniences a caller makes. Answering them from a
  category replaces the framework's own step, which calls the port's, which calls the framework's. That
  is the trap, and it is the same one three times.
- **`-imageByUnpremultiplyingAlpha`** needs a filter that divides by alpha, and the release has none:
  `CIDivideBlendMode` is absent from its cache. The one honest path is through the port's own
  accumulator, dividing the bytes per pixel, and that is not written yet.
- **`-imageBySamplingNearest`** needs a nearest sampler; the release samples linearly and has no other
  sampling to leave. `facts/CoreImage/Compositing.md` already records that for the method of the same
  name that is carried.
- **`workingColorSpace` and `workingFormat`** answer what a context was made with, which means
  remembering the options - and a category cannot add storage to a class the framework has, so this needs
  a subclass of the port's own, with the same consequence for a context the release made itself.
- Nothing has run on a device or under `xmake emulate`.

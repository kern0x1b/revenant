# A CIContext with a surface and options, and two rows that are not carried, for iOS 6

3 rows, `registry/CoreImage/ctxowner9.json`: one `implemented`, two `absent`.
`-imageBySamplingNearest` is in `facts/CoreImage/ImageAlgebra.md` and is not carried; the reason is
there.

iOS 6's selector table has `contextWithOptions:`, `contextWithEAGLContext:` and
`contextWithEAGLContext:options:` and **no `contextWithCGContext:` in either spelling**. So the context
here is one of the release's own, made by the release's own method, with the caller's `CGContext` and
the options kept beside it as associated objects — a category cannot add storage to a class the
framework has, and an associated object can, on any object, since iOS 3.1.

The header's drawing method is `drawImage:inRect:fromRect:`, not a bare `drawImage:`; that is the one
replaced, and **beside the replacement is one that leaves a context with no drawing surface alone**, so
a context the port did not give a surface is still drawn by the release.

## The two rows the port answers with NO, and why each is `absent`

Both were carried at one point and both came out. What follows is what was measured, and every number
here is an output line of a probe in `tests/backports/host/ciimage/pixel/`: the differential the band runs
through that directory's `run.sh`, and `distinct.m`, which is the seven-line one and is in the tree.

**`-imageBySettingProperties:`** — the port returned a copy with the caller's dictionary merged onto it.
The values read back correctly (`props count 1`, `props value one` on both sides) and the pixels
matched, but the object was not distinct: `props distinct 0` where the system gives `1`. A copy is the
obvious way to get a second image and it does not work, because `CIImage` is immutable. Measured, over
one image, seven public constructions and **all seven hand back the same object** — the output of
`tests/backports/host/ciimage/pixel/distinct.m`, which is the probe and is in the tree:

    copy                                           distinct 0
    mutableCopy                                    distinct 0
    CIGammaAdjust power 1                          distinct 0
    CIColorMatrix identity                         distinct 0
    crop to own extent                             distinct 0
    affine identity                                distinct 0
    CIGammaAdjust power 2 (a real change)          distinct 0

The last line is the one that settles it: even a filter that visibly changes the image returns the same
`CIImage *`. The system's `-imageBySettingProperties:` returns a distinct object because it builds the
image **inside** the framework, and no caller-facing construction does. So the identity is not reachable
from outside, and the port's answer was the caller's own image handed back with a dictionary attached to
it — `props source still 1` on the port against `0` on the system, a call that reported a change and
changed the receiver. There is no native fix without the private ivar behind `properties`, which is a
crutch, so the row is `absent` and `respondsToSelector:` answers NO.

**`-imageByUnpremultiplyingAlpha`** — the release has no filter that divides by alpha
(`CIDivideBlendMode` is absent from its 6.1.3 cache), so the only arithmetic available is the port's own
over the rendered bytes. The host's answer over a finite extent, measured: the extent unchanged, each
channel divided by the alpha, a result over one clamped, the alpha untouched, and an **infinite** extent
answered as the image itself, which is what the system does (it comes back still infinite and is not
rendered, so there is nothing to divide). The port agreed on all of that and on the alpha, and came out
one step off on a colour channel:

    unpre finite pixel 0    system 255 153 255 128    port 255 151 255 128

The division happens on an 8-bit render of an already premultiplied buffer, and 8 bits are what the
release's own render gives; the system divides at its own precision, below the byte. `kCIFormatRGBAh` is
available from iOS 6.0 (`CIImage.h:51`) and was the obvious way to keep the headroom — it is not one:
`RGBAh` is a **linear** format, so a round trip through it adds a colour-space conversion rather than
removing a quantisation, and the premultiply→unpremultiply round trip that is exactly the identity on
the system stops being one. Two steps of a division that is not the system's, in a colour channel, with
no way for a caller to see them, is the quiet inexactness the registry's `absent` is for. The row is
`absent`.

**The `-properties` row is not in the registry at all, and that is right.** The header declares
`@property (atomic, readonly) NSDictionary *properties NS_AVAILABLE(10_8, 5_0)` (`CIImage.h:408`), so
the release carries it from 5.0 and answers it itself. The port had replaced it to serve the row above;
with that row `absent` the replacement had nothing to serve and is gone, so the release's own
implementation is what a caller reaches, and there is no row to write.

## What the earlier `crutch` status was, and why it is not one of the four

An earlier pass wrote both rows with `status: crutch` and pointed at `coordination/crutches.md`.
`registry/README.md` says `status` "is one of four, and there is no fifth", and
`modules/apple/backports.lua` reads any other value as "not one of the four answers" and stops the
build. A fifth status is a way of saying *this is not a status*; the honest thing is to say which of the
four it is, and for both of these it is `absent`: not there at all, so `respondsToSelector:` answers
honestly, which is required "wherever quiet inaction would corrupt data or mislead".

## One correction to the record, and it is not a detail

The line the earlier pass quoted as `unpre round trip` — `487584e5` on the system against `fd3b7745` on
the port, read there as "a premultiply followed by an unpremultiply is not the identity" — **does not
measure the unpremultiply.** Its source is:

    put_bytes(@"unpre round trip", render([[finite imageByPremultiplyingAlpha] imageByCroppingToRect:bounds]));

which asks `-[CIImage imageByPremultiplyingAlpha]` and nothing else. The unpremultiply is not in it. So
that divergence belongs to the premultiply row in `registry/CoreImage/algebra10.json`, not to the two
rows here, and the reason those two rows came out is the identity and the one-step channel, both above.
The probe now asks the premultiply under its own name (`premul`), so the line says what it measures.

## The two properties, not carried and not ignored

`CIContext.workingColorSpace` and `CIContext.workingFormat` are **not in the registry at all**. They
were `implemented` and the gate said the base `CIContext` does not build them — the port's own context
class answers them, and a `CIContext` the release made does not have them either. They were `ignored`
and the gate said the release does not carry them, which at iOS 6.1.3 is true. So neither status is
honest and the rows are gone, with the reason here: **a release that has a working colour space and
format answers them itself, and on one that has not the port's own context class answers them for the
contexts the port makes** — which is a property of `CharonGOCtxContext`, not of `CIContext`, and a
caller holding a context the port did not make finds nothing either way.

## What the pixel probe measures

`tests/backports/host/ciimage/pixel/`: a context made over a `CGContext` on each side — once with a
named working colour space and once with none — printing the working format and whether a working space
is there, then drawing an image into that context and printing **the bytes the `CGContext` ended up
holding** and four of its pixels. The CoreImage differential's verdict line is in
`facts/CoreImage/Differences.md`, at a tolerance of 5e-4.

## Not carried, and why

- **`-imageBySamplingNearest`.** On the release every image is sampled linearly and there is no sampler
  to mark an image with, so nearest sampling is a property of a *later transform* and not of the image.
  The port has nowhere to put the mark, and an identity here would be the same pixels wearing a claim
  they have not earned. The pixel probe shows the two sides agree on the pixels, which is the evidence
  for the statement rather than a substitute for the method.
- Nothing has run on a device or under `xmake emulate`. Every number above is the host's CoreImage, and
  a statement about the release's own answer to these two calls is not made.

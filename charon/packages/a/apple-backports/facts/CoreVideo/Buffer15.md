# The attachment readers of iOS 15, and the colour space of iOS 10

Six functions, four objects, each built on a reader the release itself carries.

## What the release has, measured through its export trie

CoreVideo of the armv7 shared cache of iOS 6.1.3 exports 204 symbols and of iOS 4.3 exports 178. The
ones these six functions are built on:

| release's own function | 6.1.3 | 4.3 | what the newer name is |
| --- | --- | --- | --- |
| `CVBufferGetAttachment` | yes | yes | `CVBufferCopyAttachment` (15.0) |
| `CVBufferGetAttachments` | yes | yes | `CVBufferCopyAttachments` (15.0) |
| `CVPixelBufferGetAttributes` | yes | yes | `CVPixelBufferCopyCreationAttributes` (15.0) |
| `CVPixelBufferCreateWithPixelBuffer` etc. | yes | yes | the buffer the three above are asked about |

and it carries **no** `CVBuffer*Copy*` and **no** `CVBufferHas*` name at all, which is why each
function here is the release's reader with the ownership the iOS 15 header puts on top of it:

- `CVBufferCopyAttachments` — the release's `CVBufferGetAttachments` hands back a dictionary the
  release owns, and the iOS 15 header marks the result `CV_RETURNS_RETAINED`, so the copy is what
  carries the ownership. NULL stays NULL.
- `CVBufferCopyAttachment` — the same for one attachment, and the mode out-parameter is filled from
  the release's own reader before anything else, so a caller that asks where the attachment was
  stored gets the release's answer. A CF object has no generic copy, so the copy is made of the type
  the release stored: `CFStringCreateCopy`, `CFDataCreateCopy`, `CFDictionaryCreateCopy`,
  `CFArrayCreateCopy`, and a plain `CFRetain` for anything else, which the release's retain count
  then protects.
- `CVBufferHasAttachment` — whether the release's own reader answers for the key at all.
- `CVPixelBufferCopyCreationAttributes` — the release's `CVPixelBufferGetAttributes` is the same
  dictionary the header describes ("Returns a copy of pixelBufferAttributes dictionary used to create
  the PixelBuffer"), and the header marks the result `CV_NONNULL`, so a buffer whose own dictionary
  the release declines to produce still gets the empty dictionary rather than a NULL the caller does
  not expect to release.

`CVPixelBufferGetAttributes` is declared in the port's own file: the header of iOS 16.4 no longer
declares it, so it is the private entry point the registry README describes, and `introduced` on the
row is the release of the API that needed it.

## What the host answers, measured

`tests/backports/host/corevideo/run.sh` links the port's objects into the same binary as the host's
own CoreVideo, renamed to `charonHost_*`, so both answers are callable in one process. The verdict
line of the run that delivered this:

```
functions: checks=48 same=48 different=0
```

48 cases over the six functions. `MUTATE=1 sh tests/backports/host/corevideo/run.sh` inverts one
answer and misspells one carried string, and the run then fails with 30 and 1 `BAD` lines, so the
harness is shown able to fail rather than only shown to pass.

## `CVImageBufferCreateColorSpaceFromAttachments` and the code points

The header names two ways to build the colour space: an ICC profile under
`kCVImageBufferICCProfileKey`, or the three code points. Measured against the host over eleven
dictionaries:

| attachments | the host answers |
| --- | --- |
| an ICC profile | `kCGColorSpaceSRGB`, the colour space the profile is |
| an ICC profile and the three code points | `kCGColorSpaceSRGB` |
| `ITU_R_709` / `ITU_R_709` / `ITU_R_709` | NULL |
| `ITU_R_2020` / `ITU_R_2020` / `ITU_R_2020` | NULL |
| `DCI_P3` / `DCI_P3` / `DCI_P3` | NULL |
| `P3_D65` / `ITU_R_709` / `ITU_R_709` | NULL |
| `ITU_R_601` / `SMPTE_ST_428_1` / `SMPTE_ST_428_1` | NULL |
| the three and `kCVImageBufferGammaLevelKey` | NULL |
| a triple of nonsense | NULL |
| the primaries alone | NULL |
| an empty dictionary | NULL |

So on the host the profile is the case the release answers and the code points are a case it
declines to answer from the attachments alone, and the port follows exactly that: NULL is the
header's own stated answer for a dictionary that does not carry the information required, and a
colour space invented out of a name would not be one. The caveat is recorded rather than hidden: a
release that does answer the triple case would answer it through a CoreMedia code-point table that
is not in this port, and the row's `reason` says so.

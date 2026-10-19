# MetalPerformanceShaders, the two 10.0 classes this landing carries

`MPSCNNFullyConnected10.m` and `MPSImageConversion10.m`, and what was checked before they were
written. Both are release 10.0 and neither file holds anything else, so ONE .m per release holds.

This is a PARTIAL landing of the band `band-wmtl-mps10` (2 commits, gated green on its own base).
The series carried seven `.m` files; a competing MPS 10.0 series landed on `main` first and already
carries most of them. Only the two classes `main` does not define are here. What the other five
files hold and why they are not in this landing is written down at the bottom, because a reader who
knows the series will otherwise think they were forgotten.

## WHAT THE TWO FILES CARRY

| file | class | release |
| --- | --- | --- |
| MPSCNNFullyConnected10.m | MPSCNNFullyConnected | 10.0 |
| MPSImageConversion10.m | MPSImageConversion | 10.0 |

Two rows of `registry/MetalPerformanceShaders/absent_MetalPerformanceShaders.json` change with them,
`MPSCNNFullyConnected` and `MPSImageConversion`, both `absent` -> `implemented`. Both files are
byte-identical to the branch's; nothing in either was rewritten for this landing.

## WHAT WAS CHECKED HERE, AND THE COMMAND BESIDE IT

**Where each name is real, and in which held rung.** `xmake l tools/cache-index/first-rung.lua MPSCNNFullyConnected MPSImageConversion`,
run from this checkout, answering from the index rather than from the dyld caches:

```
MPSCNNFullyConnected	10.0.1
MPSImageConversion	10.0.1
```

**Neither class is defined anywhere on `origin/main`.** `git grep -E "@(implementation|interface)[[:space:]]+NAME"`
over the whole tree at `origin/main` (`68b70de7c`) returns nothing for either name. Both names do
occur on `main` - `MPSCNNFullyConnected` in a comment in `MPSCNNElements10.m:32`, in
`facts/MetalPerformanceShaders/Elements10.md`, and in the registry; `MPSImageConversion` in comments
in `MPSCNNElements10.m` and `MPSImageElements10.m`, in `Elements10.md` and `Owed.md`, in the
registry, and in `tests/backports/host/mpsimage10/` - and not one of those occurrences is a
definition. No `@interface`, no `@implementation`, no category on either.

**Both compile for the 6.1.3 target, under the gate's own clang.** `clang -fsyntax-only -fobjc-arc -Os
-Wall -Wno-unguarded-availability-new -Wno-unguarded-availability-obsolete
-Werror=objc-missing-property-synthesis -target armv7-apple-ios6.1.3 -isysroot
<iphoneos-sdk 16.4> FILE`, with the `llvm` package's clang 23.1.1: exit 0 for each file, no
diagnostic from either source. The two warnings the command prints are about the command line and
not about the sources: `-Wincompatible-sysroot`, because the requested target is 6.1.3 and the
requested sysroot is 16.4, and `-Wunknown-warning-option` for `-Wno-unguarded-availability-obsolete`,
which this clang does not have.

**Neither file is MRC.** No `[x retain]`, `[x release]`, `[x autorelease]`, no hand-written
`-dealloc`, no ARC opt-out pragma in either file. The package is built with `-fobjc-arc`
(`modules/apple/backports.lua`), so any of those would not compile.

**The registry file gained no rows and lost none.** The `api` list at `origin/main` and in this
revision are the same 327 names in the same order, and no object carries a key twice. Only the two
rows above differ. (Note for the next reader: this paragraph used to carry a warning that
`python3 tools/registry-shape.py --against <ref>` could not answer in the whole tree, because it walked
every registry file and died with `KeyError: 'entries'` on `registry/Intents/constants.json`, whose schema
was `constants`/`note`/`source`. Both halves of that are gone: the tools read every registry document
through the registry rows reader (removed), which refuses that shape **by name** and says where it lives, and the
manifest itself moved out of the registry to `tools/intents/constants.json` on 2026-10-03, because it was a
generator input and not a row list - a document with no array part, on which `ipairs(held.entries or held)`
makes 0 iterations, so the gate had never seen any of its 83 rows.)

## WHAT WAS NOT RUN, AND IS NOT CLAIMED

No gate, and no armv7 **link** - a `-fsyntax-only` run says the source is well formed and nothing
about symbols, so neither object was linked and neither class's `_OBJC_CLASS_$_` symbol was proven
to exist. No host case was run, no device was touched, no `build-gate.lua`, no `gate-parallel.sh`,
no `heavy.sh`, no xmake build, no `release-split`. The light guard
(`xmake l $HOME/Git/projects/ios/coordination/run_light_tests.lua "$PWD"`) was run and was green.

No number in either file is a measurement of Apple's code, and nothing here claims one. The
release's own MPS cannot run on the build host at all - its AGX family lacks
`computeCommandEncoderWithDispatchType:`, so the release's own kernel dies encoding, which
`facts/MetalPerformanceShaders/Image9.md` already records - so every signature, default and formula
in these two files is transcribed from the SDK 16.4 header and cited by line in the file's own
comment and in its registry row.

## THE FIVE FILES OF THE SERIES THAT ARE NOT HERE, AND WHY

Each of these names is a class `origin/main` already implements, in
`packages/a/apple-backports/MetalPerformanceShaders/`, and its registry row on `main` already reads
`implemented`. Landing the series' copy as well would define the same class twice in one dylib.

| file | class | already implemented on `main` in |
| --- | --- | --- |
| MPSCNNNeuron10.m | MPSCNNNeuron and its five subclasses | MPSCNNElements10.m |
| MPSCNNSoftMax10.m | MPSCNNSoftMax, MPSCNNLogSoftMax | MPSCNNElements10.m |
| MPSTemporaryImage10.m | MPSTemporaryImage, and the allocator beside it | MPSImageElements10.m, CharonMPSTemporaryImage.m |
| MPSCNNNormalization10.m | MPSCNNSpatialNormalization, MPSCNNLocalContrastNormalization, MPSCNNCrossChannelNormalization | MPSCNNElements10.m |
| MPSImagePyramid10.m | MPSImageLaplacian (and only that one of its six classes) | MPSImageElements10.m |

`MPSCNNNormalization10.m` is wholly redundant: all three of its classes are on `main`. The five
classes `MPSImagePyramid10.m` would add - MPSImagePyramid, MPSImageGaussianPyramid,
MPSImageLaplacianPyramid, MPSImageLaplacianPyramidSubtract, MPSImageLaplacianPyramidAdd - are still
`absent` on `main` and are still owed, but that file cannot be landed as it stands because its sixth
class, `MPSImageLaplacian`, is one `main` already has, in a different and separately measured
implementation (`MPSImageElements10.m`, which convolves through the
`MPSUnaryImageKernel(CharonMPSConvolutionSeam)` category rather than by building an
`MPSImageConvolution` per encode). Splitting those five classes out of that file into an object of
their own is the work that is left, and it is not done here.

## ONE PAGE ON `main` THAT THIS LANDING MAKES STALE, AND HOW THE TWO RECONCILE

`facts/MetalPerformanceShaders/Elements10.md` has a section headed "**`MPSCNNFullyConnected` - a
missing data source, and placement is *not* it**" which says, in the present tense, "The walk is
available; the weights are not" and reads as though the class is not carried. That page is the
record of the band that wrote it and is **not** edited here - it is another band's page, and editing
it from this landing is the shared-file mistake `charon/AGENTS.md` warns about. The two reconcile,
and the registry is the live state:

- what `Elements10.md` says is still true of the **11.0** initializer.
  `MPSCNNConvolution.h:1355` makes `-initWithDevice:weights:` the designated initializer and its
  argument is `id<MPSCNNConvolutionDataSource>`, a protocol whose rows are 11.3, so that form is
  still not carried and is still not callable.
- what changed is that the class now exists at all, because 10.0 has a second initializer of its own
  which `MPSCNNConvolution.h:1376-1382` marks
  `MPS_AVAILABLE_STARTING_BUT_DEPRECATED(ios(10.0, 11.0))`:
  `-initWithDevice:convolutionDescriptor:kernelWeights:biasTerms:flags:`, whose weights arrive as
  raw `float` arrays and which needs no data source at all. That is the form
  `MPSCNNFullyConnected10.m` carries.

So "the weights are not [reachable]" was a statement about the 11.0 form, and it stands; the class it
was attached to is now present through the 10.0 form. A reader who wants that page current should
ask the band that owns it.
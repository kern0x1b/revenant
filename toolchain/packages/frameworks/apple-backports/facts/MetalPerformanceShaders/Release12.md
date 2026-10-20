# The iOS 12 object of MetalPerformanceShaders

What this band carried, and what it measured and what it did not. Written on 2026-10-01, on branch
`band-SLICE-MetalPerformanceShaders-absent_MetalPerformanceShaders-12`, from `origin/main`
`580d7e435`.

## The slice and how it splits by MEASUREMENT, not by the row's `introduced`

The slice is 47 rows of `registry/MetalPerformanceShaders/absent_MetalPerformanceShaders.json`, and the
slice header calls the whole of it "release 12". The release a name can be PLACED in is not the
release the SDK dates it: `modules/apple/backports.lua:2298` reads it with
`dyld.first_releases(ladder(opt.architecture), ...)` over the HELD ladder, and the held set is dense
to 12.0 and then has no 13.0, 14.0 or 15.0.

`xmake l tools/cache-index/first-rung.lua` on all 47 names:

| rung | rows |
| --- | --- |
| 12.0 | 20 class rows, and the one method row's selector is not usable (below) |
| 16.0 | 26 class rows, every one of which the SDK dates 12.1 |

So one file cannot hold the slice. A 12.0-ladder name and a 16.0-ladder name in one object is
`misplaced()`'s refusal at `backports.lua:2426-2440` ("an object carries API that arrived in one
release, so split it") and `release-split.lua`'s `MIXED-RELEASES` independently. The 26 therefore
belong to the 16.0 object and this band wrote none of them; each of those rows now says so.

The 47 rows split, measured by the superclass chain in the SDK headers against the classes this
package already implements:

| outcome | rows |
| --- | --- |
| `implemented` | 8 |
| `absent`, superclass not carried by the port | 33 |
| `absent`, superclass carried, this band did not reach it | 6 |

## The superclass check, and why a missing ancestor is not a formality

A class whose superclass the library does not carry cannot be defined at all. The runtime fails to
create the class, the failure takes the WHOLE dylib with it, and one row's missing ancestor becomes
every row's load error. That is why 33 rows are `absent` and not `implemented` with a partial body:
there is no version of "implement it anyway" that is better than not writing it.

The chains, resolved from the 16.4 headers' own `@interface` lines and then checked against every
`@implementation` in `packages/a/apple-backports` on `580d7e435`:

| row | missing ancestor | whose row it is |
| --- | --- | --- |
| the 22 `MPSNNReduction*Node`, `MPSNNUnaryReductionNode`, `MPSNNReshapeNode`, `MPSNNPadNode`, `MPSNNComparisonNode` | `MPSNNFilterNode` | 11.0, this registry file, the release-11 object |
| `MPSNNReshapeGradientNode`, `MPSNNReductionSpatialMeanGradientNode`, `MPSNNPadGradientNode` | `MPSNNGradientFilterNode` -> `MPSNNFilterNode` | 11.0, same |
| `MPSNNReduceFeatureChannelsArgumentMin`, `...Max` | `MPSNNReduceUnary` | 11.3, this file |
| `MPSNNCompare` | `MPSCNNArithmetic` -> `MPSCNNBinaryKernel` | 11.0, this file |
| `MPSNNReshapeGradient`, `MPSNNPadGradient` | `MPSCNNGradientKernel` -> `MPSCNNBinaryKernel` | 11.0, this file |
| `MPSTriangleAccelerationStructure`, `MPSAccelerationStructure`, `MPSAccelerationStructureGroup`, `MPSInstanceAccelerationStructure`, `MPSRayIntersector` | `MPSPolygonAccelerationStructure` | 13.0, this file, the release-13 object |

The ray-intersection family is five rows and one block: `MPSTriangleAccelerationStructure` is the
only way to get geometry into an acceleration structure on this surface, so a structure with no
geometry and an intersector with nothing to trace would be four exported symbols no caller can
reach. The family is therefore carried or not at all, and this band carried none of it.

`MPSCNNYOLOLoss`, `MPSCNNYOLOLossDescriptor`, `MPSCNNNormalizationMeanAndVarianceState`,
`MPSRNNMatrixTrainingLayer`, `MPSRNNMatrixTrainingState`, `MPSNNPad` are the six rows whose
superclass the port DOES carry. They are `absent` because this band did not write them, and each row
says exactly that in its own words rather than claiming a blocker that does not exist.

## What was implemented

Two files, both release 12.0 by the measurement above, both built only from names the 16.4 headers
declare at `ios(12.0)`:

- `MPSNNOptimizers12.m` - `MPSNNOptimizerDescriptor`, `MPSNNOptimizer`,
  `MPSNNOptimizerStochasticGradientDescent`, `MPSNNOptimizerRMSProp`, `MPSNNOptimizerAdam`. The three
  update formulas are transcribed from `MPSNNOptimizers.h` line for line (`:250-268`, `:430-432`,
  `:436-438`), the gradient preprocessing is the header's own order at `:61-66` with the L1 and L2
  regularization gradients at `:33-41`, and every default is the number in the property's own doc.
- `MPSNNResize12.m` - `MPSNNResizeBilinear` and `MPSNNCropAndResizeBilinear`. The two sampling
  conventions are `alignCorners`'s own two sentences, and the regions are read as the header declares
  them: a `const MPSRegion *` of `{ MPSOrigin; MPSSize; }` doubles, normalised.
- `MPSMatrixCopyToImage12.m` - `MPSMatrixCopyToImage`, with the placement decided by `dataLayout` as
  `MPSImageCopy.h` declares the two layouts.

### What was NOT measured, stated plainly

**No build, no test program, no gate and no device ran in this band.** The shared `~/.xmake` store
was under repair and this band was forbidden to touch it, so nothing here has been compiled, linked
or compared with a result. Every rule above is transcribed from a header; not one number in it is a
measurement of Apple's code or of this port's. `tools/release-split.lua` was likewise not run: it
requires a folder of already-compiled `*.o` (`release-split.lua:150-151`, and its own header says so),
so its verdict is unknown to this band and has to be produced by whoever compiles next.

### Two things the first draft of these files got wrong, and the header that caught them

Both were caught by reading the SDK headers rather than by running anything, and both would have been
silently wrong:

- `MPSNNCropAndResizeBilinear`'s regions were first written as an `NSArray` of `NSValue`-held
  `CGRect`. `MPSNNResize.h:110` declares them as `@property (readonly, nonatomic, nonnull) const
  MPSRegion *regions` - a pointer to a C array of structs with double components
  (`MPSCoreTypes.h:321-338`, `:355-359`), normalised, not pixel rectangles in objects.
- `MPSNNResizeBilinear` and `MPSNNCropAndResizeBilinear` were first written against
  `MPSUnaryImageKernel`. `MPSNNResize.h:30` and `:99` derive both from `MPSCNNKernel`, and mark
  `-initWithDevice:` `NS_UNAVAILABLE` on each.

### A third, found by hand rather than by a header

The bilinear blend was first written as two successive blends - along x, then along y - which is what
a separable implementation does and is NOT what a single bilinear sample is. The intermediate
`at_y`-blended corners do not exist at the half-pixel position the second pass needs. It is one blend
of the four corners of the destination pixel's cell, weighted along both axes at once, and the code
says so where it is written.

## The selector row, and the rulebook's trap about selectors

`-[MPSCNNConvolutionDataSource copyWithZone:device:]` is `absent`, and the evidence is deliberately
NOT `first-rung.lua`. That tool answers `9.0` for the bare selector, which is `NSObject`'s own
`copyWithZone:` and says nothing about this owner. What the row rests on instead is that no object in
`packages/a/apple-backports` defines `MPSCNNConvolutionDataSource` at all - a grep finds only this
registry file's own rows for it - so there is no `@implementation` that could carry the method.

## The rows this band deliberately did not touch

`MPSRNNDescriptor`, `MPSRNNRecurrentMatrixState`, `MPSCNNLoss`, `MPSCNNLossDescriptor`,
`MPSNNReduceUnary`, `MPSCNNBinaryKernel`, `MPSCNNArithmetic`, `MPSCNNGradientKernel`,
`MPSNNFilterNode`, `MPSNNGradientFilterNode` and `MPSPolygonAccelerationStructure` are named in the
rows above as the missing ancestors. Every one of them is a row in this same file or in
`registry/MetalPerformanceShaders/`, and NONE of them is one of the 47 rows this slice was given, so
none of them was edited. This band read them and wrote about them; it did not move their status.

## The three classes of this release whose superclass the port already carries

`packages/a/apple-backports/MetalPerformanceShaders/MPSNNStates12.m` and `MPSNNPad16.m`, added on
2026-10-03 from the work `band-wmtl-mps12` left behind. The three rows said on main, and still said when this section was written,
"this band did not write it" and "the band's time ran out first", with the superclass named as NOT the
blocker - MPSCNNKernel for MPSNNPad, MPSState for the two states, MPSKernel for MPSRNNMatrixTrainingLayer,
all three carried. That is a queue entry and not a reason, and the classes were already written.

| class | annotation | object | what it answers |
| --- | --- | --- | --- |
| MPSNNPad | MPSNNReshape.h:225, ios(12.1) | MPSNNPad16.m | the two padding coordinates, the scalar and the per-channel fill, and the pad itself |
| MPSCNNNormalizationMeanAndVarianceState | ios(12.0) | MPSNNStates12.m | mean, variance, the initializer that takes them and the class method that allocates them |
| MPSRNNMatrixTrainingState | ios(12.0) | MPSNNStates12.m | the class; MPSState's initializers, resource list and encode |

### What was measured, and with which commands

**The armv7 build of this directory, all 74 of its objects.** The band that wrote the file never linked it
for armv7, which is the defect that kept it out; this is that check, and the commands are:

```
CLANG=~/.xmake/packages/l/llvm/23.1.1/*/bin/clang ; SDK=<the 16.4 iPhoneOS SDK>
for f in packages/a/apple-backports/MetalPerformanceShaders/*.m ; do
  "$CLANG" -c -fobjc-arc -fvisibility=hidden -target armv7-apple-ios6.0 -isysroot "$SDK" \
      -Wno-unguarded-availability-new -Wno-deprecated-declarations \
      -I packages/a/apple-backports -I packages/a/apple-backports/MetalPerformanceShaders \
      -I packages/a/apple-backports/Metal -I packages/a/apple-backports/CoreML -I includes "$f" -o "${f%.m}.o"
done
ld -r -o all.o -undefined dynamic_lookup *.o
```

**74 objects, 0 compile failures, and `ld -r -undefined dynamic_lookup` exits 0 with an empty log.** The check that matters is the
second one and it is this: a partial link over the directory resolves every Objective-C class the objects
NAME, and `nm -u all.o` leaves exactly ten `_OBJC_*` symbols open -

    _OBJC_CLASS_$_MTLTextureDescriptor   _OBJC_CLASS_$_NSArray        _OBJC_CLASS_$_NSMutableArray
    _OBJC_CLASS_$_NSMutableData         _OBJC_CLASS_$_NSNull         _OBJC_CLASS_$_NSNumber
    _OBJC_CLASS_$_NSObject              _OBJC_CLASS_$_NSString       _OBJC_CLASS_$_NSValue
    _OBJC_METACLASS_$_NSObject

- every one of them a class of Foundation or Metal, and not one of them a class of MPS. That is the
failure this page's neighbour is about: a class that reads a property of a class the library does not
carry cannot be created at all, the runtime fails to make it and the failure takes the whole dylib with
it. The two new objects answer their own classes and nothing else:

    $ nm -gU MPSNNPad16.o MPSNNStates12.o | grep _OBJC_
    000014e8 S _OBJC_CLASS_$_MPSNNPad
    000014fc S _OBJC_METACLASS_$_MPSNNPad
    0000061c S _OBJC_CLASS_$_MPSCNNNormalizationMeanAndVarianceState
    00000630 S _OBJC_METACLASS_$_MPSCNNNormalizationMeanAndVarianceState
    00000644 S _OBJC_METACLASS_$_MPSRNNMatrixTrainingState
    00000658 S _OBJC_CLASS_$_MPSRNNMatrixTrainingState

**What this is NOT.** `ld -r` is a PARTIAL link over one directory. It is not a dylib link, it resolves no
framework symbol, and it is not the gate: `gate-parallel.sh` and `tools/release-split.lua` were not run,
because one stack at a time is the coordinator's. A reader who wants the release placement of the three
classes is answered by `introduced` on their rows and by that same tool.

**No differential against Apple's code.** The release's own MPS cannot run on this host, which `Image9.md`
records with the selector and the text of the log. No host case and no device run either. Every number
above is a count of symbols and objects from commands in this page.

### WHY MPSNNPad IS IN A FILE OF ITS OWN

The three classes arrived as one file, and one file cannot hold them. The release an object is placed by is
the HELD ladder, not the header's clause, because the release the port deploys on has to be one a
release's own export answers for, and no release is held between 12.0 and 16.0:

    $ printf 'MPSNNPad\nMPSCNNNormalizationMeanAndVarianceState\nMPSRNNMatrixTrainingState\n' \
        | xmake l tools/cache-index/first-rung.lua
    MPSNNPad                                 16.0
    MPSCNNNormalizationMeanAndVarianceState 12.0
    MPSRNNMatrixTrainingState                12.0

MPSNNPad's own row said this before either file existed - "a name the SDK dates 12.1 reads 16.0 on the ladder
and its object belongs to the 16.0 band rather than to a 12.0 one", with the command beside it - and one file
holding MPSNNPad beside the two 12.0 states would be a file with two band points, which `misplaced()` in
`backports.lua` refuses and `tools/release-split.lua` reports as `MIXED-RELEASES`. So MPSNNPad is
`MPSNNPad16.m` and the two states are `MPSNNStates12.m`. The row keeps `introduced: 12.1`, which is the
header's own date; the placement is the file's business and each file's header says which ladder rung put it
there.

### Two things the object deliberately does not do

**MPSNNPad does not answer `-destinationImageDescriptorForSourceImages:sourceStates:`.** That is the method
its own paddingSizeBefore property exists for (MPSNNReshape.h:230-232: "This property is used for
automatically sizing the destination image for the function destinationImageDescriptorForSourceImages:
sourceStates:"). The method itself is MPSCNNKernel's and belongs to the graph layer - the release-11
object, which is another slice's - so this object carries the padding and the fill and leaves the sizing
to whoever carries the graph.

**MPSCNNNormalizationMeanAndVarianceState allocates the two buffers and does not fill them.** What fills a
mean and a variance is the batch normalization gradient, which is ios(11.3) and is another slice's object.
The class method here answers what the header says it answers - a state holding two buffers of
numberOfFeatureChannels floats - and the row says which object would put numbers in them.

### Two behaviours that are the header's own wording, both in MPSNNPad

1. **A destination that is not the source plus the pad on each side is refused by name**, rather than padded
   as far as it goes. The header's two properties describe the destination's shape; a caller that gave a
   different one has not asked for this pad.
2. **The fill array's index is the DESTINATION channel**, because MPSNNReshape.h:283-284 says "The first
   value of the array will correspond to the first feature channel written out to the destination image". An
   array shorter than the destination's channel count is refused, because :286-287 calls that undefined
   behavior and refusing is what this port does with it.

### The three rows of this slice that are still absent, and the one command that keeps them out

MPSCNNYOLOLoss, MPSCNNYOLOSLossDescriptor and MPSRNNMatrixTrainingLayer each declare a property whose TYPE
is a class this package does not build, which is the whole library's load and not this file's:

    $ grep -rn '@implementation MPSCNNLoss\b\|@implementation MPSCNNLossDescriptor\b\|@implementation MPSRNNDescriptor\b' \
          packages/a/apple-backports/MetalPerformanceShaders/
    (nothing)

The control in the same run: `@implementation MPSState` answers MPSState11.m and `@implementation
MPSCNNKernel` answers MPSCNNKernel10.m, so the three zeros are the package's and not the reader's. Their
rows on main already name those three ancestors, and this object did not touch them.

### The one initializer chain that changed, and why no pragma is carried for it

MPSNNReshape.h marks `-initWithDevice:paddingSizeBefore:paddingSizeAfter:fillValueArray:` the designated
initializer of MPSNNPad (:290-297), which makes `-initWithDevice:` a SECONDARY initializer of the same
class. The file as it was left chained that one to `[super initWithDevice:]` and silenced the warning with
`#pragma clang diagnostic ignored "-Wobjc-designated-initializers"`. It now reaches MPSCNNKernel's
initializer THROUGH its own designated one, the way the two-argument form beside it already did:

    - (instancetype)initWithDevice:(id<MTLDevice>)device
    {
        return [self initWithDevice:device
                 paddingSizeBefore:(MPSImageCoordinate){0, 0, 0}
                  paddingSizeAfter:(MPSImageCoordinate){0, 0, 0}
                     fillValueArray:nil];
    }

The object this leaves is the one the direct chain built - MPSCNNKernel's initializer plus the header's
three defaults, a pad of nothing on either side and a fill of 0.0f (:260) - and with the chain fixed the
file compiles with `-Wall` and **no pragma at all**, which the command above shows. The two pragmas it was
written with, `-Wprotocol` and `-Wincomplete-implementation`, are not needed either and are gone: MPSCNNKernel
and MPSState are concrete in this package, so every method those two warnings ask about has a body. All
three were carried only by the file that was never built; no other object of this directory needed them for
this reason.

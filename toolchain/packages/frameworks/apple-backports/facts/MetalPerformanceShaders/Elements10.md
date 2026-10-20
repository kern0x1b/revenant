# The elements iOS 10 added: neuron filters, the two softmaxes, three normalisations, the Laplacian, and a temporary image

Every number on this page is a measurement of **the host's own Metal Performance Shaders**, not a
reading of a header and not a comparison against a reference this port wrote. The harness is
`tests/backports/host/mpscnn10/run.sh`, it runs each case twice — once against the system's MPS and once
against this port's classes renamed under names of their own — and the two transcripts are compared.
Measured 2026-10-01 on Apple M4 Pro, macOS 27.0.

## The oracle exists here, and these bands did not use it

Nine rows of this slice carried this sentence:

> host MPS cannot run here: this host's AGX family lacks `computeCommandEncoderWithDispatchType:` and
> the release's own kernel dies encoding with
> `-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]: unrecognized selector`.

**That is false on this machine, and it is retracted.** Measured: all twenty of the slice's classes
resolve in the system's own `MetalPerformanceShaders`, and `MPSCNNNeuronReLU` encodes and writes — a
3x3 image of 1..9 comes back unchanged, which is what a ReLU with `a = 0` does over positive values.

The distinction matters because the sentence was doing real work in the rows. "Compared against a plain
C reference written from this header's own wording… No number on this row is a measurement of Apple's
code" is a much weaker claim than "measured against the release", and it is the claim these rows made.
The oracle was available and unused. Four of the rules on this page are in a form **the header does not
give**, and each was found by measuring the release rather than by reading it.

## What the release answers, and what it does not

The harness reports:

```
cases: 17, tolerance 0.0001 absolute or relative
closest to the tolerance, as a fraction of it:
  local-contrast-alpha1        0.00179
  neuron-tanh-a3-b0.5          0.000866
  neuron-sigmoid               0.0006
  cnn-softmax-4ch              0.0006
  cnn-logsoftmax               0.0006
differing cases: 0
```

**Tolerance, written down before the numbers were compared.** A normalisation and an exponential
accumulate in a different order on a GPU than on a CPU, so the two are not expected to agree to the bit.
A case passes when every element differs by no more than `1e-4`, absolute or relative, whichever is
larger. The largest distance any case came to is **0.0018 of that bound** — `local-contrast-alpha1`, at
`2.4e-7` absolute.

**The mutation campaign, and why it is in this page.** "The case is green" says nothing about whether the
case can be red. Four mutations, one per rule this band measured, each into a scratch copy so no tracked
file is written, each re-copying the pristine sources rather than restoring from git:

| mutation | what it breaks | caught by |
| --- | --- | --- |
| the window reaches back instead of being centred | the spatial normalisation's window rule | `differing cases: 3` |
| `p0` defaulted to 0 | the local contrast normalisation's `p0` | the **defaults** check, which exits before a case count |
| the divisor is the channel count, not the kernelSize | the cross-channel normalisation's divisor | `differing cases: 2` |
| both softmaxes take the logarithmic branch | `MPSCNNSoftMax` stops being a softmax | `differing cases: 2` |

The `p0` mutation is caught by the property-line comparison rather than by any case, which is why that
comparison is text: the numbers are unchanged and only the declared default is wrong. The window mutation
was **not** caught until `spatial-norm-k3` existed — which is the correction above, found by the campaign
rather than by reading.

**The fresh-kernel property lines are compared as text, not with a tolerance.** Ten lines, and they
agree exactly:

```
relu-defaults a=0 b=0 c=0
spatial-defaults alpha=1 beta=5 delta=1 kw=3 kh=3
localcontrast-defaults alpha=0 beta=0.5 delta=0.000976562 p0=1 pm=0 ps=1
crosschannel-defaults alpha=1 beta=5 delta=1 kernelSize=3
```

That is stricter on purpose. A different default is a different kernel, not a rounding, and a tolerance
would have hidden it — which it did, once: see below.

## A claim this page made, and withdrew

**This page first said the spatial normalisation's window of an EVEN kernel reaches BACK**, on the strength
of a `kw = 2` measurement whose sixteen implied values all reproduced. **That was wrong, and the case
could not have shown it.**

For a 2-wide kernel a centred window starts at `-(2/2) = -1` and a backward one at `-2+1 = -1`. **Those are
the same two pixels.** Every one of the sixteen implied `N2` values was consistent with both rules, so
the case distinguished nothing — and a run where a mutation went undetected is exactly how that happened:
the mutation campaign's first version changed the window rule and the harness stayed **green**, because
the one case that existed for the rule was the one case that could not see it.

Re-measured where the two rules actually differ, `kw = 3` (centred starts at `-1`, backward at `-2`):

| rule | max relative difference from the host, `kw = 3` |
| --- | ---: |
| centred | **3.0e-06** |
| backward | **7.7e+04** |

So the release uses a **centred** window, which is what `MPSCNNNormalization.h:60-62` itself says
(`L(i) = [i-floor((kw-1)/2), i+floor(kw/2]`, a `kw x kw` block centred on the output). The `back` flag is
gone from the object rather than left as a second answer for a later author to choose between, and the
harness now carries `spatial-norm-k3` and `spatial-norm-k5` — widths where the rules differ by one and by
four pixels.

`spatial-norm-k2` is kept, for its defaults, and its comment now says in as many words that it cannot pin
the window. **A case that cannot fail is not evidence, and a measurement that cannot discriminate is not a
measurement.**

## Three rules the header does not give, or gives in a form the release does not use

### The spatial normalisation's window is centred, and the header does not say so

`MPSCNNNormalization.h` gives **no window at all** for `MPSCNNSpatialNormalization`; the nearest thing is the
gradient's own formula at `:60-62`, which as a block is centred. That it is centred is now **measured** at
`kw = 3` and `kw = 5` rather than read off the header — see the table above and the case list below.

### The local contrast normalisation's `p0` default is load-bearing

`MPSCNNNormalization.h:151-153` says `p0` defaults to `1.0`. The measurement confirms it, and shows what
a wrong value costs. At `alpha = 0` the denominator is the constant `delta^beta`, so the release's answer
*solves* the mean:

```
M = X - Y * delta^beta
```

At `(0,0)` that gives `M = 1.55555558` against the centred 3x3 mean `1.55555556`. With `p0 = 0` the
object answers **32** where the release answers **-17.7777786**.

Every default was read off a fresh kernel and agrees with `:151-178` to the digit: `alpha 0`, `beta
0.5`, `delta 0.000976562`, `p0 1`, `pm 0`, `ps 1`. The header is explicit that `alpha = 0` is "not
recommended and is preserved for backwards compatibility" and performs "a local mean subtraction",
which is what the measured top case is.

### The cross-channel normalisation's divisor is the kernelSize, and its window is asymmetric

`:381-387` says `alpha/N` where "N is the kernel size", over
`Q(k) = [max(0, k-floor(N/2)), min(D-1, k+floor((N-1)/2))]`. Measured with `kernelSize = 3`, the
divisor implied by the release's answer is **3.000000** at every output checked — so it is the
kernelSize and not the window's length, which would be 3, 3, 2 for three channels.

`Q(k)` is **asymmetric**: for `N = 3` it is `[k-1, k+1]`, so with four channels the first channel sees
three and the last sees two. Symmetrising the window would change the edge channels' answers, and the
harness compares them.

### Softmax is across FEATURE CHANNELS, not across pixels

`MPSCNNSoftMax.h:34-37` says "applied across feature channels and in a convolutional manner at all
spatial locations"; `:101-104` gives the logarithmic form over the same channel index. Measured on a
4x4 of two channels whose values differ at each pixel, the release answers **the same pair at every
pixel**:

```
0.268941432  0.731058598
```

which is `sigmoid(1-2)` — the two channels *at that pixel*. A softmax over the sixteen pixels of a row
would answer sixteen different numbers. One channel answers 1, dividing by itself.

## The Laplacian, measured value by value

Over a 4x4 of 1..16 with the edge mode left at its default, the release answers:

```
 3   2   1  -5
-4   0   0  -9
-8   0   0 -13
-29 -18 -19 -37
```

and with `-bias` set to 1, **every one of those is exactly one larger**. That settles the order of
`MPSImageConvolution.h:62-72` — "a value to be added to convolved pixel before it is converted back to
the storage format" — by measurement rather than by reading: sum, then bias, then store.

The off-image value is **zero**, not the nearest value. A clamped border would answer `2` at `(0,0)`
rather than `3`, because the clamped left and top neighbours would both be the corner's own value.

The header says at `:109-116` that this class is "an optimized variant of the MPSImageConvolution
filter" reachable by building an `MPSCNNConvolution` with the same weights, so the walk is
`MPSImageConvolution13.m`'s and this object holds only the bias.

## The pyramid base is an ALIAS from 10.0.1, and what that costs the Laplacian kernels

Measured 2026-10-04 with `apple.objc.inventory` and `apple.dyld` over the caches this package is built
for, one class and one export table at a time:

| release | `MPSImagePyramid` in MPS's `__objc_classlist` | `_OBJC_CLASS_$_MPSImagePyramid` |
| --- | --- | --- |
| 6.1.3 - 10.0 (armv7) | absent | absent |
| 10.0.1, 10.1, 10.2, 10.3, 10.3.4 (armv7s) | present: superclass `MPSUnaryImageKernel`, **seven own methods** - `-initWithDevice:`, `-initWithDevice:centerWeight:`, `-initWithDevice:kernelWidth:kernelHeight:weights:`, `-kernelWidth`, `-kernelHeight`, `-dealloc`, `-copyWithZone:device:` | **no image exports it**, nor its metaclass |
| 11.0 (arm64) | present in `MPSImage.framework/MPSImage`, 9 own methods | **no image exports it** |
| 16.0 | present | exported, with its metaclass |

That is the whole of the window: the release carries the class for four releases and exports it for
none, so a band of 10.0.1 to 10.3.4 that linked the class implementation held two classes of one name
in every process and the runtime kept the one it registered first. The name therefore goes through
`revenant_alias.h` - what `modules/apple/backports.lua`'s own `check_categories` asks for when it reads
this reading, and what `MDLMeshBufferZoneDefault`, `HKCDADocument`, `NSTextList` and `NSTextTab`
already are. `MPSUnaryImageKernel` is the superclass the alias is declared with, and that one *is*
exported from 10.0.1 (measured, `apple.dyld` over the armv7s caches of 10.0.1 and 10.3.4), so the
proxy's chain is the release's own `MPSUnaryImageKernel` on those bands and the port's below 10.0.1.

**What it costs, and why the Laplacian kernels refuse on those four bands.** `attach.c`'s
`revenant_adopt_methods` replaces the proxy's own copy of every member the release's class already has,
and the list above is all five members of this class. So on 10.0.1 to 10.3.4:

- a pyramid a program builds through our `MPSImageLaplacianPyramid` gets the **release's**
  initializers, because the port's class inherits them and the inherited copies are the release's;
- the filter's weights are then in the release's own private storage - `MPSImageConvolution.h` declares
  `kernelWidth` and `kernelHeight` and keeps the weights themselves private - and no header declares
  them, so this port cannot read them, by any public mechanism;
- `MPSImageLaplacianPyramidSubtract` and `MPSImageLaplacianPyramidAdd` read the weights through
  `-revenant_mps_filter`, which answers NULL there, and they **refuse by name** rather than interpolate
  with a filter this port never wrote. Their rows and MPSImagePyramid's row say so.

Below 10.0.1 nothing of this happens: the release has no class of the name, the proxy IS the class,
`attach.c`'s constructor skips the alias entirely (`objc_getClass` answers nil), and every member
answers out of the associated object the filter's weights live in. From 12.0 the release exports the
Laplacian classes themselves and `band()` reexports that object, so the port's kernels are not in such
a band at all; at 16.0 the release exports `MPSImagePyramid` and the band links neither this object nor
the proxy. **No band of this machine reaches 16.0** (the armv7 ladder ends at 9.3.6 and armv7s at
10.3.4), which is why the last two sentences are measurements of the ladder rather than of a link.

`MPSImagePyramid10.m`'s Gaussian kernel is **not** in the four bands: the release exports
`_OBJC_CLASS_$_MPSImageGaussianPyramid` from 10.0.1, and `band()` reexports that object there (measured
at 10.0.1 and 10.3.4), so its inherited initializers are the proxy's own and its weights are the port's.

**Not measured**: nothing here was run on a device. What a release-made pyramid answers for
`-kernelWidth` and `-kernelHeight` is the release's own reading of its own storage, which is the
truthful answer there; what this port cannot do on those four bands is read the weights, and that is
the refusal above.

## The image side, in its own harness

`tests/backports/host/mpsimage10/run.sh` is the harness for the image classes of this slice, and the
laplacian's row names it. It runs the same two-transcript comparison:

```
defaults: 1 line(s) compared, agree exactly as text
  laplacian bias=0 edgeMode=0
cases: 3 compared, 1 expected absent, tolerance 0.0001 absolute or relative
closest to the tolerance, as a fraction of it:
  laplacian-bias1              0
  laplacian-bias0              0
  fresh-image-zeroes           0
differing cases: 0
```

**Zero, exactly.** The laplacian agrees with the release bit for bit in both bias settings — a sum of
small integers and one subtraction produces no rounding to disagree about, which is why the convolutional
harness needs a tolerance at all (an exponential does) and this one does not.

**One case is EXPECTED ABSENT and the run is green anyway.** `conversion-null-info` builds an
`MPSImageConversion` with a NULL `conversionInfo` and the port refuses it by name, because the class is
not carried — the row's claim, restated by the run. The harness checks the difference against the set of
cases the port says it does not carry, so an expected absence is reported and a case that goes missing for
any other reason is still red. The **system** side of that case is the measurement the row rests on: the
release's own `MPSImageConversion` answers a NULL `conversionInfo` by returning the same four values it
was given, which is a no-op, and a class whose one job is a conversion that answers a copy is not that
class. It cannot be a shared **C** function:
`RevenantMPSConvolveRegion` is `static` in that file, and `toolchain/AGENTS.md` records that a C function
called across objects is `Undefined symbols` in the bands where the exporting file is not carried,
because an object is placed by the release whose API it defines. So one **method** on `MPSUnaryImageKernel`
is what crosses, and it is what this commit adds.

## What the harness caught

**A default that was wrong, and that no number would have caught.** The port's `MPSCNNNeuronReLU`
answered `c = 1`; the release answers `c = 0`. ReLU's formula does not use `c`, so **every case's
numbers were identical either way** and a tolerance comparison passed. A caller reading `-c` on a ReLU
would have read 1 where the release reads 0. The property lines are compared as text for exactly this.

**The shared plane is the wrong layout for this port's `MPSImage`.** `RevenantMPSCnn.h`'s plane addresses
channel `c` at row `channel*height` with a stride of `width` times one element, which is **planar**.
This port's `MPSImage13.m:50-72` makes `MTLPixelFormatR32Float` / `RG32Float` / `RGBA32Float`, and
`MPSImageWalk13.m:65` states the consequence:

> There is no planar format in that surface, so the addressing is always interleaved.

So every case that **crosses** channels read half a row per step, the texture asserted
`bytes_per_row >= used_bytes_per_row` **eight times**, and all five channel-crossing cases answered
zeros. **Every single-channel case was green throughout** — which is why only the channel-crossing cases
found it, and why it would have been invisible in the sibling `mpscnn` harness where every case is one
channel. This object therefore walks through the four helpers the image family already shares
(`RevenantMPSImageReadRegion`, `RevenantMPSImageLoad`, `RevenantMPSImageWriteRegion`).

The shared header is **not** changed here: `MPSCNNPooling10.m` and `MPSCNNBatchNormalization12.m` use its
plane, those bands own those objects, and a defect in a shared header is fixed by the band that owns it.

**`MPSImage` has no Metal format for three feature channels.** `MPSImage13.m:49-71` returns
`MTLPixelFormatInvalid` for any count but 1, 2 and 4, and the port run printed the refusal:

```
MPSImage: channel format 4 with 3 feature channels has no Metal pixel format, so no texture was made
```

So the channel-crossing cases use **four** channels, which the port carries, and the harness prints the
channel count so a reader can see it. That limit is `MPSImage`'s and not any kernel's.

**Two harness defects, recorded because a differential cannot catch its own errors.** The transcript
labels each value line `  ch<k> row<k> v v v`, and the first parser read the two labels as numbers and
aborted with `could not convert string to float: 'ch0'`. And a `<name> <count>` line opens a case while a
`<name> kernelSize=1` line is a measurement, so the rule that distinguishes them is the shape — the
second field is a bare count — not the spelling.

## What is not carried, and the measurement that decides each

Nothing here is decided dead. Each is blocked on a named substrate.

**Two of the entries below have since been carried, and the split they asked for is what they asked for.**
`MPSImagePyramid` and `MPSImageGaussianPyramid` are in `MPSImagePyramid10.m` and the three Laplacian
pyramid classes are in `MPSImageLaplacianPyramid12.m` — two objects, because the release's own cache
ladder exports the Gaussian from `10.0.1` and the Laplacian classes from `12.0`, and an object carries
one release. That is the second entry's own conclusion, acted on. The measurements are left exactly as
written, because they are what the two objects rest on: the ladder exports the Laplacian classes from
12.0, and the release's own kernel still crashes on this family's encode, so no number in either object
is a measurement of Apple's code.

**A third object was needed, and the measurement that forced it is the export trie, not the name.**
`MPSImagePyramid` itself is annotated `ios(10.0)` (`MPSImageConvolution.h:519`) and
`first-rung.lua` answers `10.0.1` for `_OBJC_CLASS_$_MPSImagePyramid` — both true, and `first-rung`
answers whether a rung *carries* a name, which this one does from `10.0.1` because
`MPSImageGaussianPyramid`'s `super_class` points at it. What an object is *placed* by is what a client
can bind, and `tools/release-split.lua` measures that: over the same held ladder it answers **16.0**.
Walking the export tries confirms it — `10.0.1` and `11.0` export `MPSImageGaussianPyramid` and no
`MPSImagePyramid`; `12.0` adds the three Laplacian classes and still none; `16.0` adds
`_OBJC_CLASS_$_MPSImagePyramid`. So `MPSImagePyramid` is `MPSImagePyramid16.m`, and sharing one `.m`
with the Gaussian is what `band()` refuses with *"an object carries API that arrived in one release, so
split it"*.


**`MPSImagePyramid`, `MPSImageGaussianPyramid` — a missing substrate, measured on both sides.** Both
classes resolve and hold their parameters (`kernelWidth 5`, `kernelHeight 5` by default; 3x3 from the
custom initialiser). What is missing is a substrate that answers the **encode**: the pyramid is
"enqueued as a in-place operation" that "fills all mipmap levels after level=1"
(`MPSImageConvolution.h:513-520`), and running it against **the host's own MPS** on an 8x8 R32Float
texture with four mip levels takes the process down with **SIGSEGV, exit 139**. From this side the same
gap is `MPSImage13.m:253`, which makes every texture `mipmapped:NO` — there are no mip levels for such a
fill to write into.

**`MPSImageLaplacianPyramid`, `+Add`, `+Subtract` — not 10.0 at all.** The header annotates all three
`ios(10.0)` (`:663`, `:706`, `:683`) and `sdk-26.2-surface.tsv` carries 10.0 for them, so the registry's
`introduced` is what the SDK declares. But the **release's own cache ladder** answers **12.0**:

```
$ printf '%s\n' _OBJC_CLASS_$_MPSImageLaplacianPyramid _OBJC_CLASS_$_MPSImageLaplacianPyramidAdd \
      _OBJC_CLASS_$_MPSImageLaplacianPyramidSubtract | xmake l tools/cache-index/first-rung.lua
_OBJC_CLASS_$_MPSImageLaplacianPyramid	12.0
_OBJC_CLASS_$_MPSImageLaplacianPyramidAdd	12.0
_OBJC_CLASS_$_MPSImageLaplacianPyramidSubtract	12.0
```

where the same command answers **10.0.1** for the thirteen classes of this slice that *are* 10.0, and
`--rungs MPSImageLaplacianPyramid` answers `12.0,16.0,18.0` — so no release between 10.0.1 and 12.0
carries it. Carrying them here would put two releases' symbols in one `.m`, the condition
`tools/release-split.lua` exists to refuse. They are 12.0 work.

**`MPSImageConversion` — a missing converter.** Its designated initialiser takes a
`CGColorConversionInfoRef` (`:60-64`) and that CoreGraphics family is absent from this port
(`registry/CoreGraphics/absent_CoreGraphics.json`, five rows). Measured on the host, a NULL
`conversionInfo` with `AlphaIsOne` both sides is a **no-op** — a 2x2 of 1,2,3,4 comes back unchanged — and
a class whose one job is a conversion that answers a copy is not that class.

**`MPSCNNFullyConnected` — a missing data source, and placement is *not* it.** Its superclass
`MPSCNNConvolution` **is** carried. The weights arrive through `id<MPSCNNConvolutionDataSource>`
(`:1367-1371`), a protocol whose rows are 11.3 and whose `-copyWithZone:device:` and `-weightsLayout`
`Owed.md` lists against no header at all. Measured on the host: the class's twelve own methods are every
initialiser and **no encode** — it inherits the one `MPSCNNConvolution10.m` already answers. The walk is
available; the weights are not.

**`MPSCNNNeuron` — here, and refusing to be built.** `:195` marks `-initWithDevice:` `NS_UNAVAILABLE`
and its only designated initialiser takes an `MPSNNNeuronDescriptor`, which is 11.3. At 10.0 the base has
no way in of its own, so it says so by name rather than becoming something a caller can build that it is
not. Its three declared properties answer; `-neuronType` and `-data` are 11.0 and are **not** carried.
`MPSImageGaussianBlur`'s row in the same file is the same shape of thing.

## Read from

- SDK: `$HOME/.xmake/packages/i/iphoneos-sdk/16.4/6d132ebd18c74ce6b109854a65d49554` (iPhoneOS 16.4)
- Harness: `tests/backports/host/mpscnn10/run.sh`, cases in `cases.m`
- Objects: `packages/frameworks/apple-backports/MetalPerformanceShaders/MPSCNNElements10.m`,
  `MPSImageElements10.m`; the shared walk seam in `MPSImageConvolution13.m`
- Ladder: `xmake l tools/cache-index/first-rung.lua` over the held armv7/arm64 caches

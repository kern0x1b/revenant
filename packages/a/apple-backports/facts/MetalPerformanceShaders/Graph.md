# The graph layer: MPSNNGraph and the nodes it walks

`MPSNNGraph`, `MPSNNImageNode`, `MPSNNStateNode`, `MPSNNFilterNode`, `MPSNNDefaultPadding`,
`MPSNNBinaryArithmeticNode`, `MPSNNAdditionNode`, `MPSNNSubtractionNode`, `MPSNNMultiplicationNode`,
`MPSNNDivisionNode`, `MPSNNConcatenationNode`, `MPSCNNPoolingNode`, `MPSCNNPoolingAverageNode` and
`MPSCNNPoolingMaxNode` — fourteen classes, all of them in the iOS 11.0 inventory of the release, in
**three objects** and not one:

| object | release | classes |
| --- | --- | --- |
| `MPSNNGraph11.m` | 11.0 | `MPSNNGraph` `MPSNNImageNode` `MPSNNDefaultPadding` `MPSNNAdditionNode` `MPSNNSubtractionNode` `MPSNNMultiplicationNode` `MPSNNDivisionNode` `MPSNNConcatenationNode` `MPSCNNPoolingAverageNode` `MPSCNNPoolingMaxNode` |
| `MPSNNFilterNode12.m` | 12.0 | `MPSNNFilterNode` |
| `MPSNNGraphNodes16.m` | 16.0 | `MPSNNStateNode` `MPSNNBinaryArithmeticNode` `MPSCNNPoolingNode` |

There is also one category on `MPSImage`, which holds no API of its own, and one shared header,
`CharonMPSNN.h`, which holds no API either.

## Why three objects and not one, which is the whole of the second half of this work

**The release a name arrived in is not the release the gate places it at, and the difference is whether a
client can link against it.** All fourteen classes are in the 11.0 release's ObjC inventory — `objc.inventory`
over `~/.charon/dyld/11.0/dyld_shared_cache_arm64`, 52768 classes, answers PRESENT for every one, each with
its true superclass. What four of them are *not*, at 11.0, is in any image's **export trie**:

| class | 11.0 inventory | 11.0 trie | 12.0 trie | 16.0 trie | placed at |
| --- | --- | --- | --- | --- | --- |
| `MPSNNGraph` | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSNNImageNode` | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSNNDefaultPadding` | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSNNAdditionNode` and its three siblings | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSNNConcatenationNode` | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSCNNPoolingAverageNode`, `MPSCNNPoolingMaxNode` | PRESENT | `MPSNeuralNetwork` | — | — | 11.0 |
| `MPSNNFilterNode` | PRESENT | **no image** | exported | — | **12.0** |
| `MPSNNStateNode` | PRESENT | **no image** | **no image** | exported | **16.0** |
| `MPSNNBinaryArithmeticNode` | PRESENT | **no image** | **no image** | exported | **16.0** |
| `MPSCNNPoolingNode` | PRESENT | **no image** | **no image** | exported | **16.0** |
| `MPSNNGradientFilterNode` (not carried) | **ABSENT** | — | — | — | 12.0 |

`backports.lua`'s `measured_names()` reads exactly that trie — `measured_introduced` is
`dyld.first_releases`, which walks the held ladder calling `dyld.exported_at` (dyld.lua:859) — and the
registry is consulted **only as a last resort**, and only for a row whose status is `implemented`. So the
rows saying `introduced 11.0` never got a say, and `misplaced()` refused the single object.

**`first-rung.lua` answers a different question and is right about the classes.** It reads
`~/.charon/cache-index/<release>.names.gz`, which `tools/cache-index/build.py:8` writes with
`strings -a <cache> | grep -xF NAME` — every string in the cache, in any image, in any section. So it finds
a class that is *in* the cache and *not exported from* it, and answers 11.0 for all fourteen. That is a
correct answer to "when did the class arrive" and not the answer `misplaced()` needs, which is "from which
release can a port that defines this name be linked".

**The placement is the EARLIEST of the class symbol and the metaclass symbol**, because
`backports.lua:2368-2377` maps both onto one name and keeps the earlier: *"A name arrives with the first of
its symbols: a release can export a class without its metaclass … and the class is the API."* All fourteen
were measured both ways and **the two agree for every one**, so the earliest is the class's own — the
grouping is method, not luck.

**The subclasses arrive before their bases, and that costs nothing.** `MPSNNFilterNode` is the superclass of
seven of the other thirteen and lands a release later; `MPSNNBinaryArithmeticNode` and `MPSCNNPoolingNode`
land two later and are the bases of six more. That reads backwards and is Apple's own export history. It is
harmless here because the hierarchy is **not built by name at runtime**: a subclass names its superclass as
a link-time symbol, and a band that keeps the 11.0 object keeps the 12.0 and 16.0 objects too — the same way
main's other MPS objects already reference `CharonMPS` classes across files. `ld -r` over all 77 objects
leaves no MPS class undefined, which is the mechanical form of that statement.

**What the split cost and what it did not.** The rows' `introduced` stays **11.0** for all fourteen, because
that is the header's own date and the date `check_registry`'s `held` check accepts; the *export* release is
recorded in each row's `source` and in the table above, which is where a reader looks for why the object
was split. The registry's `unlisted` check counts classes and members, not files, so the split needed no
new rows.

Every claim on this page is produced by one command:

```
sh tests/backports/host/mpsnn/run.sh
```

and the oracle it is checked against is **the release's own `MPSNNGraph`**, which runs on this machine.
That is the whole difference between this page and the last attempt at it, and it is the first section
below because everything else depends on it.

## The oracle exists, and the previous round's reasons it did not were two probe bugs

`tests/backports/host/mpsnn/probe.txt` is the transcript of `probe.m`, built fresh against the SDK of
this machine and linked with `Metal.framework` and `MetalPerformanceShaders.framework`. It prints:

```
MTLCreateSystemDefaultDevice: 0x... class AGXG16SDevice name Apple M4 Pro
device newCommandQueue: 0x... class AGXG16XFamilyCommandQueue
queue commandBuffer: 0x... class AGXG16XFamilyCommandBuffer
  empty commit + waitUntilCompleted: OK, status 4, error (none)
  commit with an encoder: OK, status 4, error (none)
  Apple's names absent from the loaded framework: 0
  Apple's MPSNNGraph answers (float16 bits): 4980 4d80 5020 5180
  Apple's MPSImageAdd answers: 11 22 33 44
```

`0x4980 0x4d80 0x5020 0x5180` are the four halves that decode as **11 22 33 44**, and they are what the
release's own graph answers for `(1,2,3,4) + (10,20,30,40)`.

Three things had to be got right for that, and each one is a bug the last attempt had:

1. **The command buffer comes off a queue.** `MTLDevice.h:507-518` declares `-newCommandQueue` and
   `-newCommandQueueWithMaxCommandBufferCount:` and nothing else; `-commandBuffer` belongs to
   `MTLCommandQueue`. The probe that reported "`-[AGXG16XFamilyCommandBuffer_mtlnext commit]`: unrecognized
   selector" built its buffer with `-[MTLDevice newCommandBuffer]`, so the object it blamed was never the
   receiver of the call it made. (The runtime happens to answer `-newCommandBuffer` on this host's device,
   which is why it got as far as blaming `-commit`; the *declared* route is the queue, and that is the
   route `MPSNNGraph11.m`'s `-executeAsyncWithSourceImages:completionHandler:` uses too.)
2. **The class names are Apple's.** `NSClassFromString` was asked for `MPSNNAddNode`,
   `MPSNNConvolutionNode`, `MPSNNPoolingMaxNode` and `MPSNNActivationNode`. No Apple header declares any of
   them. The real names are `MPSNNAdditionNode`, `MPSCNNConvolutionNode`, `MPSCNNPoolingMaxNode` and
   `MPSCNNNeuronNode` — all present. The probe checks five invented names and twenty-four real ones and
   prints both lists, so the distinction is in the transcript rather than in a belief.
3. **The result was read in the format it has.** `MPSNNGraph.h:196` makes a graph's `format` default to
   `MPSImageFeatureChannelFormatFloat16`, so the release's result image is R16Float and read as float32 the
   correct answer is `2.69038e+08 6.88875e+10 0 0`. `graph-cases.m` sets the format to Float32 on both
   sides — the port's destination is allocated from the *source* image's own channel format
   (`[MPSImage charon_mps_descriptor]`), so it is float32 either way — and prints the format each side
   produced.

The MPS **image kernels** on this host are a separate question and they answer differently:
`MPSImageAdd` alone gives `11 22 33 44`, while `facts/MetalPerformanceShaders/Image.md:144` records
`computeCommandEncoderWithDispatchType:` as absent from this AGX family and the five thresholds dying on
it. That record stands; it is about the image kernels and not about the graph.

## The fourteen classes, settled from the headers

`first-rung.lua` answers **11.0** for all fourteen and **12.0** for `MPSNNGradientFilterNode`,
`MPSNNGradientStateNode`, `MPSNNLabelsNode` and `MPSNNReduceRowSum`:

```
xmake l tools/cache-index/first-rung.lua MPSNNGraph MPSNNImageNode MPSNNStateNode MPSNNFilterNode \
    MPSNNPadding MPSNNDefaultPadding MPSNNBinaryArithmeticNode MPSNNAdditionNode \
    MPSNNSubtractionNode MPSNNMultiplicationNode MPSNNDivisionNode MPSNNConcatenationNode \
    MPSCNNPoolingNode MPSCNNPoolingAverageNode MPSCNNPoolingMaxNode
```

"fourteen node classes" and "ten classes" are the same list counted at two points of its own history: the
ten were the first commit's `MPSNN*` names, before the three `MPSCNNPooling*` nodes arrived in the second.
Eleven are `MPSNN*` and three are `MPSCNNPooling*`.

Settled from **both** SDKs on this machine, 16.4 and 26.2:

- `MPSNNDefaultPadding` declares **four** methods. This object implements the two 11.0 ones
  (`+paddingWithMethod:`, `-label`) plus the coding pair `MPSNNPadding`'s base list requires.
  `+paddingForTensorflowAveragePooling` (`:497`) and `+paddingForTensorflowAveragePoolingValidOnly` (`:500`)
  carry `ios(11.3)`; `-inverse` (`:455`) carries the same date, and the row `-[MPSNNPadding inverse]` already
  says `introduced 11.3`.
- An earlier form of this object defined **five** more `+paddingFor…` methods —
  `+paddingForTensorflowMaxPooling`, `+paddingForTensorflowConvolution`, `+paddingForCaffePooling`,
  `+paddingForCaffeConvolution`, `+paddingForMXNetPadding` — and **no Apple header in either SDK declares
  any of them**. They are gone. A public class method no release ever had is API the port would be
  inventing, and its comment had claimed the header "names" six pre-rolled policies.
- The 11.0 band holds two classes this object does not build and says why: `MPSNNGradientFilterNode` and
  `MPSNNGradientStateNode` are 12.0, and `MPSCNNPoolingL2NormNode` (`MPSNNGraphNodes.h:1540`) carries
  `ios(12.0)`.

## The seventeen methods the object does not implement, and the one suppression

`-Wincomplete-implementation` asks for seventeen and every one is named at the `@implementation` it
belongs to, with its header line and its date:

| class | methods | release |
| --- | --- | --- |
| `MPSNNFilterNode` | `gradientFilterWithSource:` `:404`, `gradientFilterWithSources:` `:412`, `gradientFiltersWithSources:` `:420`, `gradientFiltersWithSource:` `:428` | no date; each returns `MPSNNGradientFilterNode*`, a 12.0 class |
| | `trainingGraphWithSourceGradient:nodeHandler:` `:466` | `ios(12.0)` |
| `MPSNNBinaryArithmeticNode` | `gradientClass` `:2158` | no date; returns the 12.0 gradient class |
| | `gradientFiltersWithSources:` `:2162` | `ios(11.3)` |
| `MPSNNDefaultPadding` | `paddingForTensorflowAveragePooling` `:497`, `paddingForTensorflowAveragePoolingValidOnly` `:500` | `ios(11.3)` |
| `MPSNNGraph` | `encodeBatchToCommandBuffer:sourceImages:sourceStates:intermediateImages:destinationStates:` `:264` | `ios(11.3)` |
| | `readCountForSourceImageAtIndex:` `:363`, `readCountForSourceStateAtIndex:` `:375` | `ios(12.1)` |
| | `initWithDevice:resultImages:resultsAreNeeded:` `:98`, `graphWithDevice:resultImages:resultsAreNeeded:` `:103` | `ios(13.0)` |
| | `encodeBatchToCommandBuffer:sourceImages:sourceStates:` `:299` | no date; its arguments are `MPSImageBatch` types, which the port does not carry |
| | `initWithDevice:resultImage:` `:112`, `graphWithDevice:resultImage:` `:119` | `ios(11.0, 11.3)`, **deprecated** — the pre-11.3 spellings of the two initializers this object does implement, and `MPSNNGraph.h:113` says to use those instead |

### The seventeen are named by rows, and the rows were measured against the gate's own check

Each of the seventeen has a registry row, `status: owed`, `minimum: 6.0`, in
`registry/MetalPerformanceShaders/absent_MetalPerformanceShaders.json`. `owed` and not `absent` is the
port's own word for it (`backports.lua:1512`): the release carries the name at its own release and the port
could carry it, so `absent` — "the release has nothing" — would be a false claim about Apple. Each row
names its header line, its release, why this object does not define it, and what would.

`introduced` is the header's own annotation where the header has one. Two rows are not, and both are
measurements:

- **The four `MPSNNFilterNode` gradient methods and `-gradientClass` read `12.0`,** not the `11.0` their
  class's interface is annotated with. `MPSNNGraphNodes.h:404-428` and `:2158` carry no macro of their
  own, and `grep -cxF` over `~/.charon/dyld/11.0/selectors_arm64.txt` — every selector the whole 11.0
  cache carries — answers **0** for all five. They cannot have arrived in 11.0, and what they return is
  `MPSNNGradientFilterNode`, which `first-rung.lua` places at 12.0.
- **`+[MPSNNDefaultPadding paddingForTensorflowAveragePooling]` reads `11.0`,** not the `11.3`
  `MPSNeuralNetworkTypes.h:497` annotates it with, because **the selector is in the 11.0 cache** (the same
  grep answers **1**) — and because `check_registry`'s `held` check refuses an absent-or-owed row whose
  `introduced` is later than a band whose cache carries the name ("listed as absent, but the release carries
  it itself"), which `tests/backports/host/registry/check.lua:47-49` pins from both sides. This is the one
  place where Apple's header and Apple's own binary disagree, and the measurement decides the field.

The rows were then run through `check_registry` itself with the real inventories, one cache per band, the
band's own cache only — a mismatched pairing answers a question nobody asked, and a first run of the probe
that swept seven deployments against the 12.0 cache said so loudly:

```
band 11.0 (the 11.0 arm64 cache, 52768 classes): OK, none of the 17 rows is named
band 12.0 (the 12.0 arm64 cache):                OK, all 17 rows pass
```

16.0 and 18.0 cannot refuse a row whose `introduced` is 13.0 or less, and 4.3, 6.0 and 6.1.3 carry no MPS at
all — `cache-census.lua MPS 6.1.3 4.3 11.0` reads 0 of 524 and 0 of 354 images naming MPS — so
`carried_by_release` is false there by the census and not by an assumption.

Implementing any of them would put a later-release name in an object that is otherwise one release, which
`misplaced()` in `backports.lua` refuses by raising and which `tools/release-split.lua` cannot see at all
-- it reads band points, not a file's declared release. So the three objects carry **four scoped
`push`/`ignored`/`pop` pairs** between them, one above each `@implementation` that has one, each with its
own list of names and its own reason: two for `MPSNNGraph` and `MPSNNDefaultPadding` in `MPSNNGraph11.m`,
one for `MPSNNFilterNode` in `MPSNNFilterNode12.m` and one for `MPSNNBinaryArithmeticNode` in
`MPSNNGraphNodes16.m`. That is instead of the file-wide `#pragma clang diagnostic ignored "-Wprotocol"` /
`"-Wincomplete-implementation"` the earlier form carried at line 59.

Two ways to have no pragma at all were measured and both refused:

- `@dynamic` does not silence `-Wincomplete-implementation` for a **method**, only for a property. For
  `@dynamic gamma;` clang answers both `method definition for 'gamma' not found` and `property
  implementation must have its declaration in interface`.
- Carrying the seventeen would be **four more objects**, one per release - 11.3, 12.0, 12.1 and 13.0 -
  each with its own placement to measure **by the same export measurement the table above records, and
  not by the header's clause**, and each with its own registry rows. That is the right way and it is a
  piece of work of its own, not a line in this one.
`-Wprotocol` needed nothing: the only two protocol warnings were `MPSNNDefaultPadding`'s
`+supportsSecureCoding YES` **without** `-initWithCoder:`/`-encodeWithCoder:`, which `MPSNNPadding`'s own
base list `<NSObject, NSSecureCoding>` (`MPSNeuralNetworkTypes.h:363`) makes a real claim about. Both are
implemented now and the conformance is round-tripped under the port's own key `paddingMethod`, as
`MPSKernel9.m`'s `label` is — the release's archive keys for a padding policy are in no header.

## What the cases measure, and the two answers the release and the port do not share

`run.sh` compiles `graph-cases.m` twice — once linked against the host's `MetalPerformanceShaders`, once
marked `-DCHARON_PORT_BUILD` with every class of the package renamed through `rename.h` and its own
selectors prefixed by `../prefix_selectors.py` — and compares the two transcripts. The rename is not
optional: the host's framework defines every class this object defines. The `class` lines in both
transcripts are the receipt, the system build printing `MPSNNAdditionNode` and the port build
`CharonMPSNNAdditionNode`.

```
ok    add
ok    subtract
ok    multiply
ok    divide
ok    add-chained
ok    add-then-sub
ok    concat-1
ok    concat-2
ok    pool-avg-shape
ok    pool-max-shape
ok    result-not-needed

graph: 11 case(s) the release and the port answer identically, 0 listed above
```

| case | graph | release | port |
| --- | --- | --- | --- |
| `add` | `(1,2,3,4) + (10,20,30,40)` | `11 22 33 44` | same |
| `subtract` | `(1,2,3,4) − (10,20,30,40)` | `-9 -18 -27 -36` | same |
| `multiply` | `(1,2,3,4) × (10,20,30,40)` | `10 40 90 160` | same |
| `divide` | `(1,2,3,4) ÷ (10,20,30,40)` | `0.1 0.1 0.1 0.1` | same |
| `add-chained` | `((a + b) + b)` | `21 42 63 84` | same |
| `add-then-sub` | `((a + b) − b)` | `1 2 3 4` | same |
| `concat-1` | one 1-channel source | `1x1x4 1 0 0 1` | same |
| `concat-2` | one 2-channel source | `1x1x4 1 2 0 1` | same |
| `pool-avg-shape` | 3×3 source, 2×2 window, `SizeSame` | `3x3x1` | same |
| `pool-max-shape` | the same window, maximum | `3x3x1` | same |
| `result-not-needed` | `resultImageIsNeeded:NO` | `NIL` | same |

`add-chained` and `add-then-sub` are the two that decide whether the walk orders anything at all: a graph
that ran its filters in the order they were made, or that handed a node the original input instead of its
predecessor's output, fails both. `pool-*-shape` is the padding arithmetic compared with **the release's
own compiled arithmetic** rather than with a transcription of it, which is a stronger oracle than the C
block this file used to extract from `MPSNeuralNetworkTypes.h` and compare against itself.

### `add-scaled`: the release's two halves disagree, and this port follows the node

```
release: case add-scaled         2x2x1 11 22 33 44
port:    case add-scaled         2x2x1 12 24 36 48
```

`probe-scaled.m` measures all three facts on one host, one device:

```
default primaryScale 1 secondaryScale 1 bias 0
after set primaryScale 2
through the graph: 11 22 33 44
through MPSImageAdd with primaryScale 2: 12 24 36 48
```

The node's setter works, the release's own kernel honours the value, and the release's own graph does not
carry it into the kernel it dispatches. `MPSNNGraphNodes.h:2136-2183` declares `primaryScale` on the node
and `MPSImageMath.h:34-37` applies it, so this port hands it across. Both lines are printed; neither is
hidden, and the case is not deleted.

### `concat-1+1`: refused, and it is `MPSImage`'s limit

```
release: case concat-1+1-unholdable 1x1x8 1 0 0 1 5 0 0 1
port:    case concat-1+1-unholdable 0x0x8 <refused>
```

`MPSNNGraphNodes.h:2443-2446` pads **each** source out to a multiple of four channels, so a concatenation
of two one-channel sources is eight channels wide, and `MPSImage13.m` holds one, two and four channels and
refuses the rest: `MPSImage: channel format 4 with 8 feature channels has no Metal pixel format, so no
texture was made`. Not this object's row, and not fixable in it.

**What goes in the padding is measured, not assumed.** `probe-concat.m` sweeps the release's own node over
five channel widths of a 1×1 image and gets:

```
1+1 -> 1x1x8 : 1 0 0 1 5 0 0 1
2+2 -> 1x1x8 : 1 2 0 1 5 6 0 1
4+4 -> 1x1x8 : 1 2 3 4 5 6 7 8
1+4 -> 1x1x8 : 1 0 0 1 5 6 7 8
3+1 -> 1x1x8 : 1 2 3 0 5 0 0 1
```

zeros, and a **1** in the block's fourth channel for a source of one or two channels — and, by the last
row, a zero for a source of three. The header states the *count* of the padding and nothing about its
value. This object had a comment saying the release "does not give" a value there and left the
destination as allocated; the measurement refutes that, and the comment and the code were both changed.

## Four defects the differential found, and where each is fixed

1. **The walk searched the list it was building.** `charon_mps_visit:seen:` asked "which filter produced
   this node?" by scanning the list the walk is *appending to*. The producer of the node being visited is
   by definition not in it yet, so every node read as a graph input and the graph reported no filters. The
   pairing now lives in `CharonMPSNNProducers()`, registered where a result node is made — which is the
   release's arrangement too, since a caller wires the filters *before* the graph exists.
2. **`primaryScale` and `secondaryScale` defaulted to zero.** `MPSImageMath.h:31-32`: "The default value
   for primaryScale and secondaryScale is 1.0f." An Objective-C `float` ivar is zero and `:34-37` applies
   the scales to both operands, so a zero scale answers zero however correct the kernel underneath is.
3. **The arithmetic kernel was never made.** The kernel getter is lazy and the encode called the *ivar*;
   every node sent its message to `nil`. It is made in the encode, against the graph's device — the one
   thing a node does not have at build time, since the caller builds the nodes before the graph that runs
   them.
4. **The padding policy was handed the node instead of the node's images.**
   `-charon_mps_destinationDescriptorForSource:` passed `@[ (MPSImage *)self ]`, so the policy asked its
   first argument for its shape and sent `-charon_mps_descriptor` to an `MPSNNFilterNode`. Nothing caught
   it, because every earlier case left that branch untaken. Measured: `-[CharonMPSCNNPoolingAverageNode
   charon_mps_descriptor]: unrecognized selector sent to instance`.

Two more were found by reading rather than by running, and are named at their fixes: the concatenation
joined **in place** into a buffer sized for the source (`CharonMPSImageConcatRows` takes the two sides
separately — a one-channel source into a four-channel destination walked off the end of the read buffer,
measured as a SIGSEGV), and the three size policies were read as the bits rather than the bits **minus
one** (`MPSNeuralNetworkTypes.h:339-341` declares `ValidOnly 0, Same 1<<4, Full 2<<4` and `:397-401` wants
the coefficient `-1, 0, 1`).

And one more, which is the reason this object had never been built at all:

5. **`-[MTLDevice newCommandBuffer]` does not exist.** `-executeAsyncWithSourceImages:completionHandler:`
   asked the device for a command buffer. `MTLDevice.h:507-518` declares no such selector; `-commandBuffer`
   belongs to `MTLCommandQueue`. It did not compile — the file-wide pragma silenced every *warning* in the
   file, and an error is not a warning — so the object had never been built for armv7 at all. The route is
   now the framework's own order: the graph's device, a queue from it, a buffer from the queue.

## Not claimed

**A two-source concatenation.** Above, and `MPSImage`'s row.

**A three-channel source.** `MPSImage13.m` holds one, two and four channels. The release's node answers
`1 2 3 0` for a three-channel source's padded block and the port has no such image to give it, so that row
of the padding table above is a measurement of the release and not a claim about this object.

**A graph from an archive.** `-initWithCoder:device:` is `MPSKernel9.m:85`'s, and an archive written by
`MPSKernel9.m:97` carries a label and nothing else; the release's own keys for a graph's nodes are in no
header. A graph decoded from one has no result node, so its encode refuses in one line.

**Anything the release does not carry.** `cache-census.lua MPS 6.1.3 4.3 11.0` reads 0 of 524 images
naming MPS at 6.1.3 and 0 of 354 at 4.3, with 21 and 6 classes present and all of them MediaPlayer's
(`MPServerObject`, `MPStoreOffer`, `MPSwipeGestureRecognizer`): no image, class or protocol of MPS is
present at either band end. This object is the port's own work over nothing the release had.

## A dependency this object does not take

`-[MPSImageDescriptor copy]`, as `MPSImage13.m` writes it, is `[[[MPSImageDescriptor allocWithZone:] init]
copy]` and calls itself; a probe that does nothing but copy a descriptor dies of stack exhaustion.
`MPSNNGraph11.m` builds descriptors field by field instead. `MPSImage13.m` carries the 13.0 API — another
object's row — so this object does not fix it, and the graph is the evidence that it needs fixing.

# MPSNNReduce: the thirteen classes, and the walk that answers for them

`MPSNNReduceUnary` and the twelve concrete classes: RowMin, ColumnMin, FeatureChannelsMin, RowMax,
ColumnMax, FeatureChannelsMax, RowMean, ColumnMean, FeatureChannelsMean, RowSum, ColumnSum,
FeatureChannelsSum. `MPSNNReduce.h:36` plus each concrete class's own annotation says `ios(11.3)`, and
`introduced` in the registry says 11.3 for all thirteen, which is when **Apple** published them.

## Two objects, and which release each one is

This page said "one object" and the 6.1.3 gate refused the claim, correctly:
`3 objects hold API no single release introduced: MPSBackports: MPSNNReduce11.m defines ...`. The
release test does not read the header's annotation and does not read `introduced`; it reads
`modules/apple/dyld.lua`'s `first_releases()` over the held ladder, which is what
`modules/apple/backports.lua`'s `check_releases()` calls, and that asks a different question: *the
first held release that EXPORTS the symbol*, so that a client of the backport can bind it. Measured
with that call:

| symbol | `first_releases()` | rungs that export it |
| --- | --- | --- |
| `_OBJC_CLASS_$_MPSNNReduceUnary` and its metaclass | **16.0** | 16.0, 18.0 |
| `_OBJC_CLASS_$_MPSNNReduceColumnMax`, `RowMin`, `FeatureChannelsSum` and the other nine | **12.0** | 12.0, 16.0, 18.0 |

`tools/cache-index/first-rung.lua` answers **12.0 for all fourteen of them**, and that is the whole
difference between the two tools rather than a disagreement about the caches: `first-rung.lua` reads
whether a rung **carries** a name (its string section, its Objective-C metadata) and
`first_releases()` reads whether a rung **exports** it. The 12.0 cache carries
`MPSNNReduceUnary` and does not export it, so the base reads as 16.0 and the twelve concrete
classes as 12.0, and an object cannot be both. This is the same split
`MPSImageReduce12.m` / `MPSImageReduceUnary16.m` already makes for the same reason, and the
thirteen rows keep `introduced: 11.3`: that field is a fact about Apple's headers and the band an
object is placed in is a fact about the held caches, and the two are not the same fact.

| file | what it holds | why |
| --- | --- | --- |
| `MPSNNReduce16.m` | `MPSNNReduceUnary`: the walk, the ivars, the `revenant_nnReduceWithDevice:` seam, the weight accessors | the base is exported from 16.0 |
| `MPSNNReduce12.m` | the twelve concrete classes, and `MPSNNReduceFeatureChannelsSum`'s `weight` accessors | the twelve are exported from 12.0 |

The seam both files share is declared once, in `RevenantMPSReduce.h`, beside the
`MPSImageReduceUnary` one: a `static` in either file would be a second copy, and a `revenant_`
selector reaching the class the SDK declares is the one thing the two can share. All three of the
differential's mutation sites (`column-start`, `feature-step`, `weight-default`) are in the base, so
`tests/backports/host/mpsnnreduce/mutation.sh` names `MPSNNReduce16.m`; `anchor_check` there is what
finds that a site moved rather than that a mutation is wrong.

## What decided that this is work and not a missing capability

The release's own cache, read with `tools/corpus/objc-inventory.lua` over
`$HOME/.revenant/dyld/16.0/dyld_shared_cache_arm64e`: **none of the thirteen declares an encode of its
own.** `MPSNNReduceRowSum`'s entire instance list is

    -destinationImageDescriptorForSourceImages:sourceStates:paddingMethod:sourceOffset:
    -initWithCoder:device:
    -initWithDevice:

so the walk is the one it **inherits** from `MPSCNNKernel`, and `MPSCNNKernel` is a class this port
already carries (`MPSCNNKernel10.m`, `cnn.json`, introduced 10.0, `implemented`). That base's
`-encodeToCommandBuffer:sourceImage:destinationImage:` is a **CPU walk** here, as
`MPSCNNPooling10.m`'s and `MPSCNNConvolution10.m`'s are — the port's MPS kernels walk the image
rather than encode onto a GPU. The question the 9.0 band had to ask — *can the port compute the answer
on the CPU for the same input?* — answers **yes**, which is why these rows are `implemented` and not
`owed`.

The base does not carry the encode, and the twelve concrete classes each implement it, which is how
`MPSCNNPooling10.m` does it. A category cannot read the ivars the base declares, which
`MPSImageReduceUnary16.m:29-40` already records for the same family of reduction.

## The walk, and what is new in it

`MPSImageReduceUnary16.m` already reduces a **row or a column** of an `MPSImage` over
`RevenantMPSImageReadRegion` / `RevenantMPSImageLoad` / `RevenantMPSImageWriteRegion`, and its 108 cases
compare with 0 mismatches. This object adds the **third axis** `MPSNNReduce` names and `MPSImageReduce`
does not — the feature channel — and reuses the same helpers. One loop does all three axes because
they differ by a stride, not by a loop.

| axis | runs | span | one answer is |
| --- | --- | --- | --- |
| row | rows × channels | columns | one row of one channel |
| column | columns × channels | rows | one column of one channel |
| feature channel | columns × rows | channels | one pixel, all channels combined |

The count of answers is the header's own sentence and not this file's arithmetic: `MPSNNReduce.h:66`
"returning the mininmum value for each row of an image", `:93` and `:199` the same for a column, `:119`
"for feature channels of an image", and `:173`/`:199`/`:225`/`:279`/`:305`/`:331`/`:357`/`:383`/`:410`
for max, mean and sum.

**Where the channel goes** is the one thing the header does not state. An `MPSImage`'s row is a row of
**one** feature channel — `MPSCNNKernel` carries `sourceFeatureChannelOffset` and
`sourceFeatureChannelMaxCount` precisely because a kernel walks one channel at a time — so a row or
column reduction answers one value per row or column **per channel** and keeps the destination's
channel count, while a feature-channel reduction crosses channels and answers one value per **pixel**
into a single plane.

**The destination's shape is not measured and does not claim to be.** The header fixes the count and
never states width or height, and this host cannot supply them: its AGX family lacks
`computeCommandEncoderWithDispatchType:` and the release's own kernel dies encoding with
`-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized selector`.
What the object does instead is the shape the count forces — a row reduction's values down the first
column, a column reduction's along the first row, a feature-channel reduction's filling the destination
row-major — and a destination too small for the count is **refused by name** with the numbers, rather
than written past its edge.

## The weight

`MPSNNReduce.h:413-420` puts `weight` on **`MPSNNReduceFeatureChannelsSum` alone**, and the release's
own cache agrees: of the twelve concrete classes only that one lists `-weight` and `-setWeight:`. The
property's own `@discussion` ends "The default value is 1.0." — the header's sentence, and the only
value this object writes from it.

Two things follow, and the differential held the object to both:

- The weight scales each channel's value **before** the reduction, so a weighted sum of `{1, 10, -1,
  0.5}` at 0.5 is 5.25 and not 2.625.
- It applies to a **sum and a mean** and to a minimum or a maximum **not at all** — the property's
  sentence says "to compute a weighted sum or mean". Scaling a minimum would change which value is
  extremal for a negative weight, and a header that does not ask for it is not read as asking.

That second clause is **not** defended by the mutation campaign, and the omission is deliberate: `weight`
is declared on one class and each kernel is its own object with its own copy of the base's storage, so
no caller can set a weight and then ask a minimum. A campaign site for it would pass for a reason that
has nothing to do with the mutation. The scope is held by the object's own comment and by
`RevenantNNReduceReference.h`, where a reader can check it.

## What the measurement is

`tests/backports/host/mpsnnreduce/run.sh` builds the object from the current tree into a fresh
directory and runs twelve cases plus two refusals over a 3×4×4 float32 source. The classes are named
as **classes**, not strings, so the generated rename header reaches the port's own — a string literal
would reach the release's, which is what the first version of the `mpsimage` reduce case did.

The reference is `RevenantNNReduceReference.h`: the header's twelve sentences as arithmetic in plain C,
taking the source values and the operation as arguments and never naming the port's class, so a case
that agrees is two implementations of one sentence rather than one compared with itself. It is a NEW
file and not an addition to `mps-reference.h`, because `MPSNNReduce` is in MPSNeuralNetwork.framework
and the `MPSImageReduce` rows are in MPSImage.framework, and one reference shared by both would be a
file whose contents depend on which framework's surface the compiler read.

The source is four channels because that is what the port maps to a Metal pixel format
(`MPSImage13.m:50-72` refuses any other count by name: "channel format 4 with 3 feature channels has
no Metal pixel format"). The values are an arithmetic sequence with a negative channel and a fractional
fourth, so a walk that transposed an axis, seeded a minimum from the first value, or ignored the weight
would all differ.

**The bound, and why it differs by operation.** min, max and sum select or add values the source
already holds, so they are **exact** and compared for **equality** — a copy that moved a bit is a copy
that moved a bit, and a tolerance here could only hide it. mean divides, and dividing cannot be exact
in binary, so the sum is taken in double and divided once and the answer is within one whole float32
ulp. Same split `mps-reference.h:276-283` states for the `MPSImageReduce` rows.

```
COMPARED 185  MISMATCHES 0

reference reduce-row-sum      runs 12 span 4  1  2  3  4  5  6  7  8  9  10  11  12
reference reduce-column-sum   runs 16 span 3  15  18  21  24  150  180  210  240
                                                  -15 -18 -21 -24  13.5  16.5  19.5  22.5
reference reduce-feature-channels-sum  runs 12 span 4  5.25  10.75  16.25  21.75  27.25  32.75
                                       38.25  43.75  49.25  54.75  60.25  65.75
  refusal reduce-row-sum into a 1x1x1 destination: left as it was (-12345)
```

## The mutation campaign, and what it caught

`tests/backports/host/mpsnnreduce/mutation.sh` — **3 sites, all caught**, 185 elements each. The
campaign starts only if every anchor resolves exactly once, which is what caught a hand-written anchor
whose whitespace differed from the file's.

| site | what it breaks | caught |
| --- | --- | --- |
| `column-start` | a column run starts at a row stride, so every column after the first walks late | 48 mismatches |
| `feature-step` | a feature-channel run walks pixels as well as channels | 72 mismatches |
| `weight-default` | the base starts the weight at 0.5 rather than the header's 1.0 | 12 mismatches |

**Two of the three are regressions for defects this object had while it was being written**, which is
why they are here and not three arbitrary edits:

- A column run was starting at `spatial * winCols` — a row's stride — so column 1 read column 0 and the
  last two columns ran off the window and were skipped. The right form differs by one multiplication
  and is written down at the site.
- A feature-channel run had `step = 1`, so it walked pixels while the step index was also the channel.
  `step = 0` is the fix, and the comment there says why 1 looks right.

## Two defects in the harness itself, recorded because a differential's own errors are the ones it
cannot catch

- The reference indexed the read-back buffer with the **source's** column count. A row or column
  reduction's destination is 1 wide and a feature-channel one's holds a single plane, so every run
  after the first read the wrong element. Both shapes are now named parameters.
- The refusal case set a **local** to `-1.0f` and then read the **texture** back, comparing two
  unrelated objects. It now writes a known sentinel into the destination first, so "nothing was
  written" is a question about the texture: the case prints `-12345`, the value that survived.

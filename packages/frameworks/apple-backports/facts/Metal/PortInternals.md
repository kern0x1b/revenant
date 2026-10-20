# The RevenantMetal objects, which are the port's and not Apple's

Across the SDK ledger there were 23 rows whose api was a `revenant`-prefixed name, and they were not
confined to one file:

  Metal/ios80classes.json            16   the object model below
  Metal/ios120classes.json            1   RevenantMetalEventState
  Metal/ios10heap.json                1   RevenantMetalHeap
  Metal/ios12sharedevent.json         1   RevenantMetalSharedEvent
  UIKit/ios17-18.json                 1   RevenantEdgeList
  Foundation/nz-private-classes.json  3   RevenantPersonNameParts, RevenantPresentationIntentState,
                                           RevenantTermOfAddressState

The count in this family's commit subjects moved as the question got sharper - 16, then 19, then 23 -
with no commit saying why, so here it is for a reader counting subjects rather than rows:

  16  the Revenant-prefixed rows in Metal/ios80classes.json, which is where I started looking
  19  the RevenantMetal-PREFIXED rows across the Metal files, adding RevenantMetalEventState,
      RevenantMetalHeap and RevenantMetalSharedEvent from three files I had not opened
  23  the Revenant-prefixed rows across the WHOLE registry, adding RevenantEdgeList in
      UIKit/ios17-18.json and three in Foundation/nz-private-classes.json

Each was true of its own set and none was a miscount; using one number for all three was the error. The
23 over six files is the form worth having, because it says the pattern was never confined to one
registry.

## What they are

Stand-ins for the `MTL` types. The port needs an object to hand back where an application asks Metal
for a device, a buffer or a command queue, and on a release with no GPU to ask, these are what it
hands back. Each is an `@implementation` in `packages/frameworks/apple-backports/Metal/`, and each answers: a
device that reports a registry ID and a name, a buffer with a length, a queue that runs what it is
given.

## Why the rows exist, which is not what they look like

A row here is the PLACEMENT RECORD for every band that carries the object, whatever its status claims.
backports.lua:2014 is the whole of it:

    local entry = entry_of(listed, name)
    local minimum = entry.minimum or ""

`minimums()` reads `entry_of` and takes `entry.minimum` for every name an object carries, and it never
reads `entry.status`. `in_range()` likewise reads only `minimum` and `maximum`. So the status on these
rows says nothing to the band checker - `absent` is a claim about the RELEASE - and the minimum is what
actually places the object.

That is why deleting them looked clean and was not. Five objects every band carries read their minimum
from these rows - RevenantMetalLibrary.o, MTLBlitCommandEncoder10.o, MTLHeap11.o, MTLHeap13.o,
MTLSharedEvent15.o - and with the rows gone the 4.3 band cannot place or link them while 6.1.3 stays
green, because everything those five name is also carried at 6.0. **A row that looks like a redundant API
entry may be the only record of when a symbol becomes linkable.** This paragraph is here so the next band
does not "tidy" these the way this one nearly did.

## The one-line rule in backports.lua, and its empty set

That rule - `bare:startswith("revenant_") or bare:startswith("Revenant")` on the unlisted computation, taken
from release-split.lua:100 - guards a DIFFERENT set from these rows, and that set is presently EMPTY.
There are 342 `Revenant*` classes in the tree and 23 rows; the other 319 never appear as unlisted builds
because `internal_symbol()` keeps them out of the export list the check reads, so the rule cannot fire
for them. It is insurance for the day one of those 319 grows a row, which is the honest description
of a guard whose triggering set is nil today - and it keeps its teeth, since it is an extra conjunct
on the existing condition and every other unlisted build is still named.

This paragraph used to blame `-fvisibility=` for it, and that was wrong on both counts; the section
below measures the correction.

## Why the ledger says nothing about them

Three separate facts, each checkable:

1. **No SDK header declares any of them.** They are not in `Metal.framework`'s headers, and
   `grep -c RevenantMetal coordination/corpus/sdk-26.2-surface.tsv` returns **0** where
   `grep -c MTLDevice` on the same file returns **145** - the whole prefix, not one name of it, and a
   control from the same file so the zero is not the reader's.
2. **The band exports nothing under these names**, and the reason is `internal_symbol()`, not
   visibility. See the measurement below; it supersedes what this page used to say here.
3. **There is no Apple implementation to read.** No dyld cache holds a `RevenantMetalDevice`, so there is
   no branch structure, no constant and no return value to port. What these objects answer is the port's
   own model of the GPU-less case, and a row in an SDK ledger has no business claiming to describe it.

## The export measurement, and the visibility claim it retires

The sixteen rows of `Metal/ios80classes.json` each used to say that the port's classes are "compiled
hidden (`xmake.lua:15` sets the package's `-fvisibility=`)", so no row can be `implemented`. That claim
is false twice over, and both halves were checked with commands a reader can paste.

**Half one: the flag never reaches these files.** `modules/apple/backports.lua:472-477` gives
`-fvisibility=hidden` to a **`.c`** source only - the `else` arm of a test on the extension - and gives
an Objective-C source `-Werror=objc-missing-property-synthesis` instead. Every one of these objects is
a `.m`. The comment above that test says so in its own first words: "Only C is compiled hidden." And
`packages/frameworks/apple-backports/xmake.lua:15`, the line the old text cited, is a **comment** about AMD and
COLAMD's `AMD_EXPORT` overriding `-fvisibility=hidden`; it sets nothing.

**Half two: the flag would not have hidden them anyway.** Same source, two compiles, the recipe's own
flags (`-target armv7-apple-ios6.0 -isysroot $SDK -fobjc-arc -Os -g0 -Wno-unguarded-availability-new
-Wno-unguarded-availability -Werror=objc-missing-property-synthesis`), the second with
`-fvisibility=hidden` added:

    nm -gU recipeflags.o | grep OBJC_CLASS   ->   00002368 S _OBJC_CLASS_$_RevenantMetalDevice
    nm -gU withhidden.o  | grep OBJC_CLASS   ->   00002368 S _OBJC_CLASS_$_RevenantMetalDevice

The object defines the class symbol as a global defined symbol either way, at the same address, and
both objects are 35260 bytes.

**What actually keeps it out, and what the built band says.** The rule is `internal_symbol()`
(`modules/apple/backports.lua:169-190, the rule itself at :189`): a name whose bare form begins `revenant` is not API, so it is
"neither weighed against a release nor exported" - the comment at :161-166 - and `exported_symbols()`
drops it, which is the function `band()` and the registry check both ask. Over the **built 6.1.3 band**
(`nm -gUj` on the `bands/6.1.3/libMetalBackports.dylib` of the tree's own canon package
`org.revenant.apple-backports_0.8.10+8cfbbe9d`):

    nm -gU over the twenty objects: 22 _OBJC_CLASS_$_ symbols, 19 of them RevenantMetal*, and all
                                    sixteen of these classes DEFINED among them
    nm -gUj over the built band:    68 names, 32 _OBJC_CLASS_$_ of them, and none of the sixteen
    nm -a over the built band:      32 _OBJC_CLASS_$_, 0 RevenantMetal*
    every Revenant-named symbol in the band at all: _RevenantMetalBindEpoch

Defined in the object, absent from the band, and no visibility flag stands between the two. The 68
exports are the MTL descriptor classes, `MTLCreateSystemDefaultDevice` and the two error strings - the
API this file is the ledger of - and the one Revenant name the band carries at all is a C function. So the
classes are not present-but-unexported; they are not in the band, not even as local symbols.

**A grep that read zero for the wrong reason, and the control that caught it.** The first pass at this
matched `_OBJC_CLASS_${NAME}$`, which is not a spelling `nm` ever emits - the symbol is
`_OBJC_CLASS_$_NAME`, and the `_` before the `$` was missing. It answered 0 for all sixteen names, which
looked exactly like the answer wanted. The control is what exposed it: the same run reported 19
RevenantMetal class symbols across the same twenty objects while every one of the sixteen read 0, which is
impossible. Every name above comes from the corrected match, `_OBJC_CLASS_$_` + name, read in Python
rather than through the shell's quoting. A count of zero is only a measurement next to a count that was
not zero.

**The same answer from the contract's own tool.** `tools/release-split.lua` applies "the same exclusions
modules/apple/backports.lua's own internal_symbol()/exported_symbols() apply", so it is the third
independent reading of the same rule. Compiled with the flags above into a scratch objects dir - the
twenty objects that define these sixteen classes - it reports:

    release-split: clean, every object file's symbols first-appear in one release
                   (20 files, 6 symbols, 50 releases checked)

    MTLHeapDescriptor10.o _OBJC_CLASS_$_MTLHeapDescriptor     10.0.1
    MTLHeapDescriptor10.o _OBJC_METACLASS_$_MTLHeapDescriptor 10.0.1
    MTLSharedEvent12.o _OBJC_CLASS_$_MTLSharedEventHandle       12.0
    MTLSharedEvent12.o _OBJC_CLASS_$_MTLSharedEventListener    12.0
    MTLSharedEvent12.o _OBJC_METACLASS_$_MTLSharedEventHandle  12.0
    MTLSharedEvent12.o _OBJC_METACLASS_$_MTLSharedEventListener 12.0

Twenty objects carrying between them every method listed below, and **6** symbols between them, all six
real API this port carries at its own release. Not one `RevenantMetal` class symbol survives the exclusion.

The two MTLHeapDescriptor lines name `MTLHeapDescriptor10.o`, and they read 10.0.1 as they always did:
that class is the only API the object carries, so it is dropped from the release that exports it, exactly
as it was when the descriptor shared an object with the port's `RevenantMetalHeap` (the v-bandtrap
series, "Give Metal's vertex attributes and its heap class an object that is in every band"). What
changed is what that object holds beside it: `RevenantMetalHeap` is a class of Revenant's own, so an object
carrying only it and a `revenant` constant exports nothing and is in every band, which is where the two
files that are categories over that class need it to be.

`implemented` is still the wrong status, and now for the true reason: the band does not export the name,
because a `revenant`-prefixed name is internal by rule rather than by compiler flag.

## The method counts, counted per class and not per file

Nine of the sixteen rows carried a number that is the **whole file's** method count rather than the
class's, which is how three classes in one file each got the same figure. Counting `@implementation
<name>` bodies, per class, with the categories that extend a class counted into it:

    RevenantMetalBlitEncoder      24   MTLBlitCommandEncoder8.m 14, 9(Options) 2, 10(Fence) 2, 12(Optimize) 4, 13(Surfaces) 2
    RevenantMetalBuffer           18   RevenantMetalBuffer.m 18
    RevenantMetalCommandBuffer    17   RevenantMetalQueue.m 17
    RevenantMetalComputeEncoder   11   MTLComputeCommandEncoder8.m 11
    RevenantMetalComputePipeline  12   MTLComputePipeline8.m 12
    RevenantMetalDepthStencil      3   RevenantMetalDepthStencil.m 3
    RevenantMetalDevice           36   RevenantMetalDevice.m 33, MTLHeap10(Heap) 1, MTLSharedEvent12(SharedEvent) 2
    RevenantMetalDrawable          9   RevenantMetalDrawable.m 9
    RevenantMetalEncoder          36   RevenantMetalEncoder.m 32, MTLHeap11(Heap) 2, MTLHeap13(HeapStages) 2
    RevenantMetalFunction         17   RevenantMetalLibrary.m 17
    RevenantMetalLayerState        1   RevenantMetalDrawable.m 1
    RevenantMetalLibrary           6   RevenantMetalLibrary.m 6
    RevenantMetalPipeline         11   RevenantMetalPipeline.m 11
    RevenantMetalQueue             3   RevenantMetalQueue.m 3
    RevenantMetalSampler           8   RevenantMetalTexture.m 8
    RevenantMetalTexture          45   RevenantMetalTexture.m 45

Three classes are assembled from more than one band object, and a row that names one file understates
them: `RevenantMetalBlitEncoder` from five (`8`, `9`, `10`, `12`, `13`), `RevenantMetalDevice` from three,
`RevenantMetalEncoder` from three. `RevenantMetalSampler` and `RevenantMetalTexture` are the two classes in
`RevenantMetalTexture.m` whose methods sum to the 53 the rows used to carry for each of them.

## The two rungs that certify "no release carries these names"

`xmake l tools/cache-index/first-rung.lua`, the 16 names and 3 controls in one run:

    RevenantMetalBlitEncoder NONE      RevenantMetalDevice  NONE      RevenantMetalLibrary NONE
    ... every one of the sixteen ...  NONE                 MTLDevice          8.0
                                               MTLCommandQueue   8.0
                                               CAMetalLayer      8.0

Three names from this very framework answer 8.0 in the same run, which is both the control that makes
the sixteen zeros mean something and the reason the file is called `ios80`.

`REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua RevenantMetal 6.1.3 4.3`, at both band ends:

    6.1.3  dyld_shared_cache_armv7   images 524  classes 11378  protocols 1171   RevenantMetal* 0 of each
    4.3    dyld_shared_cache_armv7   images 354  classes  7187  protocols  564   RevenantMetal* 0 of each
    CONTROL FAILED: no rung read carried a name beginning RevenantMetal

That last line is the tool refusing to certify its own zero, and it is right to. So the control is a
second run of the same tool, same reader, same two caches, on a prefix 11.0 carries:

    REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua MTLTexture 6.1.3 4.3 11.0

    6.1.3  images 524  classes 11378  protocols 1171   MTLTexture* 0
    4.3    images 354  classes  7187  protocols  564   MTLTexture* 0
    11.0   images 1258 classes 52768 protocols 8954   MTLTexture* 5 classes, 4 protocols
    control: 9 name(s) beginning MTLTexture found in this run, so a zero on another rung
             is the release's and not the reader's

The image and class counts are identical between the two runs, so the `RevenantMetal` run and the
`MTLTexture` run read the same caches with the same reader. The conclusion is stronger than the one the
rows needed: **iOS 6.1.3 and 4.3 carry no Metal class at all.** There is nothing there for the port's
stand-ins to shadow, which is the whole reason these objects exist.

THE ROWS CAME BACK, and the reason is the best thing in this page. Deleting them fixed a real
diagnostic and broke the 4.3 band in the same commit, and the second failure is the one that matters:
backports.lua:2014 `minimums()` reads `entry_of(listed, name)` and takes `entry.minimum` for every name
an object carries - and it never reads `entry.status`. So a row whose api is a port-internal name is
perfectly legal, and its minimum is the only thing it is read for.

Four objects every band carries depend on exactly that:

  MTLBlitCommandEncoder10.o   names _OBJC_CLASS_$_RevenantMetalSharedEvent -> RevenantMetalSharedEvent minimum 6.0
  MTLHeap11.o, MTLHeap13.o    name  _OBJC_CLASS_$_RevenantMetalHeap   -> RevenantMetalHeap          minimum 6.0
  MTLSharedEvent15.o          names _OBJC_CLASS_$_RevenantMetalSharedEvent

`RevenantMetalLibrary.o` was a fifth and is not one any more: it is where the definition of
`_RevenantAttributesFromFunction` and its two callers now are, one static in one object, so nothing
crosses an object boundary and the row has no placement left to do (v-bandtrap, "Give Metal's
vertex attributes and its heap class an object that is in every band" - it was
defined in `MTLReflection8.m`, an object of iOS 8.0's API, which a band from 8.0 does not link).

Without the rows the 4.3 band has no minimum for those four, cannot place them, and cannot link - while
6.1.3 stays GREEN, because everything they name is also carried at 6.0. A band-placement defect is
invisible at the higher rung. That is why both bands run.

So the rows are load-bearing and what made them look like noise is that they read like API. The status
they carry is absent, and it has to be: implemented needs a definition the band EXPORTS and hidden
visibility rules that out, ignored means the release carries the name and it never did, and owed is not
a landing state. absent plus a minimum is the only shape that satisfies minimums() and the registry test
at once.

THE ONE-LINE RULE IN backports.lua STAYS, because it guards a different set: the port objects that have
no row at all. A built Revenant-prefixed object with no row is not API of any release and should not be
reported as an unlisted build; every other unlisted build still is, since the guard is an extra conjunct
on the existing condition.

This page is deliberately NOT one of those. It describes port machinery, and it says so in its title.

## The sixteen rows, measured one name at a time (2026-10-02)

Every row of `registry/Metal/ios80classes.json` cited the same command with the same name in it:

    grep -c RevenantMetalDevice coordination/corpus/sdk-26.2-surface.tsv is 0

which is a measurement of `RevenantMetalDevice`, on fifteen rows about other names. A zero is the answer
for all sixteen, so the conclusion was right and the evidence was not this row's. Each row now names its
own:

    grep -c 'RevenantMetalTexture' coordination/corpus/sdk-26.2-surface.tsv

and the CONTROL is in the same run, because a reader who cannot see that the file is being read at all
cannot tell a real zero from a blind one. The same run over the same 145302 rows finds

    2606 rows naming MTL

and zero naming any `RevenantMetal`. The `absent` is therefore the surface's, not the reader's.

The method counts were wrong for eight of the sixteen as well, and the correction is what each row now
says - "N method definitions, at FILE (n), FILE (n)", counted from the source over the class's own
`@implementation` and every category written on it, so the reader's command is the one the number came
from:

| row | before | after | where |
| --- | --- | --- | --- |
| RevenantMetalBlitEncoder | 4 | 24 | MTLBlitCommandEncoder8.m (14), :9 (2), :10 (2), :12 (4), :13 (2) |
| RevenantMetalBuffer | 18 | 18 | RevenantMetalBuffer.m |
| RevenantMetalCommandBuffer | 20 | 17 | RevenantMetalQueue.m |
| RevenantMetalComputeEncoder | 11 | 11 | MTLComputeCommandEncoder8.m |
| RevenantMetalComputePipeline | 12 | 12 | MTLComputePipeline8.m |
| RevenantMetalDepthStencil | 3 | 3 | RevenantMetalDepthStencil.m |
| RevenantMetalDevice | 33 | 36 | RevenantMetalDevice.m (33), MTLHeap10.m (1), MTLSharedEvent12.m (2) |
| RevenantMetalDrawable | 10 | 9 | RevenantMetalDrawable.m |
| RevenantMetalEncoder | 32 | 36 | RevenantMetalEncoder.m (32), MTLHeap11.m (2), MTLHeap13.m (2) |
| RevenantMetalFunction | 23 | 17 | RevenantMetalLibrary.m |
| RevenantMetalLayerState | 10 | 1 | RevenantMetalDrawable.m |
| RevenantMetalLibrary | 23 | 6 | RevenantMetalLibrary.m |
| RevenantMetalPipeline | 11 | 11 | RevenantMetalPipeline.m |
| RevenantMetalQueue | 20 | 3 | RevenantMetalQueue.m |
| RevenantMetalSampler | 53 | 8 | RevenantMetalTexture.m |
| RevenantMetalTexture | 53 | 45 | RevenantMetalTexture.m |

Nothing else moved: status stays `absent` on all sixteen, and api, kind, introduced, minimum, source and
facts are byte-identical to the base revision. `minimum` is the field `minimums()` reads and never
`status`, so it is the placement record for both bands and is not this band's to touch.

`RevenantMetalLayerState` is the row where the two counts differ most and it is worth reading: the class
is one method in `RevenantMetalDrawable.m`, and the row that claimed ten was counting a neighbour's. That
is the whole failure this section records - a count that belongs to another object, next to a conclusion
that happens to be true.

## The sixteen are `absent`, and the status that was on them is the one claim the evidence refuses

A later revision set all sixteen to `ignored`, and the light guard answered with the rule that status
owes a field nothing else does - `modules/apple/backports.lua:1547-1548`, asking for an `effect` on
every non-implemented row, a `reason` on every status but `ignored`, and a `facts` page on `ignored`
and only on `ignored`:

    registry_test FAIL: the registry says: RevenantMetalBlitEncoder is ignored without a file of facts

The field was missing, so the light guard was right to refuse. The status was the defect, and adding
the field would have moved the failure rather than fixed it, which is why the status is what this
section settles.

**`ignored` asserts the opposite of what is true of these sixteen.** README.md:862-864 defines it as
the quietest answer: "the call reaches the release's own implementation, which does something else
with it, and nothing of ours is in the way". There has to be a release implementation to reach. The
tree's own shape for a real `ignored` row agrees - `registry/CoreGraphics/ios7.json`'s
`kCGColorSpaceSRGB` reads "the release exports the name and does not make a space from it". No release
ever exported `RevenantMetalDevice`, so there is nothing for the call to reach and the status cannot be
true of any of the sixteen.

`check_registry` refuses exactly that, and refuses it before a facts page is ever consulted -
`modules/apple/backports.lua:1942-1943` raises into the `missing` list, which `:2012` prints as

    listed as ignored because the release carries it, but the release does not: <every name>

so an `ignored` row naming a name no release carries fails the full gate whatever its `facts` says.
The light guard does not run that branch, which is the whole reason this could look like a missing
prose file for a whole series.

### Four measurements, each with the control that says the file was read

1. **No SDK header names one.** `grep -rl RevenantMetal` over
   `.../iPhoneOS16.4.sdk/System/Library/Frameworks/Metal.framework/Headers` names no file. Control, the
   same grep over the same directory for `MTLDevice`: `MTLBinaryArchive.h`, `MTLCaptureScope.h`,
   `MTLCommandEncoder.h`.
2. **No SDK surface row names one.** `grep -c <name> coordination/corpus/sdk-26.2-surface.tsv` is 0
   for each of the sixteen, by each row's own name and not by a neighbour's, and `grep -c Revenant` over
   all 145301 rows is 0 as well. Control in the same run: `grep -c MTL` is 3477.
3. **No held release cache carries one.** `grep -ho '^_OBJC_CLASS_\$_Revenant[A-Za-z]*'
   coordination/corpus/caches/*.tsv` is empty over 6.0, 7.0.1, 10.3.4, 12.0, 16.0 and 18.0 - which is
   the condition `carried_by_release` reports as false, the one `:1942` asks about. Controls in the
   same run: `grep -c '^_OBJC_CLASS_\$_MTL'` is 119, 171, 339 and 394 in 10.3.4, 12.0, 16.0 and 18.0
   and 0 in 6.0 and 7.0.1, and `grep -c '^_OBJC_CLASS_\$_WLSourceDevice' 18.0.tsv` is 3.
4. **The port builds all sixteen.** `grep -rl "@implementation <name>" packages/frameworks/apple-backports/Metal/*.m`
   names a file for every one of them - the table in the section above is the method counts, this is
   where each `@implementation` is written.

### Where the sixteen come from, by the file that defines them

Measured with the command in 4, one row per name, grouped by family rather than repeated per row:

| family | names | defined in |
| --- | --- | --- |
| the buffer | `RevenantMetalBuffer` | `RevenantMetalBuffer.m` |
| the queue and its command buffer | `RevenantMetalCommandBuffer`, `RevenantMetalQueue` | `RevenantMetalQueue.m` |
| the device | `RevenantMetalDevice` | `RevenantMetalDevice.m`, and methods on it in `MTLHeap10.m`, `MTLSharedEvent12.m` |
| the drawable | `RevenantMetalDrawable`, `RevenantMetalLayerState` | `RevenantMetalDrawable.m` |
| the render encoder | `RevenantMetalEncoder` | `RevenantMetalEncoder.m`, and methods on it in `MTLHeap11.m`, `MTLHeap13.m` |
| the library and its functions | `RevenantMetalFunction`, `RevenantMetalLibrary` | `RevenantMetalLibrary.m` |
| the depth stencil | `RevenantMetalDepthStencil` | `RevenantMetalDepthStencil.m` |
| the render pipeline | `RevenantMetalPipeline` | `RevenantMetalPipeline.m` |
| the texture and its samplers | `RevenantMetalSampler`, `RevenantMetalTexture` | `RevenantMetalTexture.m` |
| the blit encoder | `RevenantMetalBlitEncoder` | `MTLBlitCommandEncoder8.m`, `:9`, `:10`, `:12`, `:13` |
| the compute encoder | `RevenantMetalComputeEncoder` | `MTLComputeCommandEncoder8.m` |
| the compute pipeline | `RevenantMetalComputePipeline` | `MTLComputePipeline8.m` |

They are stand-ins for the `MTL` types, not Apple's names for anything: on a release with no GPU to
ask, these are what the port hands back where an application asks Metal for a device, a buffer or a
command queue. Measurement 1 is what makes them the port's own and measurement 4 is what makes the
rows load-bearing rather than hollow.

### Why `implemented` is unreachable either, and not for the reason this page used to give

Earlier revisions of this page, and the `reason` text of all sixteen rows, say these objects are
"compiled with hidden visibility so the band exports nothing under it". **That is not what happens in
this tree.** `modules/apple/backports.lua:457` says it outright - "Only C is compiled hidden" - and
`:500-501` adds `-fvisibility=hidden` only on the `else` of the `if objective_c` test, so a `.m`
object is compiled with default visibility like every other class a backport carries.

What actually keeps a `revenant` name out of the check is `internal_symbol`, `:193`, whose predicate at
`:213` is

    local bare = name:match("^_OBJC_%u*CLASS_%$_(.+)$") or name:match("^_(.+)$") or name
    return bare:startswith("revenant_") or bare:startswith("Revenant")

`exported_symbols` at `:263` drops every symbol that predicate claims, and `surface()` builds
`found.classes` out of `exported_symbols` at `:1452`. So `_OBJC_CLASS_$_RevenantMetalDevice` cannot reach
the set `check_registry` reads for "built" whatever visibility it was compiled with - which is why
`:2003` answered "listed as implemented, but nothing of that name is built" for a class that defines
36 methods. The outcome the earlier claim reached is right; the mechanism was not, and a reader who
went looking for `-fvisibility=hidden` on a `.m` file would not find it.

### What stays, and why the rows are not noise

`minimum` is 6.0 on all sixteen and is what `minimums()` reads - `:2059`, taking `entry.minimum` at
`:2068` through `entry_of`, never `entry.status`. Five objects every band places depend on exactly
that, as the section above records, so the rows stay whatever their status is: they are the only place
this tree records that these internal classes become linkable at 6.0. `status` is what the registry
test reads, `minimum` is what the band reads, and neither is a substitute for the other.

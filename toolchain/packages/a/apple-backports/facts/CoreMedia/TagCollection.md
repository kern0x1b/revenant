# `CMTagCollection` on a release whose SDK has no `CMTag`

`CMTag`, `CMTagCollection` and `CMTaggedBufferGroup` arrived at iOS 17. The SDK the toolchain resolves is
16.4, where `ls iPhoneOS16.4.sdk/.../CoreMedia.framework/Headers/ | grep -ci tag` is **0** and
`grep -rl CMTagCollectionCreate` over those headers finds nothing. So the family cannot be written
against that SDK at all: a source file cannot name a type it does not declare.

`CharonCMTag26.h` transcribes 26.2's own declarations under `#if !__has_include(<CoreMedia/CMTag.h>)`,
the way `CharonIntents262.h` and `CharonCKSyncEngine26.h` do: the `CMTagCategory` enum with its real
four-character codes, `CMTagDataType`, `CMTagValue`, the three-word `CMTag` struct, the
`CMTagCollectionError` enum, the filter and applier callbacks, and the three bridged references -
`CMTagCollectionRef` is `const struct CM_BRIDGED_TYPE(id) OpaqueCMTagCollection *`, so the
implementation is an Objective-C class, not a CFType.

## Rule R4 - the names this adds beyond the 16.4 headers

Every name below is declared by no header in the SDK the toolchain resolves
(`iPhoneOS16.4.sdk/.../CoreMedia.framework/Headers/` has no file whose name contains `Tag`), and by
26.2's three.

**Types and callbacks:** `CMTagCategory`, `CMTagDataType`, `CMTagValue`, `CMTag`, `CMTagCollectionError`, `CMTagCollectionTagFilterFunction`, `CMTagCollectionRef`, `CMMutableTagCollectionRef`, `CMTaggedBufferGroupRef`, `CMTagCollectionApplierFunction`

**Enumeration cases:**  - the whole of
`kCMTagCategory_*` (11), `kCMTagDataType_*` (5) and `kCMTagCollectionError_ParamErr`.

**Functions and constants carried here:** `CMTagCollectionAddTag`, `CMTagCollectionAddTagsFromArray`, `CMTagCollectionAddTagsFromCollection`, `CMTagCollectionContainsCategory`, `CMTagCollectionContainsSpecifiedTags`, `CMTagCollectionContainsTag`, `CMTagCollectionContainsTagsOfCollection`, `CMTagCollectionCopyDescription`, `CMTagCollectionCountTagsWithFilterFunction`, `CMTagCollectionCreate`, `CMTagCollectionCreateCopy`, `CMTagCollectionCreateMutable`, `CMTagCollectionCreateMutableCopy`, `CMTagCollectionGetCount`, `CMTagCollectionGetCountOfCategory`, `CMTagCollectionGetTags`, `CMTagCollectionGetTagsWithCategory`, `CMTagCollectionGetTagsWithFilterFunction`, `CMTagCollectionGetTypeID`, `CMTagCollectionIsEmpty`, `CMTagCollectionRemoveAllTags`, `CMTagCollectionRemoveAllTagsOfCategory`, `CMTagCollectionRemoveTag`, `kCMTagCategoryKey`, `kCMTagDataTypeKey`, `kCMTagInvalid`, `kCMTagValueKey`

`CMTagCollection17.m` carries **23 of the family's 34** functions: the create and copy family, the set algebra (`CreateUnion`, `CreateIntersection`,
`CreateDifference`, `CreateExclusiveOr`), `CopyTagsOfCategories`, `Apply`, `ApplyUntil`,
`CopyAsDictionary` and `CreateFromDictionary`, the
description, count, is-empty, the contains family, count-of-category, the three tag getters, the
filter pair, the mutators, add-from-collection and add-from-array, and the type id. **The set algebra, the category filter, the two appliers and the dictionary form are in the tree**,
held by 268 answers with none different, under AddressSanitizer. Three things the extension found, all
in the port:

- **`CMTagCollectionCopyAsDictionary` retained integers on the stack.** `CFDictionaryCreate` retains
  every key and value, and the values were `int` locals, so the release's own `objc_retain` was handed a
  stack address. That was the extension's segfault, and ASan named it:
  `#0 objc_retain`, `#1 CFDictionaryCreate`, `#2 CMTagCollectionCopyAsDictionary`,
  `#3 main tagcollectionimage.m:341`, `SUMMARY: SEGV … in objc_retain`. The values are `CFNumber`s now.
- **`CMTagCollectionCreateMutableCopy` made an empty collection**, discarding the source's tags, which
  is what made a union built on it lose the first collection entirely. The probe had a case for the
  mutable copy and never looked at its contents; it does now.
- **`CMTagCollectionCreateExclusiveOr` stacked the two differences**, which answers two tags where one
  of them is in both. The host answers the **symmetric difference**: a tag in one and not the other,
  counted once. Measured on a one-tag collection against a two-tag one sharing a tag with it, the host
  answers 0 for `Difference` and 1 for `ExclusiveOr`, and the port now agrees.

And two rules the host has that the header does not: a **category count of zero** is
`kCMTagCollectionError_ParamErr` rather than an empty collection, and **`ApplyUntil` takes the filter
function, not the void applier**, and answers the `CMTag` that satisfied the callback.

The mutation: taking the containment test out of `ExclusiveOr`'s second side gives
`268 checks, 3 different` and the suite exits 1; restoring it gives 0.

`CopyAsData` and `CreateFromData` are **in the tree and held by 356 answers, none different**; the
measurement that produced the layout is `.agent-work/runs/tagdata/`.

**The layout**, from the host's own bytes for collections of 0, 1, 2 and 3 tags and every data type:
a 44-byte header and **16 bytes per tag**.

```
uint32  the whole record's length, big endian
char4   "tgco"          - not compared by the host
uint32  20
char4   "tgin"          - not compared by the host
uint32  0              - must be zero
char8   "tag coll"
uint32  16 * (count + 1)
char4   "tgli"          - not compared by the host
uint32  0              - must be zero
uint32  the number of tags
per tag: uint32 the category as four characters, uint32 the data type, uint64 the value
```

The value is a plain big-endian 64-bit field: an `OSType` sits in its low 32 bits (`'vide'` is
`00000000 76696465`), a `Float64` is a big-endian double in all eight (`1.5` is `3ff8000000000000`),
and `0x0102030405060708` survives whole. Every collection round-trips through the host's own reader with
`0`.

**The answers, every one measured** over a whole record, eight truncations of it and each of its eleven
header fields flipped:

| record | host |
| --- | --- |
| shorter than the 44-byte header | `-15740` `kCMTagCollectionError_ParamErr` |
| the length field, the sub-length field, or the 20 | **`-12894`, which no SDK on this machine names** |
| either zero field non-zero | `-15747` `kCMTagCollectionError_InvalidTagCollectionDataVersion` |
| `tag coll` altered, or a count the length does not fit | `-15745` `kCMTagCollectionError_InvalidTagCollectionData` |
| the first byte of `tgco`, `tgin` or `tgli` flipped | **0 — the host does not compare the three magic tags** |

That last row is the one a port gets wrong by being careful: refusing a record whose magic does not match
would refuse records the host reads.

**356 checks, 0 different**, and the last two answers were as small as the first two suggested.

- **The value field starts at +8**, not +12: the per-tag record is category, data type, and then the
  8-byte value, with no reserved field. Reading it at +12 read the next tag's first four bytes and, for
  the last tag, past the end of the record - which is what lost the value. The *writer* put a zero at +8
  and the value at +12, which produces the same bytes for anything under 2^32, so the byte-for-byte
  comparison passed and hid it. The mutation puts the reader's offset back to +12 and gives
  `356 checks, 2 different` with the suite exiting 1.
- **The order of the two length checks.** A count the length cannot fit is `-15745` and is decided
  *before* the sub-length, which is the whole difference between a flipped count and a flipped sub-length.
- **And the length threshold is 8, not 44.** Measured over every length from 0 to 48: below 8 bytes the
  host answers `kCMTagCollectionError_ParamErr`, and from 8 up it answers `-12894`, because it reads the
  total length out of the first four bytes, finds a record that is not the one it was handed, and says so
  before it has looked at any of the rest.

`-12894` is returned as the number itself, with the conditions that produce it written above and in the
source, because **no SDK on this machine names it**: `grep -rn 12894` over the 26.2 CoreMedia headers
finds nothing, and the surrounding enums (`kCMTagCollectionError_*`, `kCMFormatDescriptionError_*`) stop
at -15749 and -12718. Inventing a name for it would be worse than carrying the number the host prints.

## One bug the differential found in the port

`charon_from` bridged the collection with a plain `__bridge` cast, which hands the reference to the
caller **without transferring ownership**: ARC released the collection at the end of the statement and
every later call through it was a use-after-free, which is the `objc_msgSend` fault at address `0x10`
the first probe died on. The reference types are `CF_RETURNS_RETAINED`, so the `+1` belongs to the
caller and `CFRelease` balances it - `__bridge_retained`.

## The rules, each measured on the host

- **The buffer rule.** `noErr` when the caller's buffer was large enough, `kCMTagCollectionError_
  ExhaustedBufferSize` only when tags were left over. For `GetTagsWithCategory` the count that decides
  is the number of tags **of that category**, not of the whole collection: a buffer of 1 against two
  MediaType tags is exhausted, 2 is fine, and 3 is fine and fills two.
- **`ContainsCategory`.** `true` for `kCMTagCategory_Undefined` whatever the collection holds - an
  *empty* collection contains it - and for every other category only when it holds tags of it. Measured
  over empty, one, three, five and six-tag collections and six categories including an unregistered
  `'zzzz'`, which is never contained.
- **`AddTag(kCMTagInvalid)`** answers `noErr`, not `InvalidTag`, and **stores it**: the count goes from
  0 to 1, and the tag sorts first because its category is 0. It is an ordinary tag with no data type.
  An earlier reading of this - "accepted and carries nothing" - came from a probe that checked only the
  status; the differential now checks the count on both sides, which is what caught it.
- **Adding a tag already held is a no-op**, so `AddTagsFromCollection` over a collection that overlaps
  leaves the size unchanged.
- **The description** is `CMTagCollection{`, a newline, one `{category:'<fourcc>' value:<v> <type>}` line
  per tag in the collection's own order, and a closing `}` with nothing after it. Measured byte for
  byte: 58 characters for one tag, ending `3e 7d 0a 7d` - `>`, `}`, newline, `}`. The value is
  `'xxxx'` for `OSType`, `0x…` for flags, plain decimal for `SInt64` and `%.2f` for `Float64`; the
  type names are `OSType`, `flags`, `int64` and `Flt64`; the Undefined category prints as `''`.

## The three serialisation keys, from the host's own symbols

| constant | value |
| --- | --- |
| `kCMTagCategoryKey` | `category` |
| `kCMTagValueKey` | `value` |
| `kCMTagDataTypeKey` | `flags` |

`flags`, not `dataType` - a value guessed from the name would have been wrong.

**How they are held.** Twice, and both bite. Each is compared to the port's own, reached through the
image handle, byte for byte; and each of the **port's** three keys is looked up in a dictionary the
**host** built from a real collection, which is the round trip the registry rows name - a key that differs
from the host's finds nothing there. The first version of that row claimed a round trip no test
performed, and `kCMTagDataTypeKey = "dataType"` still gave `212 checks, 0 different`; it now gives
**215 checks, 1 different**, and the suite exits 1.

## The differential

`tests/backports/host/coremedia7/tagcollectionimage.m` builds the port's file as its own image
(`-dynamiclib`), opens it with `RTLD_LOCAL | RTLD_FIRST` and reaches each of the 23 names through
`dlsym` on that handle, while its own calls reach the host's CoreMedia. Nothing is renamed, no system
header is touched, and `__typeof__(&name)` gives every binding the host's own type. The rule the
differential's first version broke is the one that matters: **a port's collection only ever goes to
the port's own entry points and a host's only to the host's** - handing the port's to the host's makes
CoreMedia interpret the port's object as its own.

**215 checks, 0 different.** The check can fail: replacing `return true` in `ContainsCategory` with
`return NO` gives **208 checks, 4 different**, and restoring it gives 0 again.

## Reuse

Nothing external is taken here. FFmpeg's libavformat/libavcodec and GStreamer are LGPL and were not
read; Media3 and Bento4 were not needed - the hvcC and the CMTag record are parsed from the format
descriptions Apple hands over, and every value is measured against the host's own CoreMedia.

## `CMTaggedBufferGroup` — the surface, measured, and not written

Fifteen functions, and `CMTaggedBufferGroupRef` is another bridged Objective-C class like
`CMTagCollectionRef`, so the port's is a class too. Its shape is two parallel CFArrays — tag collections
and buffers — which every accessor walks together, and the full surface, with the arity as the host's own
header gives it, is:

```
CFTypeID   CMTaggedBufferGroupGetTypeID(void)
OSStatus   CMTaggedBufferGroupCreate(allocator, tagCollections, buffers, out)
OSStatus   CMTaggedBufferGroupCreateCombined(allocator, taggedBufferGroups, out)
CMItemCount CMTaggedBufferGroupGetCount(group)
CMTagCollectionRef  GetTagCollectionAtIndex(group, index)
CVPixelBufferRef    GetCVPixelBufferAtIndex(group, index)
CVPixelBufferRef    GetCVPixelBufferForTag(group, tag, indexOut)
CVPixelBufferRef    GetCVPixelBufferForTagCollection(group, tagCollection, indexOut)
CMSampleBufferRef   GetCMSampleBufferAtIndex(group, index)
CMSampleBufferRef   GetCMSampleBufferForTag(group, tag, indexOut)
CMSampleBufferRef   GetCMSampleBufferForTagCollection(group, tagCollection, indexOut)
CMItemCount GetNumberOfMatchesForTagCollection(group, tagCollection)
OSStatus   FormatDescriptionCreateForTaggedBufferGroup(allocator, group, out)
OSStatus   FormatDescriptionCreateForTaggedBufferGroupWithExtensions(allocator, group, extensions, out)
Boolean    FormatDescriptionMatchesTaggedBufferGroup(desc, group)
```

Every `…Out` is `CF_RETURNS_NOT_RETAINED`, so the port must not retain what it hands back, and the two
`FormatDescriptionCreate…` are the three 17.0 `CMFormatDescription` rows the corpus lists, which take
this type and are therefore behind it.

**Measured now, from the host's own CoreMedia** (`.agent-work/runs/taggroup/m4`, three entries whose
tag collections are a subset chain — `cOne` = {video}, `cTwo` = {video, track}, `cThree` = {video, track,
gone} — and three pixel buffers):

| call | host |
| --- | --- |
| `Create` with one entry, with two, with three | 0, and the count is the number of entries |
| `GetTagCollectionAtIndex` / `GetCVPixelBufferAtIndex` / `GetCMSampleBufferAtIndex` at -1 and 3 | NULL, and a NULL sample buffer for a pixel-buffer entry |
| `CreateCombined` over two groups of three | 0, and the count is **6** — the concatenation |
| `Create` with 3 collections and 2 buffers | **-15780**, which no SDK here names either |
| `Create` with no entries, and with the two arrays the wrong way round | 0 |
| `FormatDescriptionCreateForTaggedBufferGroup` | 0, and `MatchesTaggedBufferGroup` is true for the group it came from and false for an empty one |
| `GetTypeID` | non-zero |

**The six lookups, and the coordinator's hypothesis is confirmed.** They answer the entry **only when
exactly one matches**: more than one match is NULL, and so is none, and `indexOut` is left as the caller
passed it in both cases. Measured with three disjoint collections, where every tag has one match, and
with a fourth entry that repeats a tag already in the second:

| query | matches | answer |
| --- | --- | --- |
| `video`, in one entry | 1 | index 0 |
| `audio`, in one entry | 1 | index 1 |
| `track7`, in one entry | 1 | index 1 |
| `track9`, in one entry | 1 | index 2 |
| `video`, in two entries | 2 | **NULL** |
| `ForTagCollection(c1)`, held by one entry | 1 | index 1 |
| `ForTagCollection(shared)`, held by one entry, though `shared` repeats `video` | 1 | index 3 |

So the two lookups count different things, and both are "the number of entries that carry every one of
the tags asked for": `ForTag` over the entries whose collection *contains* the tag, `ForTagCollection`
over the entries whose collection contains every tag of the wanted collection. The earlier chain result
fits exactly: {video} is carried by all three entries so 3 is too many, {video, track} by two, and
{video, track, gone} by one, which is why only the third was found.

**And one thing I cannot explain yet, which is why the six lookup functions are not written.** With that
chain of collections, `GetCVPixelBufferForTag(video)` is **NULL** although `video` is in all three
collections, `GetCVPixelBufferForTag(track)` is **NULL** although `track` is in two, and only `gone` — the
tag held by the third entry alone — returns index 2. `GetCVPixelBufferForTagCollection` behaves the same
way: NULL for `cOne` and `cTwo`, index 2 for `cThree`. Yet `GetNumberOfMatchesForTagCollection` answers
3, 2 and 1 for `cOne`, `cTwo` and `cThree`, which is the number of entries whose collection *contains*
the wanted one. So the counts and the lookups disagree in a way I cannot read off the header, and
`indexOut` is left at its input value on every miss rather than being set to something. Six of the
fifteen functions — the three `ForTag`, the two `ForTagCollection` and nothing else — cannot be written
from what is measured, and the nine that can are not in the tree because there is no differential yet.

**Not written, and the blocker is a design one, not a measurement one.** The fifteen need a way to
*hold* a `CMTag`, which is a three-word C struct with no lifetime of its own and cannot go into an
`NSArray` as an object, and a way to ask one collection whether it carries another's tags, which is
`CMTagCollectionContainsSpecifiedTags` - the port's own, in `CMTagCollection17.o`. Calling it from this
object is the trap in `charon/AGENTS.md` ("a C function shared between backport files"), and the rule
for it is to put it in a file that exports no API symbol of its own. A half-written attempt that kept
per-entry tag copies inside the group, and a `CMTagCollectionCopyAllTags` that no SDK declares, are in the
work area as `CMTaggedBufferGroup17.half-draft.m` and `CharonCMTaggedBufferGroup26.h.draft`; neither is
in the tree, and the invented helper is exactly what must not ship.

So the next step is a small one and it is a real design decision: either a `charon_`-prefixed no-export
helper carrying `CMTagCollectionContainsSpecifiedTags` and the tags of a collection as a `NSArray` of
`NSValue`s, or `CMTagCollectionCopyAllTags` added to the collection's own object. The measurements are
done; the fifteen are not blocked on anything else.

## A group cannot hold a host collection, and that is the SDK, not the group

Measured, not inferred. `charon_copy_all_tags` bridges a `CMTagCollectionRef` to `CharonCMTagCollection`
and messages it, which works for a collection this package made and fails for one CoreMedia made:
`-[__NSCFType charon_copyAllTags:]: unrecognized selector`. The other route - the host's own
`CMTagCollectionGetTags` - is the port's symbol on the 16.4 SDK, so the port cannot call it either.

The consequence for the differential is that **each side's group must be built from that side's own
collections**, and a mixed group is not constructible here at all. The case was written, run, and removed
rather than left to abort the suite; a caller on 6.1.3 can only hold port collections anyway, so the limit
does not reach the port's users, but it is the reason the probe's arrays are per side.

## The group's format description and the two sample-buffer functions

Five rows, measured in `cmtag-fixtures/taggedgroup-measure.m` with its answers beside it (commit
`2fbdb758c`) and held by `tests/backports/host/coremedia7/taggedgroupdescription.m`: **28 checks, 0
different**, under AddressSanitizer.

**What a format description is here: the platform's own.** `CMFormatDescriptionCreate` at media type
video and media subtype `'tbgr'` — measured `1952606066` — with the group's per-entry tag collections in
its extensions dictionary. Its `CFTypeID` is `CMFormatDescriptionGetTypeID()`'s, which is what the host's
own answer measures, so a caller gets something the platform understands and no new opaque type exists.

**The payload is `CFData`, and that was not the first shape tried.** An array of the collection objects
was, and 16.4 refuses it: `CMFormatDescriptionCreate` answers `kCMFormatDescriptionError_InvalidParameter`
(`-12710`) for an extensions dictionary holding bridged Objective-C values, while the same call for a NULL
group — the same dictionary with no such value in it — answers `0`. The modern framework that took the
measurement tolerates them, so this is the old platform's constraint and the port is the one that has to
live with it. What travels instead is, per entry in order, a `CMItemCount` and that collection's tags as
they sit in memory: a `CMTag` is three machine words with no lifetime of its own, so copying its bytes
copies all of it.

**`Matches` compares the per-entry collections in order and by content, and nothing else.** The group it
came from is 1; the same tags over different buffers is 1, so buffers are not part of it; the same entry
*sizes* over different tags is 0, so it is not a count; two entries is 0 and NULL is 0. The comparison is
the port's own tag equality over each collection's sorted storage, because `CFEqual` has nothing to say
about a bridged Objective-C class.

**A NULL group is not a failure.** The host answers `0` and hands back a real description with the same
subtype that matches nothing, and the reason is visible in the port's own code: there are no entries to
record, so the payload is empty. It is a description of nothing rather than an error, and it releases
without an AddressSanitizer report.

**The sample buffer is a real one and the group rides on it as an attachment.** `CMSampleBufferCreate`
with one sample over an empty `CMBlockBuffer`, the given timing kept (measured `1/2` and `2/1`),
`numSamples 1`, data ready; then `CMSetAttachment` under
`kCMAttachmentMode_ShouldNotPropagate`. **Retention follows CF ownership and is not a decision made
here:** the attachment retains the group and the group is released with the buffer, which is why the
differential runs under AddressSanitizer — a missing retain or an over-release is a report there rather
than a crash later. `CMSampleBufferGetTaggedBufferGroup` hands back the same pointer, and NULL for a
sample buffer built over an image buffer, which is what makes the pair specific to this kind.

**Two mutants, each red for its own case.** Comparing counts instead of tags flips *same entry sizes over
different tags* from 0 to 1 and nothing else. Never attaching the group flips *the buffer hands the same
group back* and nothing else.

**The 26.0 one is declarable.** `…WithExtensions` takes a plain `CFDictionaryRef` and needs no type 16.4
lacks, so it compiles for `armv7-apple-ios6.0` against the 16.4 SDK and owes no `crutches.md` entry.

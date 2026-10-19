# The metadata objects: groups, filters, value requests, body objects, and AVMetadataItem's members

Seventeen corpus rows, the rest of the metadata family after the constant families in
[MetadataKeySpaces.md](MetadataKeySpaces.md) and [CoordinatedPlaybackReasons.md](CoordinatedPlaybackReasons.md).
Eleven classes and six members on three of them, carried with a Charon-prefixed designated initializer
each, in the form `CharonHomeKitConstruction.h` uses: `objc_method_family(init)` puts a port-owned
selector in the `init` family, because clang decides the family from the attribute and not the spelling.

## The measurement that changed the design of one of them

## AVMetadataItemFilter is BOTH: the class is defined, and the 7.0 members are a category

This took two corrections to get right, and the first one was a real gate failure.

The corpus row is the 7.0-era class and `introduced` reads 7.0. Searching this class's own symbols -
`_OBJC_CLASS_$_AVMetadataItemFilter` and its metaclass - in the exports of **all fifteen held rungs**
(4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and 8.0 armv7; 8.1.3, 8.2 and 8.4.1 armv7s; 9.3.6 armv7; 10.0.1,
11.0 and 12.0 arm64; 16.0 arm64e), with `_NSFileSize` as a planted control, the first held rung that
exports it is **7.0**. (An earlier note in this file said 8.0, and a commit said 8.4.1: both were
searches that had skipped the 7.x rungs, which is what a partial ladder looks like.)

That makes the class **needed** below 7.0 and **shadowed** from 7.0 up, and a category alone cannot do
both: a category compiles to no `_OBJC_CLASS_$_` symbol, so on a 6.1.3 band `nm -gU` finds nothing of
the name, `check_registry` counts the row's `built` false, and the band build stops with "the registry
does not describe what the backports carry: listed as implemented, but nothing of that name is built".

So there are two objects, and the split is not tidiness - it is what makes each band work:

| object | what it is | `nm -gU` | bands |
| --- | --- | --- | --- |
| `AVMetadataItemFilter.m` | the CLASS, under Apple's own name, with the list attached and the header's own `+metadataItemFilterForSharing` | `_OBJC_CLASS_$_AVMetadataItemFilter` and its metaclass | 6.1.3 and 4.3, where the release has no such class; dropped from 7.0 up |
| `AVMetadataItemFilter7.m` | a CATEGORY holding the three 7.0 members | **no class symbol at all** | every band, so the members land on whichever class is in the binary |

Had the 7.0 members ridden in the class object, the class symbol would have been dropped on every 7.0+
band and the port's members with it. `AVTimedMetadataGroup4.m` is the same shape and is the precedent
for a category-only object.

**What the differential cannot see, and says so.** The host has this class, so the host's table and the
port's are compared on the RELEASE's class in a binary where the port's own class is renamed away - the
probe cannot see a 6.1.3 band by construction, and no differential against this host can. What the
table does show is that the category's three members are callable and agree on whichever class is
present. What the gate will show on a 6.1.3 band is `nm -gU` over the port's objects finding
`_OBJC_CLASS_$_AVMetadataItemFilter` in `AVMetadataItemFilter.o` and nothing in
`AVMetadataItemFilter7.o`, which is quoted in the commit and is the only evidence there can be without
building the whole package.

`AVTimedMetadataGroup` is the same case and was found the same way, by the review's own release-split:
the **4.3** armv7 rung exports it and `AVMutableTimedMetadataGroup` with it, so the two members the
corpus carries are a **category** in `AVTimedMetadataGroup4.m` and the port defines neither class.
`AVMetadataGroup`, `AVDateRangeMetadataGroup`, `AVMutableDateRangeMetadataGroup` and
`AVMetadataItemValueRequest` are first exported by the 9.3.6 held rung, and the five body-object
classes by 16.0, so those are the two objects the port does define.

What the release's class does not have is the 7.0 spelling: on this build
`+metadataItemFilterWithIdentifiers:`, `-initWithIdentifiers:` and `-identifiers` are gone and the
member is `allowList`. The port carries both spellings over **one** stored list, so an application
written for 7.0 and one written for a current release get the same array.

## Every row, and what carries it

| row | first release that exports it |
| --- | --- |
| `AVMetadataItemFilter` | the **8.4.1** release exports it |
| `+[AVMetadataItem metadataItemWithPropertiesOfMetadataItem:valueLoadingHandler:]` | no held release exports it |
| `+[AVMetadataItem metadataItemsFromArray:filteredByIdentifier:]` | no held release exports it |
| `+[AVMetadataItem metadataItemsFromArray:filteredByMetadataItemFilter:]` | no held release exports it |
| `-[AVTimedMetadataGroup copyFormatDescription]` | no held release exports it |
| `-[AVTimedMetadataGroup initWithSampleBuffer:]` | no held release exports it |
| `AVDateRangeMetadataGroup` | no held release exports it |
| `AVMetadataBodyObject` | no held release exports it |
| `AVMetadataCatBodyObject` | no held release exports it |
| `AVMetadataDogBodyObject` | no held release exports it |
| `AVMetadataGroup` | no held release exports it |
| `AVMetadataHumanBodyObject` | no held release exports it |
| `AVMetadataItem.startDate` | no held release exports it |
| `AVMetadataItemValueRequest` | no held release exports it |
| `AVMetadataSalientObject` | no held release exports it |
| `AVMutableDateRangeMetadataGroup` | no held release exports it |
| `AVMutableMetadataItem.startDate` | no held release exports it |

## How the behaviour is compared, and what the comparison can and cannot settle

One probe, linked twice: plain, where every name is Apple's own, and with the port's objects and the
port's own class names renamed, in the same binary. The two tables are joined on the key and every row
falls into one of three classes:

- **must match** - the host answers it and the port answers it, and the two must agree. A difference is
  a failure unless `ALLOWANCES` names it. `ALLOWANCES` holds 55 keys, of which a run exercises 36 -
  counted by grepping the `ALLOWED` lines a run prints, not by reading the dict - and each is a
  difference in **Apple's** build.
- **`~` port-only** - a row about the port's own construction, which Apple has no factory for, so
  there is nothing to compare it to. These are held against the **unmutated baseline**, and that is
  where a mutation of a `charon_` initializer shows up. A run prints 24 `~CONSTRUCTED` rows and 9
  `~DIAG` rows.
- **answers less** - the host answers it and the port does not. Always a failure. It is 0.

**A check no mutant can break is not a check**, and the first version of this harness had five mutants
and all five passed it. Two reasons, both measured and both fixed:

1. The runner judged a mutation by "nothing differs", so a mutation that made the port agree *more
   closely* with the host - which is what the `filterNil` mutant did - was reported as a pass. It now
   judges against the unmutated baseline and requires that a mutation **turned a right answer wrong**
   and that **nothing moved toward the host**.
2. Most of the mutated rows sat in `ALLOWANCES`, where a change is invisible by construction. The list
   is now short, and no mutant aims at one.

| mutant | the line it changes | noticed | control |
| --- | --- | --- | --- |
| `bodyinit` | the body's `-init` default `objectID` | `changed=4 right-then-wrong=4` | green |
| `filterlist` | the filter category's stored list | `changed=2 right-then-wrong=2` | green |
| `grouprange` | the group initializer's stored range | `changed=3 right-then-wrong=3` | green |
| `copyeq` | `-[AVMetadataGroup isEqual:]` | `changed=1 right-then-wrong=1` | green |
| `handler` | the value request's handler call | `changed=1 right-then-wrong=1` | green |

## Three bugs the mutants and the rows found

- **`-charon_initWithItems:timeRange:` is an initializer, and the row called it twice on one object.**
  The second call re-initialised the receiver, so "does a group equal a different group" compared an
  object with itself, answered `YES`, and the `copyeq` mutant had nothing to break. The diagnosis is
  kept as rows: `~DIAG made items` and `~DIAG other items` read `array(2)` and `array(1)`, and
  `~DIAG made isEqual: reaches the port's implementation` reads **yes** with the Apple row reading no -
  so the port's `-isEqual:` was reached and was correct all along, and the row was wrong.
- **`-respondsToSelector:` sent to a Class asks the metaclass**, which does not carry the instance
  methods, so four of the five construction blocks ran zero rows.
- **`set -e` killed the script the moment the join returned 1**, so no verdict printed and every mutant
  looked like a silent exit 1.

## What this does not close

Nothing here is produced by a detector: `AVCaptureMetadataOutput` is a separate row and is not carried,
so a body object is made only by this port's own initializer. The reader and writer adaptors that would
feed a group from a real asset, and the metadata loader that would answer a value request, are separate
rows in [AVFoundationOwed.md](AVFoundationOwed.md).

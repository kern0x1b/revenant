# The URL resource keys and their neighbours, with the values real releases shipped

45 exported string constants of Foundation that arrived between iOS 7 and iOS 18: the file protection
group, the volume and shared-item keys, the iCloud user defaults notifications, the URL resource keys
of 8.0, the attribute names of 15.0, the credential storage key of 7.0, the one stream service type,
and the six that no release below 18.0 exports.

That count is the registry facts-rows count (removed), run over <registry-root> for `facts/Foundation/NSURLResourceKeyStrings.md 7.0-18.0`: the rows whose `facts` is this file and whose `introduced` is in `[7.0, 18.0)`. It reads **44**
on `6fcdc631b` and **45** from `568b5f846` on - the same rows on those two, and all `implemented` on
each - and it is 45 on `820a21f76`, on `b721b20b2`, on `d12d2fd9a` and on the tip of the series that adds
this paragraph. So the `44` this file's first line carried was **right when it was written**: one of the
fifteen constants the earlier `foundation-absent-2` answered -
`NSFileProtectionCompleteWhenUserInactive`, introduced 17.0 - is inside this window and carries this
file's `facts` pointer from that commit, and before it that row was `absent` with no pointer at all. The
walk is where that sentence comes from, one run per tree:

```
6fcdc631b   44 rows point at facts/Foundation/NSURLResourceKeyStrings.md with introduced in [7.0, 18.0)   implemented: 44
568b5f846   45 rows point at facts/Foundation/NSURLResourceKeyStrings.md with introduced in [7.0, 18.0)   implemented: 45
6fcdc631b   NSFileProtectionCompleteWhenUserInactive  introduced 17.0  status absent        facts (none)
568b5f846   NSFileProtectionCompleteWhenUserInactive  introduced 17.0  status implemented  facts/Foundation/NSURLResourceKeyStrings.md
```

Source: the SDK 26.2 headers for the declarations and their availability; for every value, the dyld
shared cache of a real release, read through `tools/corpus/cache-value.lua` over the project's own
cache reader. **No value is taken from a header comment, from the host framework, or from the
identifier's own spelling** — and the three that differ from their own name below are the reason.

## The values, as the releases shipped them

| the constant | the value a release holds | read from |
| --- | --- | --- |
| `NSPresentationIntentAttributeName` | `NSPresentationIntent` | 16.0 |
| `NSReplacementIndexAttributeName` | `NSReplacementIndex` | 16.0 |
| `NSUserDefaultsSizeLimitExceededNotification` | `com.apple.CFPreferences.byteCountLimitReached` | 9.3 |
| `NSStreamNetworkServiceTypeCallSignaling` | `kCFStreamNetworkServiceTypeCallSignaling` | 10.0.1 |
| `NSURLIsApplicationKey` | `_NSURLIsApplicationKey` | 9.0 |
| every other one here | its own name | the release in the table below |

Five of the 45 are not the string their own name suggests, and one of them is not even an
`NSURL…` name: the notification a user defaults posts when the store is full is a
`CFPreferences` name, and the attribute names of 15.0 drop the `AttributeName` ending. Guessing any
of these from the header would have been wrong, which is the whole reason they were read.

## Which release first exports each of them, and where the port stops carrying it

Measured over every held release the machine has a cache for — 3.1.3 to 9.3.6 on armv7, 10.0.1 and
10.3.4 on armv7s, 10.0.1 to 12.0 on arm64 and 16.0 and 18.0 on arm64e — by asking every image of
each release whether it exports the symbol. The first release that does is where the release itself
carries the constant, and the port's object must be out of the band from there on: a band that both
defines and links a symbol the release has is a duplicate at load.

| first release that exports it | the keys | the port's `maximum` |
| --- | --- | --- |
| 7.0 | `NSURLCredentialStorageRemoveSynchronizableCredentials` | 6.1.6 |
| 8.0 | the URL resource keys of 8.0, `NSThumbnail1024x1024SizeKey`, the two iCloud keys | 7.1.2 |
| 8.3 | `NSURLUbiquitousItemIsSharedKey`, the two `…SharedItemRole…` | 8.2 |
| 9.0 | the five `NSURLFileProtection…`, `NSURLIsApplicationKey`, `NSURLUbiquitousSharedItemOwnerNameComponentsKey` | 8.4.1 |
| 9.3 | the three `NSUbiquitousUserDefaults…`, `NSUserDefaultsSizeLimitExceededNotification` | 9.2.1 |
| 10.0.1 | the volume keys, the `…SharedItem…` permissions and roles, `NSURLCanonicalPathKey`, `NSStreamNetworkServiceTypeCallSignaling` | 9.3.6 |
| 16.0 | the three attribute names, the progress file operation kind | 12.0 |
| 18.0 | `NSURLFileProtectionCompleteWhenUserInactive`, `NSURLVolumeMountFromLocationKey`, `NSURLVolumeSubtypeKey`, `NSURLVolumeTypeNameKey`, `NSURLFileIdentifierKey`, `NSURLDirectoryEntryCountKey` | 16.0 |

Three of these are not what the SDK's availability suggests, and they are the reason the ladder was
walked rather than read off the headers: `NSURLUbiquitousItemIsSharedKey` is a 10.0 API whose
*symbol* a release exports from **8.3**; `NSURLFileProtectionCompleteWhenUserInactive` is a 10.0 API
that **18.0** is the first to export, and `NSURLVolumeMountFromLocationKey`, `NSURLVolumeSubtypeKey`,
`NSURLVolumeTypeNameKey`, `NSURLFileIdentifierKey` and `NSURLDirectoryEntryCountKey` with it. A
`maximum` read off the availability would have put the port's own definition into a band where the
release already has the symbol.

## One object per group

The eight files are one release group each, and that is the rule rather than taste: an object stays
in a band while any of its entries is in range, so a file holding the 9.0 group and the 9.3 group
would still be compiled in the 9.3 band, where the release exports the 9.0 symbols itself, and
define them a second time. `tools/release-split.lua` measures the same thing from the objects
themselves after a build.

## What these keys are for, on the port's own release

A key is a name, and a name answers nothing by itself: what a key is worth is
`-[NSURL getResourceValue:forKey:error:]` and `-[NSURLResourceValues …]` answering for it. The keys
above are carried whole so that an application of 2024 links and runs; the reading of them is the
existing `NSURLResourceKeys14.m` and `NSURLVolumeKeys.m`, and the rows for the *values* — which of
these a 6.1.3 file system can answer at all — are separate rows, measured separately. The
protection keys, the volume keys and the canonical path are readable on 6.1.3 through `getattrlist`
and `statfs`; the iCloud container's own state (whether an item is shared, who its owner is, whether
a download was asked for) is the `cloudd` daemon's state, and 6.1.3 has no API that reports it, so
those keys answer the documented "no value" rather than a guess.

## The fifteen that arrived after the SDK this package builds against

The build resolves `revenant@iphoneos-sdk` to 16.4, and these fifteen arrived after it: eleven
calendar identifiers and the two sync-control keys of 26.0, the cookie attribute of 18.2 and the file
protection level of 17.0. None of them has an `extern` declaration in that SDK, so
`Foundation/RevenantFoundationIdentifiers.h` declares the three groups, each gated on the version
macro the SDK spells (`__IPHONE_17_0`, `__IPHONE_18_2`, `__IPHONE_26_0`, none of which 16.4 defines),
and three objects carry the values, one per release group, for the reason "one object per group"
above.

Their values were read out of the **host's own Foundation** by `dlsym` rather than out of a release's
shared cache, and that is a departure from the method the rest of this file uses, so it is named
here rather than left to be discovered: no `dyld_shared_cache` is held on this machine (none under
`~/.xmake/packages/i` or `~/.revenant/cache`), and the ladder has no release new enough to export
thirteen of the fifteen. The instrument is in the tree and it is the one this file's own test for a
wrong value needs — `tests/backports/host/foundation-constants/` asks the host for every name the
package carries, compares it with the port's, and mutates each value in turn to show the comparison
notices that constant (15 mutants, 15 noticed, 0 failures). What the host's answer is not is a
*release's* answer, and the difference is exactly the gap the ladder would close: the reading below
is the host's, and a release that spelled one of these differently would be caught only by a ladder
read.

| the constant | the value the host's Foundation exports |
| --- | --- |
| `NSCalendarIdentifierBangla` | `bangla` |
| `NSCalendarIdentifierDangi` | `dangi` |
| `NSCalendarIdentifierGujarati` | `gujarati` |
| `NSCalendarIdentifierKannada` | `kannada` |
| `NSCalendarIdentifierMalayalam` | `malayalam` |
| `NSCalendarIdentifierMarathi` | `marathi` |
| `NSCalendarIdentifierOdia` | `odia` |
| `NSCalendarIdentifierTamil` | `tamil` |
| `NSCalendarIdentifierTelugu` | `telugu` |
| `NSCalendarIdentifierVietnamese` | `vietnamese` |
| `NSCalendarIdentifierVikram` | `vikram` |
| `NSHTTPCookieSetByJavaScript` | `SetInJavaScript` |
| `NSFileProtectionCompleteWhenUserInactive` | `NSFileProtectionCompleteWhenUserInactive` |
| `NSURLUbiquitousItemIsSyncPausedKey` | `NSURLUbiquitousItemIsSyncPausedKey` |
| `NSURLUbiquitousItemSupportedSyncControlsKey` | `NSURLUbiquitousItemSupportedSyncControlsKey` |

Twelve of the fifteen are not what their own name suggests, which is the whole reason they were read:
the eleven calendar identifiers hold the lower-case calendar name the release uses rather than the
`NSCalendarIdentifier…` spelling, and `NSHTTPCookieSetByJavaScript` holds `SetInJavaScript`. Writing
the own name for any of the twelve would have been a value no release ships, and the mutation in
that suite is what notices it.

### The band of the one whose ladder reading disagrees with its annotation

`NSFileProtectionCompleteWhenUserInactive` is a 17.0 API by its availability, and the ladder puts the
first release that exports the symbol at **18.0** (`tools/release-split.lua` over the held caches,
`_NSFileProtectionCompleteWhenUserInactive  18.0`), so the port's `maximum` is **16.0** — the band
below 18.0 — and not 17.0. That is the same shape this file already records for
`NSURLFileProtectionCompleteWhenUserInactive` and the five names beside it, and it is the one case in
this file where `maximum` is *below* `introduced`: The registry maximum check (removed) compares the two and
reports this row, correctly, because its rule is the availability and the ladder's answer is the
band. The rule and the ladder are both right about different things, and which one a given row owes
its `maximum` to is the question the table above answers.

## How many rows this family still owes, counted by a script in the tree

The count a report quotes has to be repeatable, and the number that circulated for this series
("131 absent Foundation rows, 116 remain") does not reproduce: it was read off a corpus export, and
the export's framework column is empty for every registry file whose JSON carries no `framework` key,
so counting by framework there silently drops rows. A registry walk (removed) counts the registry
files themselves, by path — `registry/<Framework>.json` and `registry/<Framework>/<part>.json`, the two
shapes the registry README gives — and refuses a path with no registry under it rather than printing
zero of zero.

```
The first block is written by the registry walk's `--write-facts` mode (removed), so it is this tree and cannot
be anything else; the second names the tree it was measured on, and `git archive 6fcdc631b
packages/a/apple-backports/registry` reproduces it.

<!-- framework: Foundation -->
<!-- count:begin -->
```
Foundation   110 absent   9 ignored   792 implemented   48 inert      (16271 rows, 3283 absent, over 65 frameworks)
```
<!-- count:end -->

Two historical pairs, each naming the tree it was measured on and reproducible with
`git archive <tree> packages/a/apple-backports/registry`:

```
# output of the removed registry walk, as measured:
Foundation                 131         9           771         48               131
16269 rows, 3355 absent, over 65 frameworks

# output of the removed registry walk, as measured:
Foundation                 116         9           786         48               116
16269 rows, 3340 absent, over 65 frameworks
```

So the fifteen took Foundation from `131 absent / 771 implemented` at `6fcdc631b` to
`116 / 786` at `e641e4d37`, and nothing else moved between those two trees. The block at the top of
this section is the tree this file is in and says `110 / 792`, which is the same script reading a tree
that has moved since `e641e4d37`: this file's own family has taken the six item-provider rows, and
another band has landed rows of its own. A number that said "this tree" here would have been wrong
within a day, which is why the live one is generated and these two name their trees.

## What the release ladder can and cannot answer for these fifteen

The ladder on this machine holds 50 rungs, the newest 18.0, and nothing between 12.0 and 16.0, so a
name it dates at 18.0 is an upper bound and not a measurement of 18.0. Read through
`tools/release-split.lua` over an object that defines the names, with the two controls a reading needs
— a name a held rung exports, and a planted name no release has:

```
_NSFileProtectionCompleteWhenUserInactive                  18.0
_NSURLFileProtectionCompleteWhenUserInactive               18.0
_NSCalendarIdentifierRevenantPlantedNoSuchName               none
_NSHomeDirectory                                           3.0        (the control: a rung this machine holds exports it)
```

So: the thirteen names of 26.0 and the one of 18.2 are exported by **no** rung this machine holds —
`none` is the answer, and a planted name reads the same `none`, which is what makes it a reading rather
than a silence. The host's own Foundation is therefore the only oracle for fourteen of the fifteen,
and for the two 17.0 names the ladder gives an upper bound (18.0) while the availability gives 17.0,
which is the sibling `NSURLFileProtectionCompleteWhenUserInactive`'s own `maximum` in this tree and the
value `NSFileProtectionCompleteWhenUserInactive` now carries. The registry maximum check (removed) is green on
this tree with that value:

<!-- maximum -->
<!-- maximum:begin -->
```
16718 rows, 252 with a maximum, 0 not at the release that has the API, 99 members of a class the backports carries this rule does not judge
```
<!-- maximum:end -->

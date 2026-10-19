# CoreSpotlight, iOS 9

`CSSearchableIndex`, `CSSearchableItem`, `CSSearchableItemAttributeSet`, `CSSearchableItemActionType`
and `CSSearchableItemActivityIdentifier` are strong-imported LOAD-FAIL symbols for provenance and
telegram, two applications of the corpus. A hard-linked class or C symbol that is absent kills the
application at launch — dyld fails to bind the non-weak import — so the classes and constants are
carried, not marked absent.

The functions live in `libCoreSpotlightBackports.dylib`, built with the `corespotlight` config,
because CoreSpotlight is the only framework it loads besides Foundation.

## The earlier verdict, retracted

An earlier pass of this port answered every write with `CSIndexErrorCodeIndexingUnsupported` and
called `isIndexingAvailable` a `documented-absent` seam, on the reasoning that iOS 6.1.3's own
`SPSpotlightManager` is a pull model and `CSSearchableIndex` is a push model, and bridging one onto
the other would be guessing at an undocumented private protocol. That reasoning does not hold: a
private, undocumented protocol is work, not a wall, the same way the Swift runtime and Metal-over-ES2
were work. The write seam is reversible, and this pass reverses it.

## What the device has

An iPhone 4S and an iPad 2 on iOS 6.1.3 have no CoreSpotlight framework and no on-device Spotlight
index an application can write to in Apple's own sense of the word. What they do have:

- `Spotlight.framework` (`/System/Library/PrivateFrameworks/Spotlight.framework/Spotlight`), a
  private framework carrying exactly one Objective-C class, `SPSpotlightManager`. Its full method
  and property list, read from `__objc_methname`/`__objc_classname` of the extracted binary:
  `init`, `dealloc`, `alloc`, `+sharedConnection`, `+defaultManager`, `+sharedManager`,
  `-startRecordUpdatesForApplication:andCategory:`, `-endRecordUpdatesForApplication:andCategory:`,
  `-requestRecordUpdatesForApplication:category:andIDs:`,
  `-_processIdentifiers:forApplication:andCategory:`, `-notifyIndexer`,
  `-appModifiedRecordIDs:forCategory:`, `-application:modifiedRecordIDs:forCategory:`,
  `-eraseIndexForApplication:category:`, plus the record-field names `_displayID`, `external_id`,
  `title`, `subtitle`, `summary`, `aux_title`, `aux_subtitle`, `category`, `content`. Objective-C
  type encodings confirm two-object-argument methods (`v16@0:4@8@12`, e.g.
  `startRecordUpdatesForApplication:andCategory:`) and three-object-argument methods
  (`v20@0:4@8@12@16`, e.g. `application:modifiedRecordIDs:forCategory:`); every argument is `@`
  (an object), so no primitive width can be wrong at the `objc_msgSend` boundary. `__text` is 0x1d4
  bytes: most of these selectors are thin forwarders to two shared internal C entry points at
  `0x366a1d78`/`0x366a1d88`, so the substantive per-selector logic (how a category's registration is
  kept, how a pull answer is actually assembled from the `_displayID`/`title`/... record fields)
  lives past those stubs and was not traced further — the class surface, not the control flow inside
  it, is what this port bridges to.
- `Search.framework` (`/System/Library/PrivateFrameworks/Search.framework/Search`), which owns
  `-_loadSearchBundles`, backed by `-contentsOfDirectoryAtPath:error:` reading each bundle's
  `principalClass` — a real directory scan, not a hardcoded table.
- Exactly eleven search bundles on the device, all Apple's own, found by listing the shared cache:
  `/System/Library/SearchBundles/{AddressBook,Application,Extended,MobileCal,MobileMail,MobileNotes,
  Reminders,TopHits,VoiceMemos,iPod}.searchBundle` and
  `/System/Library/Spotlight/SearchBundles/SMSSearch.searchBundle`. None of them is a general,
  per-installed-app entry point.
- `Application.searchBundle`'s own extracted binary names its source file as
  `SPApplicationDatastore.m` and carries the string `categoryForDomain:` — it matches installed
  application names on its own, independent of `SPSpotlightManager`'s category registration.

Confirmed by extracting both frameworks and both search bundles named above out of the armv7 shared
cache of iOS 6.1.3 with `modules/apple/dyld.lua`'s `extract` and reading their `__objc_methname`,
`__objc_classname` and `__cstring` sections with `strings`/`otool -l`; `CSSearchable`,
`MobileSpotlight` and `CoreSpotlight` are exported by none of the release's images at all.

## The `extract` bug this pass fixed

`modules/apple/dyld.lua`'s `extract` failed with `bad argument #2 to 'pack' (unsigned overflow)` on
`Spotlight.framework`, and would fail identically on any image whose `LC_DYLD_INFO_ONLY` carries a
zero-length field (`weak_bind_size` or similar) at a nonzero offset. The bounds pass that computes
`first`/`last` (and so the relocation `shift`) already excludes zero-length fields
(`if offset > 0 and length > 0`); the rewrite pass that applies `shift` did not, so a zero-length
field's stale, out-of-[first,last) offset was shifted into a huge negative number and handed to
`string.pack("<I4", ...)`. Fixed by applying the same `length > 0` guard on the write side; a
zero-length field is written back as `0`, since nothing ever reads at it. Verified by re-extracting
`Spotlight.framework` (previously a hard failure) and cross-checking the rebuilt Mach-O header's
segment/symtab/dysymtab bounds against the file size in Python — all within range, unlike the earlier
attempt's `183410688 + (8192 - 187111415) = -3692535`.

## What the port does

`CSSearchableIndex` keeps its own journal: a `CharonSpotlightStore` per index name, a property-list
of archived `CSSearchableItem`s and the batch client state, under Application Support at
`space.kern0x1b.corespotlight/<name>.plist`. `indexSearchableItems:completionHandler:` and the three
delete methods write or remove entries and call their handler with a `nil` error — a real journal, not
a `documented-absent` refusal — and `endIndexBatchWithClientState:completionHandler:` /
`fetchLastClientStateWithCompletionHandler:` persist and return the client state exactly as the
header describes, including refusing batching on `defaultSearchableIndex`. `isIndexingAvailable`
answers `YES`: the index genuinely indexes.

Every mutation also calls `CharonSpotlightBridge`, which `dlopen`s `Spotlight.framework`,
resolves `SPSpotlightManager` and `+sharedManager` with `NSClassFromString`/`objc_msgSend`, registers
the index's category (the application's own bundle identifier) with
`-startRecordUpdatesForApplication:andCategory:`, and on each write pushes the changed identifiers
with `-requestRecordUpdatesForApplication:category:andIDs:` followed by `-notifyIndexer`. Every call
is guarded by `respondsToSelector:` and wrapped in `@try`/`@catch`, off the main thread, so an
unexpected private-framework surface can never turn into a fatal error for the host application: this
is the honest bridge to the private class, not a fabricated success.

## What is not proven

`SPSpotlightManager`'s registration and push calls were exercised against a private class whose
control-flow past the two shared stub entry points was not traced, so whether the manager journals a
category it has never seen from a first-party bundle, and whether the `_displayID`/`title`/... record
fields need to accompany the pushed identifiers for the pull side to answer anything, are both
unmeasured on-device. What is measured and closes the loop regardless of that answer: even a
perfectly accepted registration cannot reach the user, because the system's own search surface is the
fixed eleven-bundle list above, none of which reads a third-party category, and
`Application.searchBundle` (the one bundle that does look at installed apps) bypasses
`SPSpotlightManager` entirely.

**The twelfth entry named above is built and installed; the query path is not proven yet, and
exactly how far it gets is now measured on an iPad 2 (6.1.3), not guessed.**
`packages/a/apple-backports/CoreSpotlight/SearchBundle/CharonSearchDatastore.m` is
`org.charon.corespotlight.searchBundle`'s principal class, built by `write_searchbundle` in
`modules/apple/backports.lua` whenever `corespotlight` is among the staged libraries, for
`/System/Library/SearchBundles/org.charon.corespotlight.searchBundle/`. **It is not packaged:**
`write_deb` builds it outside the stage and prints `withheld:` with the reason, because sending
`-appendResults:` hangs `searchd` (below). It goes back into the package only once that hang is
fixed and the query path is measured green on a device. The protocol it
implements was read from `NotesDatastore` (`MobileNotes.searchBundle`'s own principal class) with
`llvm-otool -oV` and each selector resolved against the iOS 6.1.3 shared cache directly
(`.agent-work/handoffs/2026-09-23-corespotlight-searchbundle-measurement.md`), which corrected two
selector names an earlier `strings`-only pass got wrong (`-categoryForDomain:` and
`-wantsEveryResultInItsOwnSection` are not implemented by `NotesDatastore` at all - the real
required methods are `-displayIdentifierForDomain:`, `-searchDomains` and
`-performQuery:withResultsPipe:`). `-performQuery:withResultsPipe:` filters every app's stored
items (case-insensitive substring match against `attributeSet.title` - the only field this
port's `CSSearchableItemAttributeSet` actually backs; `.contentDescription` was assumed present
from the real CoreSpotlight API and found, on device, to raise `NSUnknownKeyException` instead of
answering `nil` - corrected before it ever shipped a crash) and
pushes matches through `-[resultsPipe addResults:]`, the way `NotesDatastore` itself does.

This forced a real correction to `CSSearchableIndex` itself:
`CharonSpotlightStoreDirectory` wrote under `NSApplicationSupportDirectory`, sandboxed to the
indexing application's own container - a location no search bundle, running in whatever process
hosts system search, could ever read. It now writes under
`/var/mobile/Library/Caches/org.charon.corespotlight/<bundle identifier>/`, world-readable
(`0777`), the same shared-cache bridge pattern `org.charon.callkit` already uses to cross the same
kind of process boundary. `CharonSearchDatastore.m` resolves `CSSearchableItem` - this port's own
class, not Apple's, so no compile-time link is possible - by `dlopen`ing the installed
`libCoreSpotlightBackports.dylib` symlink before unarchiving, and every value that crosses that
boundary is typed `id` and read with `valueForKey:`, never a static `CSSearchableItem *`, since
this bundle is built once, not per band.

## Measured on device 2026-09-23 (iPad 2, 6.1.3): the two questions this was all built to answer

**Does the search host re-read `/System/Library/SearchBundles/` without a reboot? Yes, measured, not
assumed - there is no persistent daemon to be stale.** `com.apple.searchd`
(`/System/Library/PrivateFrameworks/Search.framework/searchd`) is a launchd on-demand service with
no `KeepAlive`: nothing has it loaded until the first client connects, it exits again once idle, and
each cold start is confirmed by its PID changing between runs (`ps ax`) after `kill -9`ing it. A
`SPSearchAgent` created from a standalone diagnostic process (`tests/backports/device/searchbundle-probe.m`)
drove a real query through this real daemon and got real
results back for Apple's own built-in bundles (`com.apple.MobileAddressBook`: 3, `com.apple.AppStore`:
1, for the query `"a"`) - proving the whole `SPSearchAgent` → XPC → `searchd` → `-_loadSearchBundles`
→ datastore → `SPSearchResultSection` pipeline is real and working end to end, and that a freshly
installed or updated bundle is live the moment the next connection cold-starts `searchd` - no respring,
no reboot, structurally, because there is nothing long-lived to go stale.

**Does a real query reach `-performQuery:withResultsPipe:`? Not yet - genuine progress, an honest
boundary, not a guess dressed as a result.** Getting this far took three more real, on-device-only
bugs, each found by a failure this port could not have predicted from host-only reading:

1. **`Info.plist` used the wrong keys.** The host-only pass read `principalClass` (lowercase) from a
   `strings` fragment - "unable to load search bundle... principal cl[ass...]" - and wrote that as a
   literal plist key, the same trap as the `-categoryForDomain:` mistake in the same document,
   applied to a plist key this time instead of a selector name. `MobileNotes.searchBundle`'s own
   `Info.plist`, fetched and read directly, uses `NSExecutable`/`NSPrincipalClass` (standard
   `NSBundle` keys) and carries no `CFBundleExecutable` at all. `[NSBundle loadAndReturnError:]`
   answered `NSCocoaErrorDomain` code 3588 ("couldn't be loaded") against the wrong keys; fixed by
   matching the real bundle's keys exactly.
2. **The compiled bundle referenced `_objc_alloc` and `___NSArray0__`, neither exported by iOS
   6.1.3.** Both are modern-runtime fast-path symbols ARC's codegen substitutes for ordinary
   patterns - `[[X alloc] init]`/bare `[X alloc]` for the first, the empty array literal `@[]` for
   the second - when the compile target implies a new-enough runtime, which `-target
   armv7-apple-ios9.0` (used to route around a `libarclite` requirement at lower targets, same as
   `tests/backports/device/cellulardata.m` this session) does. `dlopen`'s own `dlerror()` named the
   exact missing symbol directly - a far better signal than `NSBundle`'s generic "couldn't be
   loaded". Fixed by replacing `@[]` with `[NSArray array]` throughout; the earlier
   `CTCellularData9.m`/device-test precedent for `_objc_alloc` already established the same fix
   for `alloc`/`init`.
3. **`SPSearchDatastore` is a protocol, not a class - `NotesDatastore` does not subclass a class of
   that name.** `NSClassFromString(@"SPSearchDatastore")` answers `nil`; the code silently fell back
   to a bare `NSObject` subclass, which loaded and registered without error but which `searchd`
   never asked anything of - no crash, no log, `-searchDomains` simply never called, indistinguishable
   from the bundle not existing at all. `macho.imported_symbols` on `MobileNotes`'s own extracted
   binary names exactly one `SP`-prefixed class import, `SPContentResult`; NotesDatastore's real
   inheritance is `SPContentResult <SPSearchDatastore>`, class and protocol two different names
   sharing no relationship the earlier reading assumed. Fixed by subclassing `SPContentResult`.

## Measured 2026-09-23, second pass: `SPContentResult` found by reading the classlist, not guessing

**Boundary crossed, not intermediate: `searchd` now calls into this bundle's own methods for real.**
The first device pass ended with `searchd` never calling `-searchDomains`/`-performQuery:withResultsPipe:`
on the registered class at all - that is now fixed and confirmed: both are called, `-performQuery:withResultsPipe:`
receives a real query, correctly reads its `searchString`, and correctly builds a real `SPContentResult`
carrying the synthetic item's exact title. `resultsPipe respondsToSelector:@selector(appendResults:)`
answers `YES`. Whatever remains is entirely about the one call at the end of this chain, not about
whether the bundle is reachable at all - record it as crossed so the next pass does not re-prove it.

A note on the method that found `SPContentResult`, since the instruction that produced it was itself
based on an assumption worth naming: the coordinator's own suggestion was to find the image that
*exports* `_OBJC_CLASS_$_SPContentResult`. Nothing exports it - `macho.imported_symbols`, which reads
the export trie, found nothing, and following that instruction literally would have answered
"defined nowhere", a sixth wrong fact in this chain. **A class can be defined and never exported**;
the ObjC runtime reads class definitions from `__objc_classlist`, a section a linker's export trie
has no reason to include, since nothing outside the image references the class by its mangled
`_OBJC_CLASS_$_` symbol directly - only `objc_getClass`/`NSClassFromString` reach it, at runtime, by
name. `apple.objc.inventory()` walks `__objc_classlist` across the whole cache directly, which is why
it found what the export-trie read could not.

Answer: `SPContentResult` is defined in `Search.framework` itself, the file already extracted this
session - superclass `SPSearchResult`, superclass of that `PBCodable`, and no overridden `-init`
anywhere in the chain, so the "unmeasured initialization contract" this document named as the
boundary after the first device pass was the wrong hypothesis. The real blockers, found one at a
time as each was fixed:

1. **`objc_allocateClassPair` over `SPContentResult` does not itself grant `<SPSearchDatastore>`
   conformance.** `NotesDatastore` gets it from its own `@interface` declaration; `class_addMethod`
   alone does not reproduce that. This is the exact same gap this pass had already found and fixed
   on the delegate side (`SPDaemonQueryDelegate`, `class_addProtocol` in
   `tests/backports/device/searchbundle-probe.m`) - applying the identical fix to the datastore
   class itself (`class_addProtocol(cls, objc_getProtocol("SPSearchDatastore"))`) is what made
   `searchd` call `-searchDomains` and `-performQuery:withResultsPipe:` for the first time. Confirmed
   by the file log the class itself writes (see below): `searchDomains called`, then, once the query
   agent's domain list was extended to include this datastore's own declared domain,
   `performQuery:withResultsPipe:` too.
2. **The `resultsPipe` parameter is not a separate object and not an `SPSearchResultSection`.**
   Logging its `-description` showed the exact same pointer as `query` - it is the query object
   itself, an `SDSearchQuery`. That class is not in the shared cache at all (`apple.objc.inventory()`
   found nothing under that name); it is defined in `searchd`'s own executable, fetched and read
   directly with `llvm-otool -oV`. Its real, required protocol is `<SPSearchResultsPipe>`, and the
   push method is `-appendResults:` (`v12@0:4@8`) - not `-addResults:`, which is a real method of the
   unrelated `SPSearchResultSection` that happened to share a name and a shape, the exact mechanism
   that makes a wrong name look plausible. Fixed by sending `-appendResults:` instead.
3. **The result factory is `SPContentResult`'s own class method, not `SPSearchResult`'s.** The first
   device pass attributed `+resultWithIdentifier:title:subtitle:summary:auxiliaryTitle:auxiliarySubtitle:actionURL:searchableContent:`
   to `SPSearchResult` (repeating the original, pre-device `strings`-based session's claim
   unchecked); `apple.objc.inventory()`'s classlist read shows it is `SPContentResult`'s own class
   method - `SPSearchResult` only happens to be `SPContentResult`'s superclass. `SPSearchResult
   respondsToSelector:` answered `NO` for exactly this reason, caught by the file log rather than
   silently returning no results forever.

After all three: the bundle `dlopen`s cleanly, registers as a real `SPContentResult` subclass
conforming to `<SPSearchDatastore>`, `searchd` calls `-searchDomains` and
`-performQuery:withResultsPipe:` for real, `-performQuery:withResultsPipe:` correctly reads the
query's `searchString`, correctly finds the one synthetic item written for this test, and correctly
builds a real `SPContentResult` carrying that exact title - confirmed by the object's own
`-description` in the log: `<SPContentResult: 0x1d59c080> { title = CharonProbeXyzzyPlugh19640523; }`.
`resultsPipe respondsToSelector:@selector(appendResults:)` answers `YES`.

**Sending `-appendResults:` to it hangs `searchd`, and the differentiating experiment names which
of the two candidates it is not.** The call was made; no crash followed, no further log line
(`appendResults: sent`, the line immediately after the send, never appears), and `searchd`'s own
process moved into uninterruptible sleep (`ps` state `U`) and stayed there, unresponsive to a fresh
connection, until killed with `kill -9`. Real, observed, confirmed by waiting past it and
re-checking, not a single snapshot.

`class_copyIvarList` walked across the real chain (`SPContentResult` → `SPSearchResult` →
`PBCodable` → `NSObject`, read directly on device, not guessed from names) found the actual field
set, smaller than assumed: `SPContentResult` itself carries only `_extid`/`_content`
(`-setExtid:`/`-setContent:`); `SPSearchResult` carries `_identifier` (a `Q`/`uint64_t`, not a
string - the factory's `identifier:` argument is presumably hashed into it internally),
`_title`/`_subtitle`/`_summary`/`_auxiliaryTitle`/`_auxiliarySubtitle`/`_url`, and one `_has`
bitfield (`{?="identifier"b1"flags"b1}`) tracking only those two fields as ever-set - both already
set by the real factory this code calls. **There is no `_domain` ivar anywhere in this chain** -
that field belongs to the unrelated `SPSearchResultSection`, so "unset domain" was never a real
candidate; `_extid`/`_content` were the only two fields actually worth filling.

Filled both (`-setExtid:` with the item's own identifier, `-setContent:` with its title, confirmed
in the log immediately before the hang: `extid=org.charon.corespotlight.probe.item1
content=CharonProbeXyzzyPlugh19640523`) and repeated the call on a clean `searchd`
(confirmed not-yet-running before the run, per the coordinator's instruction not to chain
experiments without a health check between them). **The hang still happens, identically** - same
missing `appendResults: sent` line, same `U` state, same unresponsiveness until `kill -9`. This
rules out the missing-field hypothesis directly rather than leaving it open: whatever
`-appendResults:` blocks on, it is not an unset `extid`/`content`/`domain`. The remaining
candidate - `-appendResults:` expecting a call chain or connection state this bundle's
`-performQuery:withResultsPipe:` does not reproduce, most plausibly a `mach_msg` wait on something
this out-of-process caller never supplies - stands as the real boundary, differentiated rather than
assumed. `searchd` was confirmed healthy again after each `kill -9` (a real query against Apple's
own built-in bundles, results returned normally) before the device was released; the bundle itself
was removed before release, since it hangs the host it loads into.

This paragraph and the one above were measured by commit `f19a3da8` and lost from main when an
earlier-authored patch (`59b01c7a`) was applied after it; they are restored as measured. The
experiment's code - `-setExtid:`/`-setContent:` filled with the item's identifier and title - is
not restored: it did not change the hang, and what `NotesDatastore` itself puts into those two
fields is not measured, so filling them with guessed values would be a quietly different answer.

Diagnostics used during those passes, since this class runs inside `searchd`, not the process
that launches it: a plain `fopen`/`fprintf`/`fclose` to `/private/var/backports/searchbundle.log`
was the channel that reached the measurer. It is removed from the source: it wrote every search
string and every matching item's title - the device owner's own searches and every indexing app's
data - to a file with no bound. The bundle keeps only `NSLog` lines for structural failures (no
query, no title, no result); whether `searchd`'s `NSLog` reaches the device's system log is not
measured. A pass that needs more must add its own scaffolding, keep user data out of it, and take
it off before its patch.

## What differs from the release

The `Images`, `Media`, `Documents`, `Events`, `Places` and `Messaging` attribute categories and the
custom-key API are not carried: an application that reads or writes one of those properties sends a
message this port does not implement. `indexDelegate` is kept but never messaged: nothing in this
port's own runtime ever loses the journal the way the real index's remote process can, so there is
never a `reindexAllSearchableItemsWithAcknowledgementHandler:`/
`reindexSearchableItemsWithIdentifiers:acknowledgementHandler:` call to make. The two continuation
constants (`CSSearchableItemActionType` = `"com.apple.corespotlightitem"`,
`CSSearchableItemActivityIdentifier` = `"kCSSearchableItemActivityIdentifier"`) are carried at the
release's own values, extracted from `CoreSpotlight` of the arm64 shared cache of iOS 12.0
(`_CSSearchableItemActionType` and `_CSSearchableItemActivityIdentifier`, each a pointer to a
`CFConstantString`, read with `modules/apple/dyld.lua`'s `pointer_at`/`string_at`), but neither is
ever posted by this port: no item of this port's making is ever surfaced by the system's Spotlight
for the user to tap, so the continuation path they describe never runs here — see above for why, and
for what closing that gap actually requires. `CSIndexErrorDomain` = `"CSIndexErrorDomain"`, extracted
the same way.

A write that fails is answered, and nothing of it is kept. The index is a plist per index name
under `CHARON_SPOTLIGHT_SHARED_ROOT` (`CoreSpotlight/CharonSpotlightStore.h`), written by
`-[CharonSpotlightStore save]` in `CSSearchableIndex.m`. When the directory cannot be made, the
store cannot be serialized, or the file cannot be written, the five mutating calls
(`indexSearchableItems:`, the three deletes, `endIndexBatchWithClientState:`) hand their completion
handler an error in `CSIndexErrorDomain`:
- it describes the path;
- it carries the Foundation error that caused it under `NSUnderlyingErrorKey`;
- its code is `CSIndexErrorCodeIndexUnavailableError` (-1000).

The store in memory goes back to what it held before the call, so `fetchLastClientState...` and a
later save never answer or write what the caller was told failed, and searchd is not told of
records that were not stored.

The code is reasoned, not measured. The SDK's `CSSearchableIndex.h` (iPhoneOS16.4.sdk) documents
-1000 as "The indexer was unavailable", and this file store is the port's indexer. None of the other
codes fits: -1001 is an invalid item, -1002 an invalid client state, -1003 a failed connection to a
remote process (this port has none), -1004 an exceeded quota, -1005 no indexing on the device. The
release has no exact counterpart to measure: it writes inside its indexing daemon, and an
application does not see a write failure of its own. What would decide it is the answer of an iOS 9+
device whose index cannot be written, for example with a full disk; that has not been run.

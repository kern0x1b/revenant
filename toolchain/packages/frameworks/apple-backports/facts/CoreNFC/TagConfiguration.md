# NFCTagCommandConfiguration and the two ISO15693 configurations, iOS 11.0

Introduced in iOS 11.0: the configuration an application fills in and hands to a tag, for the
manufacturer custom command and for reading several blocks at once. All three classes arrived in
11.0 and are carried whole: **NFCTagCommandConfiguration**,
**NFCISO15693CustomCommandConfiguration** and
**NFCISO15693ReadMultipleBlocksConfiguration**.

## Why these three and not the rest of CoreNFC

A configuration is a value. It is made from the fields an application sets, read back through its
properties, and copied; nothing in it is a session, a tag or a radio. That is the same line the
sibling file draws for NFCNDEFPayload (facts/CoreNFC/NDEF.md), and it is what makes these three
carriable on an iPhone 4S and an iPad 2, which have no NFC radio at all.

The sessions are on the other side of that line: an application that asks
`+[NFCReaderSession readingAvailable]` gets **NO**, a session can be made but is never ready, and
its `-beginSession` is answered with the unsupported-feature invalidation (facts/CoreNFC/NFCReaderSession.md),
and the tag protocols have no tag to answer for. Carrying a configuration therefore gets a caller as far as building,
keeping and copying one, and no further - and that limit is stated in each row's `effect`, not
papered over by a stub session that pretends to poll.

## The measurement: the host's own CoreNFC

Unlike the NDEF classes, the tag-command configuration classes are **not**
`API_UNAVAILABLE(macOS)`, so the same three classes exist on the host and are a real oracle. The
differential builds the port's own source with its class names prefixed (`-DNFCTagCommandConfiguration=RevenantHost…`),
so the port's classes and the host's coexist in one process, and asks both the same questions in the
same order.

**The command**, from the repository root:

```
PROBES_BUILD="$PWD/.agent-work/runs/tagconfig" FLEET_HEAVY_LANE=fast \
    $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/corenfc-tagconfig/run.sh
```

It ends with `0 of 116 checks failed` and writes the per-check log to the path it prints. Every
check is a comparison of the port's answer with the host's for the same call; the check name is the
question and the `detail` carries both numbers when one differs.

### What the host answers, and the port answers the same

| question | host | port |
| --- | --- | --- |
| `-init` on the base | `maximumRetries` 0, `retryInterval` 0 | the same |
| `-init` on the custom command | `manufacturerCode` 0, `customCommandCode` 0, `requestParameters` **nil** | the same |
| `-init` on read multiple blocks | `range` {0,0}, `chunkSize` 0 | the same |
| `maximumRetries = 1000` (header: 0 to 256) | 1000 | 1000 |
| `retryInterval = -5` | -5 | -5 |
| `manufacturerCode` 0x1FF (header: 0x00 to 0xFF) | 0x1FF | 0x1FF |
| `customCommandCode` 0x5 (header: 0xA0 to 0xDF) | 0x5 | 0x5 |
| zero-length read range (header: "shall not be 0") | length 0 | length 0 |
| the three-field / two-field initialisers | retry fields stay at the base's 0 | the same |
| `-copy` | the subclass, carrying every field, its `requestParameters` its own | the same |
| `-isEqual:` over two objects of identical fields | **NO** (NSObject's) | NO |
| `NSCopying` conformance | yes | yes |

**Nothing clamps and nothing raises.** The headers call ranges "valid" and say a length "shall not
be 0", and the host keeps every number it is given outside them. That is measured, not inferred: the
row above is six out-of-range assignments, each answered with the number asked for.

### The mutation, which is what makes the run bite

`--fail-first` makes the port's `copyWithZone:` drop the base's retry fields and its three-field
initialiser report one retry it was never given. Measured, the run then reports **7 of 116 checks
failed**, every one of them a `maximumRetries` comparison:

```
FAIL maximumRetries of a copy answers what CoreNFC answers: port 0, host 3
FAIL maximumRetries of the three-field initialiser answers what CoreNFC answers: port 1, host 0
FAIL the three-field initialiser leaves maximumRetries at zero answers what CoreNFC answers: port 1, host 0
FAIL maximumRetries of a copy answers what CoreNFC answers: port 0, host 5
FAIL maximumRetries of a copy answers what CoreNFC answers: port 0, host 7
FAIL the base's maximumRetries of a fresh configuration on both sides answers what CoreNFC answers: port 1, host 0
FAIL the base's maximumRetries of a fresh configuration answers what CoreNFC answers: port 1, host 0
7 of 116 checks failed
```

The mutation is applied to a **copy** of the source under the build directory, so no test hook is
compiled into the port's own file — the tree's other mutation (`corenfc/run.sh --mutated`) likewise
leaves the port's source alone.

```
PROBES_BUILD="$PWD/.agent-work/runs/tagconfig-mut" FLEET_HEAVY_LANE=fast \
    $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/corenfc-tagconfig/run.sh --fail-first
```

## This run found a real defect, and it is fixed

The first run of this differential reported **2 of 116 checks failed**, and one of them was a
defect in the port's own code rather than in the test:

```
FAIL manufacturerCode of a copy answers what CoreNFC answers: port 0, host 4
FAIL customCommandCode of a copy answers what CoreNFC answers: port 0, host 160
```

The subclass's `-copyWithZone:` called `[super copyWithZone:]` and then set only its own *new* field,
so a copy of an `NFCISO15693CustomCommandConfiguration` named no command at all — the copy read back
`manufacturerCode` 0 and `customCommandCode` 0 whatever the original had. Fixed at
`CoreNFC/NFCTagConfiguration11.m` by setting all three of the class's own fields. It is the kind of
defect a header-faithful implementation makes and a differential against a real oracle does not.

## What is absent, and why

The reader sessions (`NFCReaderSession`, `NFCNDEFReaderSession`,
`NFCISO15693ReaderSession`), the tag protocols (`NFCTag`, `NFCISO15693Tag`) and the two delegate
protocols. The run checks these **both ways** — present on the host, absent from the port — so a
stub that grew a session while carrying a configuration would fail here:

```
ok beginSession is absent from a reader session
ok invalidateSession is absent from a reader session
ok NFCISO15693ReaderSession is absent from the port
ok a custom command configuration cannot send a command
ok the port's class carries the RevenantHost prefix
```

The reasons and the census that certifies them are in
[facts/CoreNFC/NFCReaderSession.md](NFCReaderSession.md), which carries the command and its control:

```
REVENANT_ROOT="$PWD" xmake l tools/corpus/cache-census.lua NFC
```

```
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
          images 524, of which naming NFC 0
          classes 11378, of which NFC* 0
          protocols 1171, of which NFC* 0
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
          images 354, of which naming NFC 0
          classes 7187, of which NFC* 0
          protocols 564, of which NFC* 0
11.0      $HOME/.revenant/dyld/11.0/dyld_shared_cache_arm64
          images 1258, of which naming NFC 1
          classes 52768, of which NFC* 34 (... NFCISO15693CustomCommandConfiguration
                  NFCISO15693ReadMultipleBlocksConfiguration NFCISO15693ReaderSession
                  NFCISO15693Tag ... NFCTag NFCTagCommandConfiguration ...)
          protocols 8954, of which NFC* 11 (... NFCISO15693Tag NFCReaderSession NFCTag ...)
control: 45 name(s) beginning NFC found in this run, so a zero on another rung
is the release's and not the reader's
```

The 34 and the 11 are the control, in the same run and by the same reader as the two zeros, and they
include the three classes this object defines: their first appearance is 11.0, which is what places
them in this object and no other.

`xmake l tools/cache-index/first-rung.lua NFCTagCommandConfiguration` (self-test 8 of 8) gives each of
the three its first held rung at **11.0**, by the whole symbol table rather than the Objective-C
metadata — a second reader, which is why the two agree.

## What `release-split` says, and what its "0 symbols" means here

```
xmake l tools/release-split.lua <objects dir>       # objects/CoreNFC/*.o, objects/sdkdir beside them
```

```
release-split: /…/objects/CoreNFC
release-split: SDK /…/iPhoneOS16.4.sdk
release-split: clean, every object file's symbols first-appear in one release (2 files, 0 symbols, 50 releases checked)
release-split: every folder of … is clean
```

**"0 symbols" is this object's normal reading, not a gap and not a hidden-visibility defect.**
`release-split`'s own `symbols_of()` counts a symbol when it is external (`N_EXT`) and explicitly not
private external (`N_PEXT`) — the comment at `tools/release-split.lua:103` gives the reason. Every
`.m` in this package is compiled with `-fvisibility=hidden` (`modules/apple/backports.lua:477`), which
makes every Objective-C class symbol private external, so `nm -gUm` lists them under that heading and
the tool skips them. Measured: the **shipped** `NFCNDEFMessage11.o`, compiled the same way in the
same run, also contributes 0 symbols — 2 files, 0 symbols, both of them.

That is not the `unbuilt` trap the rulebook names (a class compiled with hidden visibility can never
be `implemented`): the gate that decides that reads `surface()`'s `found.classes`, which is filled from
`objc.binary_inventory()` over the **linked dylib**, where a class the library defines carries an
image (`modules/apple/backports.lua:1441-1449`). The differential above is the proof that it does: it
links this object into a binary and `NSClassFromString` hands back the very class the object file
registered, under the port's own name.

```
ok RevenantHostNFCTagCommandConfiguration is carried under its own name
ok the port's class carries the RevenantHost prefix
ok the port's class and the host's class of the same API are two classes
```
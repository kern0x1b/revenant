# NSProgress, iOS 6 to 11

Source: the host's own Foundation, asked for every case below and held against the backport by the
`progress.*` records of `tests/backports/host/foundation2/run.sh`, and Foundation of iOS 6.0 and 6.1.3 on the
emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/foundation2.m`, which compares the
backport's answers with the records the host wrote.

## What iOS 6 already has

`NSProgress` is in the Foundation of iOS 6.0 and 6.1.x, with most of the surface iOS 7 made public: the
progress of the current thread, `progressWithTotalUnitCount:`, `becomeCurrentWithPendingUnitCount:` and
`resignCurrent`, the two counts, `fractionCompleted`, cancelling and pausing with their handlers, the
`userInfo` and the kind. From 6.0 a class that is there is not backported; what the release lacks is carried
as categories, and the eight ways it answers differently are listed at the end. Below 6.0, where the class
itself is missing (`Foundation/NSProgress.m`, registry `NSProgress`, no `minimum`), the categories attach
to that instead, unchanged, the same way they attach to the release's from 6.0 on.

## The class below iOS 6.0

Two libraries weakly import it - `NSItemProvider` and `UIDragDropSession`, `libFoundationBackports.dylib` and
`libUIKitBackports.dylib` - each only ever calling `+progressWithTotalUnitCount:1`, a leaf progress with no
ambient current progress; nothing in the package reaches the current-progress stack, `-addChild:withPendingUnitCount:`
or a handler through them. The class exists for its own sake, not only theirs, and is held to the same surface
below 6.0 as the categories already assume is there from 6.0 on.

`Foundation/NSProgress.m` carries: the current-progress stack (`+currentProgress`, `becomeCurrentWithPendingUnitCount:`,
`resignCurrent`, `initWithParent:userInfo:`, `+progressWithTotalUnitCount:`, adapted from swift-corelibs-foundation's
`Progress.swift`, which documents the mechanism but is not itself the answer where it disagrees with what iOS 6
measures - see below), the two counts, `fractionCompleted`, `isIndeterminate`, cancelling and pausing with their
handlers (`isCancellable`/`isPausable`/`isCancelled`/`isPaused`/`cancel`/`pause`/`resume`, the handler setters;
the getters of `cancellationHandler`/`pausingHandler` stay in `NSProgress+Additions.m`, which already reads them
by ivar name off whichever class the process has), `userInfo`/`setUserInfoObject:forKey:`, `kind`, and
`localizedDescription`/`localizedAdditionalDescription`. `-addChild:withPendingUnitCount:` and `-isFinished` are
deliberately not here: `NSProgress+AddChild9.m` and `+Additions.m` carry those, the same category for every band,
so the class does not duplicate a selector two files would both define, and the categories' own `+load` guard
(`if ([NSProgress instancesRespondToSelector:@selector(addChild:withPendingUnitCount:)]) return;`, read at
`+load` time, before `attach.c`'s constructor attaches this package's own categories - toolchain/AGENTS.md, Traps)
tells the release's-own-support case from this one the same way it always has.

Cancelling and pausing cascade to an implicit child in both orders without a live link from child back to
parent: a child attached while the parent is already cancelled/paused is cascaded at attach; one attached first
is reached when the parent later cancels/pauses, by walking the array of already-attached children the parent
holds. Neither needs `__weak` - a runtime this class is also built for, armv7-`apple_minimum` 4.3, does not have
(`objc_storeWeak` is absent there, facts/Foundation/NSMapTable.md); `-Xclang -fobjc-runtime-has-weak`, which
`modules/apple/backports.lua` passes for a band below 5.0, only lets *other* files that need real `__weak` compile
in the same pass at this deployment target - it says nothing about whether calling it at 4.3 is safe, and this
class is the one placed there, so it does not use it.

Held to iOS 6, not the newest release, for three read cases where they disagree (below): `fractionCompleted` of
a zero-total progress, `isIndeterminate` of a fresh one, and `resume`. `localizedDescription`/
`localizedAdditionalDescription` answer what was explicitly set, or `""` when nothing was, matching iOS 6's own
measured default (`null_resettable`, so a value once given is not silently dropped); the newest release computes
a default from the counts and kind when nothing was set, and a rule read off a handful of cases would be a
guess ("What the backport adds", above).

The five `userInfo` keys these five properties read and write (`NSProgressThroughputKey`, `NSProgressFileOperationKindKey`,
`NSProgressFileURLKey`, `NSProgressFileTotalCountKey`, `NSProgressFileCompletedCountKey`) are exported from 6.0 (armv7
caches: absent through 6.1.6, present from 7.0), unlike `NSProgressEstimatedTimeRemainingKey` (absent through 6.1.6,
present from 7.0 too, but the existing registry entry already reads its `introduced` as 7.0, its SDK-documented
release; not revisited here). Weakly imported and NULL below 6.0 until this session, since `NSProgress+Additions.m`,
which reads and writes them, was only ever placed at `minimum` 6.0 and later before this class existed below that -
the same reason NSProgress itself was missing there. `Foundation/NSProgress+Keys6.m` carries them, apart from
`+Additions.m`'s own two constants (introduced 6.0 and 7.0 respectively), each the string of its own name (measured
with `tools/corpus/cache-value.lua` against the 12.0 arm64 cache's Foundation), so no one object mixes a release its own symbols
are present at with one they are not (`band()`, "split it").

What is not carried, below 6.0 or from it: publishing and subscribing (`publish`, `unpublish`,
`addSubscriberForFileURL:withPublishingHandler:`, `removeSubscriber:`, `isOld`) - all four are
`API_UNAVAILABLE(ios)` in the SDK header itself, not something an iOS application can call regardless of release,
so nothing is missing that a caller could reach.

What the base class's own `fractionCompleted` does not do, stated rather than silently different, the same shape
as the already-accepted limitation of `-addChild:withPendingUnitCount:` two paragraphs up in "What the release
cannot do": an implicit child that finishes stays in the parent's list and keeps contributing its full portion to
`fractionCompleted` for the rest of the parent's life, but the parent's own `completedUnitCount` never absorbs
it. Not measured against a real device oracle (no test in the package reaches the current-progress stack at all,
per "Two libraries weakly import it" above); checked against the host's own Foundation instead
(`tests/backports/host/progress2/run.sh`, a differential with the class renamed, 36 checks, four named
tolerances for the three read-case divergences above and for the handler dispatch below), which is this class's
own oracle in the absence of a device one, same as `tests/backports/host/foundation2` already is for the
categories. Checked on the emulator against the release's own class: `tests/backports/device/progress.m` and
`progress-cases.m` (already written for the release, unchanged) through `tests/backports/device/below6/`, on
5.0 against 6.0's own answers (63/0, 12/0). 4.3 is not checked there yet, honestly, not a pass reported as one:
`device/progress.m` decodes its own expectations file with `NSJSONSerialization`, which the backports do not
carry below iOS 6.0 until that class's own turn (the next single-reference class after this one), so the
program's own harness-only JSON decode is weak-imported and NULL at 4.3 and the run is a silent 0/0, waived in
`tests/backports/device/below6/xmake.lua` for that reason and no other. Nothing of `NSProgress` under test is
reached at 4.3 by this program at all, below or above the waiver; the 4.3 build of `Foundation/NSProgress.m`
itself is the same compiled object 5.0 uses (band() places both at the same object, one band point apart) and
the host differential above, neither of which is a device measurement. Once `NSJSONSerialization` is carried
below 6.0, this run becomes real and this paragraph is to be corrected again.

Where a handler is called differs in timing, not effect: iOS 6's `-cancel`/`-pause` call the handler
synchronously, at the call itself; the host's newest Foundation dispatches it asynchronously (read in
`Progress.swift`: `DispatchQueue.global().async { handler() }`), so `host/progress2`'s checks of the handler
firing wait briefly first, as `tests/backports/device/progress-cases.m`'s own `cancel.child`/`pause.child` cases
already do for the same reason. Not measured which iOS 6 itself does (synchronous or dispatched) - not
reachable by the package's own two callers, and `progress-cases.m`'s wait already tolerates either.

## What the backport adds

A progress made with `+discreteProgressWithTotalUnitCount:` has no parent and does not take the current
progress for one: `+progressWithTotalUnitCount:` of the release takes it, and this is the way out of that.

`+progressWithTotalUnitCount:parent:pendingUnitCount:` makes the child with its parent and the given part of
the parent's units, so that the parent's fraction moves as the child's does (a parent of 10 units, a child of 4
given 6 of them: 0.3 with two of the four done, 0.6 with all). A nil parent makes a progress like a discrete
one, and a negative part is accepted. The release links a child to its parent only when it is made, by way of
the current progress, so the port makes the parent current for the moment of the call and lets go of it after;
the current progress is what it was before.

`-performAsCurrentWithPendingUnitCount:usingBlock:` makes the progress current with that part, runs the block
and resigns it. A block that raises leaves the progress current, as the newest release does.

`finished` is true when the progress is determinate and its completed count has reached the total. It is
indeterminate when the total is negative, or is zero with nothing completed, so a total of zero with
three units done is finished and one with none is not; a cancelled progress is finished when its counts say so
and not because it was cancelled.

The two handlers of the release are read back by their getters, which answer the block the release keeps, or
nil when none was set or it was cleared. The block is the one the setter copied, and calling it runs the
handler.

`estimatedTimeRemaining`, `throughput`, `fileOperationKind`, `fileURL`, `fileTotalCount` and
`fileCompletedCount` are not stored on their own: each reads and writes its key of the progress's `userInfo`, the
way the newest release keeps them, so `userInfo` shows them and setting one to nil takes its key out. The keys
are the constants of the release, and they are not the same text on every release - iOS 6 spells the throughput
key `NSProgressThroughput` where the newest spells it `NSProgressThroughputKey` - so an application that reads
the dictionary by the constant sees what the property set, and one that writes the literal text of a newer
release does not.

`NSProgressEstimatedTimeRemainingKey`, `NSProgressFileOperationKindReceiving` and
`NSProgressFileOperationKindUploading` are the strings of the same names, as in the newest release.

## What the release cannot do

An existing progress cannot be attached to a parent in the release's own way: it links a child when it is created
and keeps no list of children on the parent, and the link cannot be written into the object from outside - setting
the two fields that hold it left the parent's fraction where it was. `-addChild:withPendingUnitCount:` is carried
another way: the parent is made current with that part, the release makes a progress of the port's own under it, of a
million units, and the port sets that progress's completed count to the child's fraction each time the child's
`fractionCompleted` changes, watched by key value observing, and once at the start for a child that has some done. The
parent's fraction then moves as the child's does, for a child that has children of its own too, and its observers are
told; a child that reaches 1 is let go of. `-cancel` and `-pause` of a progress are replaced on a release that lacks
`-addChild:withPendingUnitCount:` and hand the message on to the children added to it, after the release's own work. A child added a second time raises `NSInvalidArgumentException`, as in the newest release; a progress that
the release made under another one is not known to be a child, so that one is not refused.

One thing of the release shows through: a progress that something observes with key value observing - which the port does
to every added child - is cancelled and paused on the next turn of the run loop, not at once, on iOS 6, observed by
an application or not. The host does it at once, so a test that reads `isCancelled` right after `-cancel` sees it
late, and one that lets the run loop turn does not.

What stays different: the parent's `completedUnitCount` does not count the child's units (see the last list), and the
child holds no reference to the parent it was added to.

The release can pause a progress and has no way back, so `-resume` and `resumingHandler` are absent.

`localizedAdditionalDescription` is absent: the newest release composes it from the counts, the throughput, the
time remaining and the file counts in several localized forms, and a rule read off a handful of cases would be
a guess.

## Where iOS 6 answers differently

These are methods of the release itself, which the port does not replace:

- `localizedDescription` is empty; the newest release says `25% completed`, or `Downloading 3 files…` for a file
  kind.
- `fractionCompleted` of a progress whose total is zero is not-a-number, and 0 in the newest release.
- `isIndeterminate` of a new progress is false, and true in the newest release.
- A cancellation handler set on a progress that is already cancelled is not called; the newest release calls
  it at once.
- `initWithParent:userInfo:` takes a parent that is not the current progress, where the newest release raises
  `NSInvalidArgumentException`.
- `resignCurrent` leaves the pending units a progress took uncounted when no child was made from them; the newest
  release counts them as completed, so a parent made current with 6 of 10 units and resigned with no child is 0.6
  done there and 0 here.
- A parent's `completedUnitCount` does not count a finished child's units; its fraction does.
- The keys of the file and throughput constants are spelled without `Key`, as above.

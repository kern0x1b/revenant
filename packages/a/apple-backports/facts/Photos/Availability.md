# Library availability, iOS 13.0

`PHPhotoLibraryAvailabilityObserver`, `-[PHPhotoLibrary unavailabilityReason]`, `-registerAvailabilityObserver:`
and `-unregisterAvailabilityObserver:` are of iOS 13, and the release this port runs on answers the
question they ask: the photo library of iOS 6 is `ALAssetsLibrary`, and it says in two ways whether
this process may read it. The authorization `[ALAssetsLibrary authorizationStatus]` reports, which the
port's `+[PHPhotoLibrary authorizationStatus]` is already made of, and the refusal its own enumeration
answers with when the library's data cannot be read.

There is no third source, and the port does not invent one. iOS 6 has no notification for a volume
going away, no way to be told that the system photo library was switched, and no library bundle this
process can move: the three events Apple's header gives codes for -- `PHPhotosErrorLibraryVolumeOffline`
(3114), `PHPhotosErrorRelinquishingLibraryBundleToWriter` (3142), `PHPhotosErrorSwitchingSystemPhotoLibrary`
(3143) -- cannot happen on this release, and the port answers no such error. Which of Apple's codes a
release *with* those events gives was not measured: it needs a release that has them, and no held
firmware here has one (the ladder stops at 18.0, and the events need a library this machine has no
control over).

## What the port answers

`-[PHPhotoLibrary unavailabilityReason]` is `nil` while the release's library answers this process, and
otherwise an `NSError` in the domain the header declares the codes in, `PHPhotosErrorDomain`, with the
header's own code for the case: **3311** (`PHPhotosErrorAccessUserDenied`, "The user has denied
access") for a denied process, **3310** (`PHPhotosErrorAccessRestricted`, "Access restricted by system
configuration") for a restricted one.

The observers are kept weakly, in a `NSHashTable`, as the change observers of `PHPhotoLibrary` are
(`facts/Photos/Changes.md`): one that goes away is dropped without being unregistered. The port sends
`-photoLibraryDidBecomeUnavailable:` to every observer registered at that moment, on a serial queue of
its own, because the header says of this notification that it "is posted on a private queue"
(`PHPhotoLibrary.h:45`) -- and says it of nothing else here. The callback is for a **change**: the
library going from available to unavailable. An observer registered while the library is already
unavailable is told nothing, since a registration is otherwise a second way of asking for
`-[PHPhotoLibrary unavailabilityReason]`, which answers it.

The port learns of a change in the two ways it has: the release's own `ALAssetsLibraryChangedNotification`,
and the next read of the reason itself. A denied process is told no more than that -- it never gets the
library, so nothing is ever posted to it -- which is why a denied process measures the property and the
registration rules, and not the transition.

## What is measured, and how

Run on an **iPhone 4S running 6.1.3** on 2026-09-30, through the tree's own runner, which builds the
program from this tree's Photos sources and prints what it reported:

    $ sh tests/backports/device/photos/run.sh --control photosalbums8 photosavailability13
    photosalbums8: 3 checks, 0 failed
    photosavailability13: 11 checks, 0 failed
    control: 1 checks, 1 failed
    control: it failed, so a failing check in a program above would have been seen
    photos device: every program that ran passed

The program's own report, `.agent-work/runs/photos-device/photosavailability13-.report`:

    AssetsLibrary authorization 2
    ok this process is denied the photo library
    ok PHPhotoLibrary carries -unavailabilityReason
    ok PHPhotoLibrary carries -registerAvailabilityObserver:
    ok PHPhotoLibrary carries -unregisterAvailabilityObserver:
    unavailabilityReason: Error Domain=PHPhotosErrorDomain Code=3311 "the user has denied access to the photo library" ...
    ok a denied process has an unavailability reason
    ok the reason is in the header's PHPhotosErrorDomain
    ok the reason is PHPhotosErrorAccessUserDenied (3311)
    ok an observer registered while the library is unavailable is told nothing
    ok an unregistered observer is told nothing, and unregistering twice is not a crash
    survived a notification with no observer alive
    ok a registration after the state is known tells nothing
    ok nothing was delivered on the main thread
    11 checks, 0 failed

A daemon is denied the photo library by the release, which is what makes the unavailable case measurable
without reading anybody's library: the program writes nothing and reads no asset. Its control is
`tests/backports/device/photos/control.m`, which asserts the opposite of the check
`photosalbums8.m` holds the port to, on the same call in the same process, and must fail -- the run
above reports it failing, which is what makes "0 failed" mean something. A device where the release
does not deny the process makes the guarded check vacuous, and the runner says so instead of reporting
a pass.

**Not measured here, and why:** the `nil` an authorised process gets, and the 3310 a restricted one
gets. Both need a bundle identifier the user allowed, which is an application, and the fleet keeps
that on the iPad 2 (the device that holds the fleet's own `CharonPhotosProbe` fixtures); the iPad 2
was not attached on 2026-09-30. The rule that produces them is two lines over a status the port already
answers and measures -- `+[PHPhotoLibrary authorizationStatus]` is measured in
`tests/backports/device/photos8.m` -- and the header's own `nullable` on the property, so the mapping
is reasoned, not assumed, and is recorded as reasoned here and in the row's `effect`.

## What the ladder says about the names

`tools/cache-index/first-rung.lua`, the first held release that carries each name, over the 50 rungs of
`dyld.held_ladder({"armv7","armv7s"})` -- asked with the name as the cache spells it, which for a
selector is the selector without the method's brackets and for a C symbol is the symbol with its
Mach-O underscore (`_PHLocalIdentifiersErrorKey`, not `PHLocalIdentifiersErrorKey`, which reads NONE):

| name | first held rung |
| --- | --- |
| `registerAvailabilityObserver:` | `10.0.1` |
| `unregisterAvailabilityObserver:` | `10.0.1` |
| `photoLibraryDidBecomeUnavailable:` | `10.0.1` |
| `unavailabilityReason` | `11.0` |
| `PHPhotoLibraryAvailabilityObserver` | `10.0.1` |
| `PHPhotoLibrary` | `8.0` |

Two of those are worth a reader's attention. The header marks the availability API `ios(13.0)`, and the
ladder says the names were already carried by **10.0.1** -- the same gap the header of a queue file
warns about, where a name in the cache is earlier than the release the SDK marks. Which class declares
`registerAvailabilityObserver:` in the 10.0.1 cache was **not** measured: a selector's name is in
`__objc_methname` whichever class declares it, so the rung says the name is there and not whose it is.
The port implements the API the header declares, for 13.0, which is the contract the corpus rows are
written from; the earlier carrying is recorded here and not acted on.

The protocol's name reads `10.0.1` and not `NONE`, which the tool's own README says to expect: it reads
class names, selectors, C literals and the whole symbol table, and a *protocol* name is in none of them.
A protocol's presence needs the class-scoped reader (`tools/corpus/objc-inventory.lua`), which was not
run over the 10.0.1 cache for this row: the port declares the protocol from the header it compiles
against, exactly as it does for `PHPhotoLibraryChangeObserver`, and the protocol's metadata is not
emitted by either (measured: `nm` of the built `PHPhotoLibrary.o` carries no `__OBJC_PROTOCOL_$_` symbol,
for the change observer either).

Source: the header of iOS 16.4 for the declarations, the codes and the "private queue" sentence;
`ALAssetsLibrary` of an iPhone 4S running 6.1.3 for what the release answers, measured by
`tests/backports/device/photosavailability13.m` through `tests/backports/device/photos/run.sh`. The
other three availability codes (3114, 3142, 3143) are the header's, named here as unreachable on this
release rather than carried.

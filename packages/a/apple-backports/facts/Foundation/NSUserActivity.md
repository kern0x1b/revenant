# NSUserActivity, iOS 8

Introduced in iOS 8: a description of what the user is doing in an application, so the system can hand it to
another device (Handoff), index it (Spotlight) or offer it to the application again. iOS 9 added the expiry date, the
keywords, the required keys and the eligibility flags.

Source: the host's own Foundation, asked for every answer below and held against the port by the `useractivity` group of
`tests/backports/host/uikit2/run.sh`, which compiles the port with its names changed and puts it beside the system's
class. The shared caches of iOS 6.0 and 7.0 have no activity; the class first appears in the cache of iOS 8.0.

## What the port does as the system does

A new activity has the type it was given, an empty dictionary of user info, `needsSave` on, handoff eligibility on and
everything else off or `nil`. The user info is copied when it is set, `nil` reads back as an empty dictionary, and
`-addUserInfoEntriesFromDictionary:` merges. Setting a value does not change `needsSave`. A web page URL takes `http`
and `https` and raises `NSInvalidArgumentException` for any other scheme, with the system's reason; an activity with no
type raises the system's reason too when the application declares no `NSUserActivityTypes`, and takes the first
declared type when it does. `becomeCurrent` asks the delegate to save, once, after it returns and never at once,
turns `needsSave` off before it does, asks nothing when the activity is current already, and asks again after
`resignCurrent`; `invalidate` leaves the activity usable. `getContinuationStreamsWithCompletionHandler:` answers at
once, with no streams and `NSCocoaErrorDomain` 3328, which is what the system answers for an activity nobody
continues. The delegate is held weakly.

## What it cannot do

iOS 6 has no Handoff, no Spotlight index of activities and no continuation, so an activity is never advertised, indexed
or handed to another device, and the class is `inert`. The delegate messages `userActivityWasContinued:` and
`userActivity:didReceiveInputStream:outputStream:` and the application delegate's continuation messages are never sent.
The system saves a current activity again whenever `needsSave` is set; the port asks once, at `becomeCurrent`.
`eligibleForPrediction` (iOS 12) is carried the same way `eligibleForHandoff` and `eligibleForPublicIndexing` already
were: a plain stored `BOOL`, nothing acting on it. It starts off, unlike handoff: the host answers no for a new
activity, and an application opts in by setting it. Predictions rest on
a system daemon iOS 6 does not run either, exactly as Handoff and the Spotlight index do, and that reasoning did not
stop those two from being honest storage; it does not stop this one. Held against the host's real `NSUserActivity` by
`tests/backports/host/uikit2/useractivity_test.m`.

What later releases added - the referrer URL, the persistent identifier and the content attribute set - is not
declared, so `respondsToSelector:` answers no; the registry lists each that has a decision.
The class does not adopt `NSSecureCoding` or `NSCopying`, which is what the system's does not do either.

`targetContentIdentifier` (iOS 13) is declared and stored as a plain string, as the host's is, and nothing acts on it.

## What the delete class method answers here, and the three rows this family still owes

`+deleteSavedUserActivitiesWithPersistentIdentifiers:completionHandler:` is the 12.0 method, and its
signature and handler are read from the SDK's own `NSUserActivity.h:108`. What it would delete from is
the system's store of saved activities, and this package keeps none: `NSUserActivity` is the port's own
class, its state lives in the object, and nothing it writes survives the process. So the port answers
the contract - call the handler - and says in the log on every call that there was no store, which is the
difference between an answer and a caller left guessing (`NSUserActivity.m:245` for the sibling, `:253` for this one).

Three rows in this family are not answered by code, each for a measured reason:

- `-[NSUserActivityDelegate userActivityWasContinued:]` and
  `-[NSUserActivityDelegate userActivity:didReceiveInputStream:outputStream:]` (both 8.0, the
  `maximum` these rows already carry). Both are declared in the SDK's `NSUserActivity.h` (line 129 and
  :133) and both are *called by the system's continuation*, which is Handoff: 6.1.3 and 4.3 have no
  `continueUserActivity:` to call from and no other device to continue to, so nothing in a program the
  port serves reaches either selector. They are declarations plus a log line for the case where
  something does - which needs a host case that links the port's declaration beside a conforming object
  (the host has neither selector, so the read is sound), not yet written.
- `-[NSFilePresenter accommodatePresentedItemEvictionWithCompletionHandler:]` (17.4). **The sentence this
  file used to carry here was wrong in its second half, and the header it cited does not say it.** The
  claim was that the 16.4 `NSFilePresenter.h` declares no `@interface` "because the class is macOS's and
  its members are marked `API_UNAVAILABLE(ios, watchos, tvos)`". The first half holds and the reason
  does not. Measured on the 16.4 build SDK's own header, which is 18,251 bytes and 152 lines: it
  declares `@protocol NSFilePresenter<NSObject>` at `:20` and **no `@interface` of that name at all** -
  `grep -n "@interface" NSFilePresenter.h` is empty. Of its 20 declarations, exactly three carry an
  availability annotation, and only `:40` (`primaryPresentedItemURL`) is unavailable on iOS, reading
  `API_AVAILABLE(macos(10.8)) API_UNAVAILABLE(ios, watchos, tvos)`; `:97` and `:105` are explicitly
  available, `API_AVAILABLE(macos(10.13), ios(11.0)) API_UNAVAILABLE(watchos, tvos)`. The other 17
  carry none. The method this row is about is not in that header either -
  `grep -c accommodatePresentedItemEvictionWithCompletionHandler NSFilePresenter.h` is 0.
  **What settles its platform, and it settles it against the old sentence.** The 26.2 SDK
  `tools/intents/generate.sh` calls `SDK_262` (the coordinator's unpacked copy under
  `charon/.agent-work/sdk-26.2`) reads, at `NSFilePresenter.h:74`:

      - (void)accommodatePresentedItemEvictionWithCompletionHandler:(void (NS_SWIFT_SENDABLE ^)(NSError * _Nullable errorOrNil))completionHandler API_AVAILABLE(macos(14.4), ios(17.4)) API_UNAVAILABLE(watchos, tvos);

  **`ios(17.4)`, not a Catalyst annotation** - so the method **is** an iOS 17.4 API, and the sentence
  this paragraph used to carry ("a Mac Catalyst API, which is what this row's own `source` says", "it is
  a macOS surface, not one of the iOS releases the port carries") does not match the header it cites.
  The 2026-09-28 review of this family (`coordination/reviews/live/foundation.md`) found this first; the
  line above is that finding re-measured on the copy that is here now. The same 26.2 header declares
  `@protocol NSFilePresenter<NSObject>` at `:20` and no `@interface`, exactly as 16.4 does, so **neither
  iOS SDK has a class to hang a category on** - which is the real blocker and was true all along.
  What decides the row is older than both: `Foundation17ReleaseAbsences.md` read the 6.1.3 armv7 rung's
  own class census - 11,378 classes, 188,523 instance selectors - and found `class NSFilePresenter
  ABSENT` with `NSAttributedString` present as the control. So on the bands the row is in it is
  `absent` for the ordinary reason. **The owner decision this paragraph asked for is withdrawn**,
  because the question it rested on ("macOS surface or iOS surface?") is answered: iOS. What remains
  open is the review's other question, and it is a different one: 17.4 is below the ladder's newest rung,
  18.0, so whether an 18.0 band *owes* this method is a question about the port's band coverage, not
  about which platform declares it. Implementing it would take a whole `NSFilePresenter` - a
  presentation coordinator an application registers items with - which is a family of its own and not
  one method.
- `NSPredicateValidating` and `-[NSPredicate allowEvaluationWithValidator:error:]` (both 26.4). Their
  declarations are on **no SDK on this machine**: 0 files of the whole 16.4 build SDK name
  `NSPredicateValidating` and 0 name `allowEvaluationWithValidator`, where the same search returns 95
  files for `NSPredicate`, and 0 files of the 26.2 SDK name either either (88 there for `NSPredicate`,
  and 26.2 carries 129 Foundation header files to 16.4's 126). So the newer header does not have them
  either, and
  the pair's own `introduced` is **26.4** - above the newest SDK here and above the held ladder's newest
  rung (18.0), so the release's own metadata cannot settle it either. The old `source` said
  `SDK 26.5`, which is not on this machine at all. Without the declaration the validator's required
  selector and the method's return are unreadable, and writing them from the name would be a guess
  about a contract. They owe one SDK that declares them, which is a fetch and not an implementation. The measurements and the commands are in
  `facts/Foundation/NSPredicateValidating.md`, which is the page their rows name.

## The two continuation members, and how "nothing calls it" was measured

`-[NSUserActivityDelegate userActivityWasContinued:]` and
`-[NSUserActivityDelegate userActivity:didReceiveInputStream:outputStream:]` (both 8.0) are declared by
the SDK the port's programs are compiled against (`NSUserActivity.h:129` and `:133`) and belong to a
protocol an application's own delegate adopts. The caller is the system's **continuation** - Handoff
handing this device an activity another device sent - and the releases this package carries have none:
there is no `continueUserActivity:` to call from and no second device to continue to.

So they are `absent`, and the claim that status rests on is a claim about this package's own sources,
which is checkable. **The transcript below replaces one that cited `tools/called-sites.py`, which is not
in this repository** - a facts file naming a reader nobody can run is a claim with nothing behind it, and
the two rows' `source` fields cited that tool too. `grep` over the package's own sources is what is in
the tree, with the file count beside it:

```
$ cd packages/a/apple-backports
$ grep -rn "userActivityWasContinued\|userActivity:didReceiveInputStream:outputStream" --include="*.m" --include="*.h" --include="*.c" .
(no output; grep exits 1)
$ find . \( -name "*.m" -o -name "*.h" -o -name "*.c" \) | wc -l
2350
$ grep -rF "becomeCurrentWithPendingUnitCount:" --include="*.m" --include="*.h" --include="*.c" . | wc -l
8
```

**0 occurrences in 2,350 sources**, which is the strong form of the claim: the selector does not appear at
all, so nothing in the package can call it and no declaration of it can hide behind a send. The search's
own control is a selector the port does name, and it comes back with 8 in the same run - so the zero is
the package's and not the search's. The zero form is also a count over files, so a file that is not there
cannot be counted as empty:

```
$ grep -rc "userActivityWasContinued" --include="*.m" --include="*.h" . | grep -v ":0$"
(no output)
```

so a run that searched nothing cannot be mistaken for a run that found nothing.

The release side is measured too, and it is the half that decides the status word: neither
`NSUserActivity` nor `NSUserActivityDelegate` is in the 4.3 or the 6.1.3 rung's own name index - 0 of
the 317,453 names at 4.3 and 0 of the 568,965 at 6.1.3, with `UIView`, `NSObject` and `setObject:forKey:`
present in both as the control. That is `~/.charon/cache-index/<release>.names.gz` - the index
`tools/cache-index/build.py` writes, read here by `tools/cache-index/first-rung.lua`'s own `_names_of()`
over the bytes it holds.

**Both rows are `absent`**, which is the tree's word for "not there at all, so `respondsToSelector:`
answers honestly": the port declares neither protocol and has no caller, so there is no implementation
of ours and none of the release's on the bands these rows are in. An earlier commit in this series had
them as `ignored`, which the review was right to refuse: `ignored` means the call reaches the
*release's own* implementation, and on these bands there is not one.

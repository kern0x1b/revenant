# UIPointerInteraction and the pointer delegate, iOS 13.4

Introduced in iOS 13.4: the interaction a view is given to change the pointer of a trackpad or a mouse over it, and the two
protocols it talks to its delegate through. iOS 6 has no pointing device - no trackpad, no mouse, no hover - so the interaction
answers as an iPad without a pointer does: it can be made, added to a view and removed, and it never asks its delegate for anything, because a device with no pointing device never sends the delegate a request. That is the implementation for hardware the 4S lacks, not a stand-in.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointer` group), and the header of SDK 16.4. The host answers for a Mac pointer; nothing about the pointer itself is read here.

## As UIKit does

- `-initWithDelegate:` keeps the delegate **weakly**; nil is accepted and `-delegate` answers nil once the delegate is gone.
- `enabled` starts as YES and is kept as it is set; `-invalidate` changes nothing that can be read back.
- `view` is nil until the interaction is added to a view (`UIView+Interactions` sends `-willMoveToView:` and `-didMoveToView:`), moves
  with it from one view to another, and is nil again after it is removed.
- `-init` is answered as `-initWithDelegate:nil`, as the host's is although the header marks it unavailable.
- `-description` is `<UIPointerInteraction: 0x...>`, which is what the class inherits.

## What the port does

- Nothing more. No gesture recogniser is added to the view and the delegate is never sent `-pointerInteraction:regionForRequest:defaultRegion:`,
  `-pointerInteraction:styleForRegion:`, `-pointerInteraction:willEnterRegion:animator:` or `-pointerInteraction:willExitRegion:animator:`. The
  first time an interaction is added to a view the port says so in the log, once: "this release has no pointing device, so the interaction is
  attached and its delegate is never called".
- `UIPointerInteractionAnimating` has no carrier: the release never hands an application an animator, so no object of the port adopts it.

## Where it differs

- Everything above about the pointer: nothing is drawn, nothing morphs and nothing is asked. An application that uses the interaction to add
  hover feedback loses only the feedback.

## Measured in a bundled window (2026-10-17)

`tests/backports/host/pointer-types` runs the same checks on the host's interaction and on the port's, in a bundled Mac Catalyst app with
the iPad idiom and a window, and compares the lines: 29 checks, all matching. Five planted controls fail (`interaction-enabled-not-stored`,
`interaction-delegate-strong`, and three on the button and the lock state), so the comparison can tell a wrong port from a right one.

- The class is `UIPointerInteraction` on both sides, from `-initWithDelegate:` and from `-init`, and `enabled` reads YES by default, NO after
  it is set NO, and YES after it is set YES.
- The delegate is kept while the application holds it and reads nil once the application has let go, on both sides.
- `view` is nil before the interaction is added, the view after `addInteraction:`, and nil after `removeInteraction:`; `view.interactions` lists
  the interaction only while it is added.

The host has a pointing device, which a bundled application cannot drive. Nothing here measures a hover, a region, a style or an animator:
those are the six `absent` rows of this page, and the delegate is never sent any of its messages on either side.

## The six `absent` rows of this page, measured (2026-10-01)

The six method rows above - the four `-[UIPointerInteractionDelegate pointerInteraction:...]` and the two
`-[UIPointerInteractionAnimating addAnimations:]` / `addCompletion:]` - carried "the header of SDK 16.4; nothing of a
release was read" as their `source`. That is an assertion. This is the measurement, the command that reproduces it and its
output, so a reviewer can settle any of the six without a second tool.

**The claim, in one line:** no release this port builds carries a single name beginning `UIPointerInteraction`, so
nothing can enter or leave a region and no object is ever handed to an application as an animator.

### The commands, from the root of the repository

```
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua UIPointerInteraction 6.1.3 4.3 16.0
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua UIHoverGesture        6.1.3 4.3 16.0
for r in 6.1.3 4.3; do
  for s in pointerInteraction:regionForRequest:defaultRegion: pointerInteraction:styleForRegion: \
           pointerInteraction:willEnterRegion:animator: pointerInteraction:willExitRegion:animator: \
           gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer: zzNonexistentSelectorForControl:
  do printf '%s %-62s %s\n' "$r" "$s" "$(strings -a ~/.charon/dyld/$r/dyld_shared_cache_armv7 | grep -cxF "$s")"; done
done
printf '%s\n' UIPointerInteraction UIPointerInteractionDelegate UIPointerInteractionAnimating \
  addAnimations: addCompletion: zzNonexistentNameForControl | xmake l tools/cache-index/first-rung.lua
```

### The output

```
6.1.3     ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming UIPointerInteraction 0
         classes 11378, of which UIPointerInteraction* 0
         protocols 1171, of which UIPointerInteraction* 0
4.3       ~/.charon/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming UIPointerInteraction 0
         classes 7187, of which UIPointerInteraction* 0
         protocols 564, of which UIPointerInteraction* 0
16.0      ~/.charon/dyld/16.0/dyld_shared_cache_arm64e
         images 2664, of which naming UIPointerInteraction 0
         classes 143137, of which UIPointerInteraction* 2 (UIPointerInteraction UIPointerInteractionAnimator)
         protocols 25549, of which UIPointerInteraction* 2 (UIPointerInteractionAnimating UIPointerInteractionDelegate)
control: 4 name(s) beginning UIPointerInteraction found in this run, so a zero on another rung is the release's and not the reader's
```

and the hover recogniser the port's own `UIHoverGestureRecognizer` stands in for, same shape:

```
6.1.3 / 4.3   classes UIHoverGesture* 0, protocols 0
16.0          classes 143137, of which UIHoverGesture* 2 (UIHoverGestureRecognizer UIHoverGestureRecognizerAccessibility)
control: 2 name(s) beginning UIHoverGesture found in this run
```

**The control is what makes the zero mean something.** A census printing 0 is ambiguous - the name may be absent, or the
reader may be looking at the wrong thing - so every release prints its image, class and protocol counts and a run finding
nothing anywhere is reported `CONTROL FAILED`. Four names found, all four at 16.0, means the reader was looking at the
right thing and 6.1.3 and 4.3 really hold none.

### The four selectors, and a control beside them

```
6.1.3  pointerInteraction:regionForRequest:defaultRegion:                       0
6.1.3  pointerInteraction:styleForRegion:                                       0
6.1.3  pointerInteraction:willEnterRegion:animator:                             0
6.1.3  pointerInteraction:willExitRegion:animator:                              0
6.1.3  gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:  15
6.1.3  zzNonexistentSelectorForControl:                                         0
4.3    the same four, 0;  gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer: 9
```

`gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:` is the control for the grep: a delegate selector of
the same shape, in the same cache, found 15 and 9 times. `zzNonexistentSelectorForControl:` is the control for the grep
itself: 0 everywhere, as it must be.

### The bare selectors of the two animator rows are NOT the answer

`addAnimations:` reads **8.0** and `addCompletion:` reads **9.0** in the ladder, where the pointer names all read 16.0.
That is the documented trap - `fileSystemRepresentation` reads 3.0 and belongs to another class - and it is why these two
rows are argued from the **protocol**, not from the selector:

```
UIPointerInteraction              16.0
UIPointerInteractionDelegate      16.0
UIPointerInteractionAnimating     16.0
addAnimations:                    8.0     <- another class's
addCompletion:                    9.0     <- another class's
zzNonexistentNameForControl       NONE    <- the control
```

No release below 16.0 declares `UIPointerInteractionAnimating`, so no object of the port conforms to it and nothing sends it
either of its two messages. The 8.0 and 9.0 rungs belong to other classes' selectors and say nothing about this owner; had
they been taken at face value, `implemented` would have been written for an owner that does not exist on any release the port
builds.

### What a reader should take from this

All six rows stay `absent`, and the verdict is now a measurement rather than a queue entry: **0 classes and 0 protocols of the
prefix at 6.1.3 and at 4.3, 0 of the four selectors in both caches, control passed in the same run, and the two animator rows
argued from their protocol because their bare selectors read other classes' rungs.** No object is owed: a `.m` here would
define a delegate callback with nothing to deliver it and export no symbol any release does not already have.

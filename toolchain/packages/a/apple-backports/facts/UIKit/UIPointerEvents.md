# Pointer members of UIEvent, UIGestureRecognizer, UITapGestureRecognizer and UIButton, iOS 13.4

Introduced in iOS 13.4: which buttons and modifier keys an event came with, the button a tap needs, a recogniser's hook to leave an event out,
and a button's built-in pointer interaction. iOS 6 delivers touches only, so the events carry nothing to report.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointercategories` group), and the header of SDK 16.4.

## As UIKit does

- `UIEventButtonMaskForButtonNumber(n)` is 1 for `n` of 0 or 1, `1 << (n - 1)` up to the largest bit the type keeps but two, and 0 for a
  negative number or a larger one: 62 gives 2^61 and 63 gives 0 on a 64-bit host.
- `UITapGestureRecognizer.buttonMaskRequired` starts as `UIEventButtonMaskPrimary`, keeps any positive value, and raises
  `NSInternalInconsistencyException` "buttonMaskRequired must be greater than 0" for zero or less.
- `-[UIGestureRecognizer shouldReceiveEvent:]` answers YES.
- `UIButton.pointerInteractionEnabled` is NO at first. Setting `pointerStyleProvider` to a block turns it on; the getter answers the block that was
  set. The first turn-on adds one `UIPointerInteraction` to the button's `interactions`; turning it off keeps the interaction and the provider,
  and turning it on again adds no second.

## What the port answers

- `UIEvent.modifierFlags`, `UIEvent.buttonMask`, `UIGestureRecognizer.modifierFlags` and `UIGestureRecognizer.buttonMask` are 0 always: no modifier
  is held and no button is pressed, since every event is a touch. Nothing was read from a release for the button mask of a finger; the
  header says the tap's mask is only evaluated for indirect input devices.
- The interaction the button adds is the port's `UIPointerInteraction`, and never asks the provider for a style.
- `-gestureRecognizer:shouldReceiveEvent:` of a recogniser's delegate is never sent. That is measured below, and it is measured
  class-scoped because the owner **is** carried at both band ends - the one row of this file where the read is a real question.

## `UIButton` pointer members, measured in a bundled window (2026-10-17)

`tests/backports/host/pointer-types` compares the host's button with the port's, in the same bundled app as the interaction checks: 29
checks in all, matching. The button's `pointerInteractionEnabled` reads NO on a new button, YES after it is set YES, NO after it is set NO;
`pointerStyleProvider` reads nil by default, the block set after it is set, and nil after it is cleared. Setting a provider turns the
interaction on (`pointerInteractionEnabled` reads YES), on both sides. Five planted controls fail, including `button-enabled-not-stored` and
`button-provider-not-kept`. The provider is never called on either side: a bundled application has no pointer to drive it with.

## `-[UIGestureRecognizerDelegate gestureRecognizer:shouldReceiveEvent:]`, measured (2026-10-01)

The row carried "the header of SDK 16.4; nothing of a release was read" as its `source`, and its reason - "the release asks a delegate
about touches, never about an event" - was true but unmeasured. This is the measurement.

### The commands, from the root of the repository

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
awk -F'\t' '$1=="protocol" && $2=="UIGestureRecognizerDelegate"' inv-6.1.3.tsv
for r in 6.1.3 4.3; do
  for s in gestureRecognizer:shouldReceiveEvent: shouldReceiveEvent: \
           gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer: zzNonexistentSelectorForControl:
  do printf '%s %-62s %s\n' "$r" "$s" "$(strings -a ~/.charon/dyld/$r/dyld_shared_cache_armv7 | grep -cxF "$s")"; done
done
```

### The protocol at both band ends, in full

```
6.1.3  protocol UIGestureRecognizerDelegate
       -gestureRecognizer:shouldReceiveTouch:
       -gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:
       -gestureRecognizerShouldBegin:
4.3    protocol UIGestureRecognizerDelegate
       -gestureRecognizer:shouldReceiveTouch:
       -gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:
       -gestureRecognizerShouldBegin:
```

Three messages, the same three at both ends, and `gestureRecognizer:shouldReceiveEvent:` is not one of them. `UIGestureRecognizer`
itself **is** carried, and carries the private `-_delegateShouldReceiveTouch:` - which is what a recogniser of this era calls instead.
It asks about a **touch**, not about an event. That is the whole of the absence, and it is the release's own, not the port's.

### The selectors, and the control beside them

```
6.1.3  gestureRecognizer:shouldReceiveEvent:                                 0
6.1.3  shouldReceiveEvent:                                                   0
6.1.3  gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:  15
6.1.3  zzNonexistentSelectorForControl:                                        0
4.3    gestureRecognizer:shouldReceiveEvent:                                 0
4.3    shouldReceiveEvent:                                                   0
4.3    gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:   9
```

The third line is the control for the grep: another member of the same protocol, in the same cache, found 15 and 9 times. The fourth is
the control for the grep itself: 0, as it must be.

### What this says about the row beside it, and what a caller gets

`shouldReceiveEvent:` is **0 in both caches**, so the release's `UIGestureRecognizer` does not have that method either. That is why
`-[UIGestureRecognizer shouldReceiveEvent:]` is `implemented`: the port's category **adds** a selector no release the port builds
carries, rather than replacing one, which is the condition `+load` and `attach.c` care about. Had the release carried it, a category
replacing a release method would be the thing to check, and it is not what happens here.

For a caller the consequence is the row's `effect`: the port's `-shouldReceiveEvent:` answers YES, every event reaches the recogniser,
and the 13.4 delegate hook is never consulted - because on this release there is no code that consults it.

## `UIButton.hovered`, iOS 15

`-[UIButton isHovered]` answers NO, always (`UIKit/UIButton+Hover15.m`). A button is hovered only while a pointer rests over it, and the
release delivers no hover event at all - the port's `UIHoverGestureRecognizer` never leaves the possible state for the same reason - so NO
is the answer any device without a pointer gives, not a placeholder. The registry lists the getter, `-[UIButton isHovered]`, since the
property is readonly and has no setter to spell it. Ladder, by `objc.inventory` on each cache with `initWithBarButtonSystemItem:menu:` of
iOS 14 as the positive control and an invented selector as the negative one: `isHovered` is not in `UIButton`'s methods in 6.1.3 or 12.0
and is in 16.0 and 18.0; the ladder has no 13-15 cache, so it bounds the release to 12.0-16.0 and `introduced` stays the header's 15.0.
Not measured on a device.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `-[UIButton isHovered]`: NO.

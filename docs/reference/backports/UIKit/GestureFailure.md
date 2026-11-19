# Dynamic gesture failure requirements on iOS 6.1.3

`UIGestureRecognizer+Failure7.m` gives iOS 6 the iOS 7 `UIGestureRecognizerDelegate` failure methods by adding UIKit 6's private names to a delegate class at `setDelegate:` time when that class implements the public ones, and forwarding from the private names to the public ones. Delegates that implement neither public method keep the stock `respondsToSelector:` answers, so UIKit leaves their capability bits clear and does not run the arbitration loop for them. No recognizer enumeration or per-touch work is done by the backport.

## What iOS 6.1.3 has

Measured from `.cache/dyld/6.1.3/dyld_shared_cache_armv7`, not on a device by this worker:

- `selectors_armv7.txt` lines 9098, 9101 and 21104: the failure selectors are `_gestureRecognizer:shouldRequireFailureOfGestureRecognizer:`, `_gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:` and the recognizer hook `_shouldRequireFailureOfGestureRecognizer:`. The public `gestureRecognizer:shouldRequireFailureOfGestureRecognizer:` and `gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:` are absent; only `shouldReceiveTouch:` and `shouldRecognizeSimultaneouslyWithGestureRecognizer:` are public delegates.
- `objc.inventory` of the cache: the two private delegate methods are implemented on `UIPopoverController`, `PLStackView`, `MFDragManager` and `MPGobblerGestureRecognizer`; the private recognizer hook on `UIGestureRecognizer` and `UITapGestureRecognizer`. No class implements either public selector. `-[UIGestureRecognizer _shouldRequireFailureOfGestureRecognizer:]` (`0x3304df2c`) is two instructions and returns NO.
- UIKit extracted to a scratch Mach-O and disassembled with `llvm-objdump --triple=thumbv7-apple-ios6.1 --mcpu=cortex-a8`. Its selector references are `0x397957bc` (private shouldRequireFailureOf), `0x397957c0` (private shouldBeRequiredToFailBy) and `0x39795820` (private recognizer hook). There is no reference to either public selector: UIKit 6 never sends them.

## Who asks, when, and with which arguments

- `0x32f7f318` and `0x32f7f33e` probe the delegate with `respondsToSelector:` for the two private names when the delegate is set. The answers are cached as bits of a 16-bit field on the recognizer: `0x20` for private shouldRequireFailureOf, `0x40` for private shouldBeRequiredToFailBy, `0x2000` for the recognizer hook.
- `0x33017054` is the dynamic arbitration. It returns early unless the cached mask intersects `0x2060`, then walks the other recognizers (`0x3301713e` to `0x33017218`), skipping the recognizer itself (`0x33017154`). It calls the private recognizer hook with `(self, other)` at `0x330171b2`, the delegate's private shouldRequireFailureOf with `(self, other)` at `0x330171cc`, and the delegate's private shouldBeRequiredToFailBy with `(self, other)` at `0x330171f4`. A YES answer calls an internal helper at `0x330171e8` or `0x33017210`; the latter swaps the two arguments, so the other recognizer waits for this one. The argument order and both directions are the same as the iOS 7 public pair.

The semantics are therefore identical under different names. A delegate that implements only the iOS 7 public methods is never asked, because its `respondsToSelector:` answer to the private names is NO and the cached bits stay clear. A competing pan wins the touch and an edge swipe back does not close the chat. On 2026-11-19 the coordinator's phone probe (`telegram-build/tools/memprobe/gesturefix.c`) added the two private names to the delegate classes and forwarding to the public ones; the edge swipe then closed the chat (screen similarity 0.999 against 0.46-0.57 without it).

## The backport

`NSObject (RevenantGestureFailure7)` implements the two private delegate names for every object. Each implementation calls the matching iOS 7 public method only when the receiver responds to it, and answers NO otherwise. A class that implements a private name itself still wins, so the system's own delegates keep their behaviour. The category is in `libUIKitBackports.dylib`, loaded before any recognizer is made, so the private names resolve at the moment UIKit takes the `respondsToSelector:` bits.

`UIGestureRecognizer (RevenantFailure7)` declares both public recognizer hooks, which answer NO by default, and implements the private hook `_shouldRequireFailureOfGestureRecognizer:` by forwarding to the public `shouldRequireFailureOfGestureRecognizer:`. A subclass that overrides the public hook therefore reaches UIKit's private path; system subclasses that override the private hook keep theirs. There is no private counterpart of `shouldBeRequiredToFailByGestureRecognizer:` in 6.1.3, so that public hook is available to callers but UIKit 6 does not consult it on a recognizer.

The one-shot `addGestureRecognizer:` swizzle and static `requireGestureRecognizerToFail:` arbitration that this file previously carried are removed: they were a second, static mechanism that only saw recognizers added through `UIView` and never re-evaluated, while UIKit 6 already has the dynamic path the bridge restores.

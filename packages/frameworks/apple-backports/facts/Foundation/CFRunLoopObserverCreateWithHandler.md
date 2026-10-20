# CFRunLoopObserverCreateWithHandler

iOS 5.0 adds the block form of `CFRunLoopObserverCreate`. The package carries it for releases before 5.0 in
`Foundation/CFRunLoopObserverHandler.m`, over `CFRunLoopObserverCreate`, which CoreFoundation has had since 2.0: the
observer's context holds the block, `Block_copy` when the observer takes it and `Block_release` when the observer goes,
and the callout calls it with the observer and the activity.

Held against the host's own function in `tests/backports/host/uikit2` (group `runloopobserver`, 8 checks): for four
combinations of activities, repeating and order, the backport's observer sees the same activities in the same order as
the system's over three turns of the loop, answers the same activities, repeats, order and validity, hands the block
itself as the observer, keeps the block alive while it lives and lets it go once released. Negative control: without
the release callback the block outlives the observer and four checks fail.

Used by the package itself: `UIKit/UITextField+SelectionChange13.m`, which below 5.0 called a NULL weak import before.

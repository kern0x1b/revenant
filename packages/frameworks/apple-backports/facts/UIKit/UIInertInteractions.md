# The interactions that have nothing to react to, iOS 13 and 14

`UILargeContentViewerInteraction`, `UIScreenshotService`, `UITextFormattingCoordinator`, `UITextPlaceholder`, `UIScribbleInteraction`,
`UIIndirectScribbleInteraction` and `UIPointerLockState` are carried as the objects an application makes and holds so that one that
links them launches. What each would react to is not on the release, so each is `inert`: made, kept, added to a view and removed like
its kin, never called back, and says so once in the log the first time it is used.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked for every default, and held against the backport by the `inert`
group of `tests/backports/host/uikit2`; `tests/backports/device/uirest.m` for a device.

## Large content viewer

The viewer shows a magnified item when a person holds a control while the accessibility text size is large; iOS 6 has neither. The
five members of `UILargeContentViewerItem` are kept on a view - no viewer, NO, no title, no image, no scaling, zero insets to begin
with - and nothing reads them. An interaction made with a delegate keeps it weakly and has no `gestureRecognizerForExclusionRelationship`
until it is added to a view, when it has a disabled recogniser on that view, as the host has; `+enabled` answers NO and the
notification of its change is never posted. The first interaction added says so in the log.

## Screenshot service

A window scene answers one `UIScreenshotService`, always the same, that keeps its delegate weakly and its scene weakly. iOS 6 takes a
screenshot itself and asks the application for nothing, so the delegate is never asked for a PDF; setting one says so in the log.

## Text formatting coordinator

The font panel belongs to Mac Catalyst. The coordinator is made, keeps its delegate weakly, is never visible (`+fontPanelVisible` NO),
takes selected attributes and forgets them, and `+toggleFontPanel:` does nothing and says so.

## Text placeholder

A value with no rects, as the host answers for one made with `init`; a text input sets them, and none of the release's does.

## Scribble

Handwriting with Apple Pencil is not on the release. Both interactions are made, with `-init` too as the host allows, keep their
delegate weakly, never handle writing, and `+pencilInputExpected` is NO. The delegates' messages are never sent.

The eleven members of `UIScribbleInteractionDelegate` and `UIIndirectScribbleInteractionDelegate` are `absent` rather than inert, and
the difference is measured rather than assumed: **the release carries neither protocol.** `objc.inventory`, read with

    REVENANT_ROOT=<checkout> xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
    REVENANT_ROOT=<checkout> xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7

finds `UIScribbleInteractionDelegate`, `UIIndirectScribbleInteractionDelegate`, `UIScribbleInteraction` and
`UIIndirectScribbleInteraction` as neither a class nor a protocol in either cache. The same two runs read 11378 classes and 1171
protocols on 6.1.3 and 7187 and 564 on 4.3, which is the control: the reader saw the whole of both caches, so the four zeros are the
releases' and not the reader's. So there is nothing on the release for a delegate method to override, and no element, no frame, no
focus and no writing to ask about; the two interactions the port builds (`UIKit/UIScribbleInteraction.m`) attach to a view, keep
their delegate weakly, and say so once in the log. An application that implements any of the eleven is never called, which is the
effect each row records.

## Pointer lock

A scene answers one `UIPointerLockState`, always the same and never locked; `prefersPointerLocked` of a view controller is NO,
`childViewControllerForPointerLock` nil, and asking for an update says so once. The notification's name is `UIPointerLockStateDidChangeNotification`,
its user info key `scene`, and it is never posted.

Measured in a bundled window (2026-10-17), by `tests/backports/host/pointer-types`, with the host's own lock state beside the port's: the class
is `UIPointerLockState` on both sides, made by `+new` and by `alloc` and `init` (the header marks both unavailable to the compiler, so the test
calls them through the runtime); `locked` reads NO by default; the scene's state is the same object on every read; `prefersPointerLocked` reads
NO before and after `setNeedsUpdateOfPrefersPointerLocked`; `childViewControllerForPointerLock` is nil. The host reads the same values, so
these rows are measured as they stand. Whether the host's lock ever engages needs a pointer the bundled app cannot drive, and is not claimed.

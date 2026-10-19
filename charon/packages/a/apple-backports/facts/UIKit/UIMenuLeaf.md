# UIMenuLeaf, iOS 16.0

The protocol `UIAction` and `UICommand` take in iOS 16, for a menu element that runs something: `title`, `image`,
`discoverabilityTitle`, `attributes`, `state`, `sender`, `presentationSourceItem` and `-performWithSender:target:` (SDK 16.4,
`UIMenuLeaf.h`; `selectedImage` and `repeatBehavior` joined it in iOS 17 and are not in this SDK).

## The protocol

The port's `UIAction.m` and `UICommand.m` are compiled against the 16.4 header, which declares both classes as adopting it, so the
protocol and both conformances were already in the library before any member was: `nm -a` on `UIAction.o`, `UICommand.o` and
`libUIKitBackports.dylib` of a gate build shows `__OBJC_PROTOCOL_$_UIMenuLeaf`. The registry row's old effect ("NSProtocolFromString
answers nil") was therefore false; what was missing were three members, and a caller going through the protocol found
`conformsToProtocol:` YES and then raised on `performWithSender:target:`. That the runtime of 6.1.3 registers the protocol from the
library, so `NSProtocolFromString(@"UIMenuLeaf")` answers it, is reasoned from how the runtime reads a loaded image's protocol list,
not measured on a device.

## The members the port added (`UIKit/UIMenuLeaf16.m`)

- `-[UIAction performWithSender:target:]` runs the handler with `sender` set to the sender while it runs, the path the port's own
  controls, bar items and context menu already take; the target is not used, since an action has a handler and no selector.
- `-[UICommand performWithSender:target:]` sends the command's action with `sendAction:to:from:forEvent:` to the target, or up the
  responder chain from the first responder when the target is nil, with the command as the sender of the message - what the port's
  context menu already did - and `sender` set to the sender while it runs. The context menu now goes through it with its view.
- `UICommand.sender` is that sender while the action runs, nil otherwise, as `UIAction.sender` (`UIAction.md`).
- `presentationSourceItem` of both answers the sender while the element runs when it is a view or a bar button item - what a popover
  can hang from - and nil otherwise. The header's example is a button's menu giving the button; which sender the system gives for a
  context menu was not read. `UIPopoverPresentationControllerSourceItem` itself is not carried (its row says why), so the object
  answered is a plain `UIView` or `UIBarButtonItem` that does not claim the protocol.

Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-leaf-anchor-key.log`, an invented protocol and selector as
the negative controls): the protocol is in neither the 6.1.3 nor the 12.0 cache and in 16.0 and 18.0; `UIAction` and `UICommand` are
not in 12.0, and `performWithSender:target:`, `presentationSourceItem` and `sender` are in both classes in 16.0 and 18.0. There is no
13-15 cache, so `introduced` stays the header's 16.0. None of the behaviour was held against the system; the device run is the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked that the runtime has `UIMenuLeaf`, that `UIAction` and `UICommand` conform, and an action's `performWithSender:target:` with `sender` and `presentationSourceItem` while it runs and nil after; all as described. A command's `performWithSender:target:` raised nothing, but its action could not be seen: a process has no `UIApplication` to send it.

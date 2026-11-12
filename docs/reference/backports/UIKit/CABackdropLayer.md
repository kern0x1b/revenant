# `CABackdropLayer` on iOS 6

`CABackdropLayer` is the QuartzCore layer that shows what is behind it, through the filters set on it. It is not public:
no SDK header declares it and no `.tbd` exports it (`NSClassFromString` finds it by name only), so the exports report has no
key for it and counts it nowhere. It is in the backports as an exception to the rule that they cover public SDK members,
beside `__NSConcreteUUID` (`frameworks/Backports/README.md`, "Public symbols"), because applications look it up by name and
an iOS 6 target has no class of that name.

## Why it is here

Telegram's glass views create the layer with `NSClassFromString("CABackdropLayer")` and message it through method
pointers, so no link-time symbol is involved and a missing class gives `nil` and a view that draws nothing: five components
do it (`LegacyGlassView` for the alerts and glass buttons, `EdgeEffect`, `LiquidGlassShapes`, `SpaceWarpView`,
`PeerInfoAvatarListNode`), and `UIViewController+Navigation.m` reads it by name too. A patch of each caller would
repeat the same fallback five times; one class that answers to the name fixes all of them, and any other application that
looks the class up the same way.

Measured on an iPhone 4S, iOS 6.1.3, with an injected probe: `CABackdropLayer` is missing, `CAFilter` is present
(`gaussianBlur`, `colorMatrix` and `variableBlur` answer `filterWithName:`), and `UIVisualEffectView` and `UIBlurEffect` come
from `libUIKitBackports.dylib`. Without the class, Telegram's confirmation alert and Network-error alert are see-through
panels: the text of the screen behind them reads straight through. With the class, the same alert is frosted and the text
behind it is no longer legible.

## What it does

- The class has the surface the callers use: `scale` (default `1.0`), `groupName`, `enabled` (default `YES`) and `filters`.
  The filters are stored and read back; they are never handed to `CALayer`, so the render server never sees a `CAFilter`
  it does not draw on iOS 6. Other keys the callers set by `setValue:forKey:` (`meshTransform` and the like) are kept by
  `CALayer`'s own key-value storage.
- It draws nothing itself. When the layer holds a `gaussianBlur` filter, belongs to a layer that is a `UIView`'s layer, and is
  enabled, it keeps a `UIVisualEffectView` (the backport: a capture of what is behind, blurred on the CPU at a quarter of
  the scale) as the bottom subview of that view, with the layer's frame, and follows the layer's frame and bounds.
  Removing the layer, disabling it, or setting filters without a `gaussianBlur` removes the effect view.
- It only blurs a panel: a layer whose smaller side is under 100 points (a glass button, a search pill, a toolbar) gets no effect
  view and stays as the caller draws it without the class, a translucent fill. See "Cost" for why.
- The blur style follows the filter: a `gaussianBlur` with `inputRadius` above 4 (Telegram's clear glass on iOS 6) takes
  `UIBlurEffectStyleExtraLight`, the others `UIBlurEffectStyleLight`.
- A `variableBlur` filter (the progressive blur of `EdgeEffect`, with a mask image) is stored and not drawn: a uniform blur
  would show a hard edge where the mask fades, which is worse than no blur.
- `scale`, `groupName`, the colour matrix and the mesh transform change nothing on screen on iOS 6.

## Registration

The file is `frameworks/Backports/src/UIKit/CABackdropLayer.m`, in `libUIKitBackports.dylib` beside `CASpringAnimation.m`
(the QuartzCore classes of the backports are built in that library). It uses `REVENANT_ALIAS_STATE` (`revenant_alias.h`): the
class is `RevenantCABackdropLayer`, a `CALayer` subclass, and its `+load` registers `CABackdropLayer` as a subclass of it
only when the runtime has no such class. Where the system has the class (iOS 7 and later), the system's answers every message
(`alloc`, `class`, `respondsToSelector:`) and this one is never instantiated. The package registers it when the library loads: nothing
is injected and no application is patched.

## Cost

The effect view is the backport's `UIVisualEffectView`, so the cost is that of its capture and blur: it renders the window layer
with the host view and everything above it hidden, and blurs the result at a quarter of the scale. The capture is the cost, not
the blur: on the iPhone 4S `renderInContext:` of the window took 3 ms to 207 ms on average per view in a 170 s log of the entry
screen, the country sheet and the alert (the views over the list rows and the panel over the entry screen were the slowest),
and it runs on the main thread. A first version of the class (an effect view for every glass layer) captured each of them
every half second even when nothing under it had changed, 1,493 captures in that log, 98 % of them unchanged. Besides the
alert, the three screens carry seven such layers, all of them buttons and pills 40 to 50 points high, which a blur adds
little to over a white screen.

Three rules keep it affordable (`CABackdropLayer.m`, `RevenantBackdrop.m`):

- A layer with a side under 100 points gets no effect view (above). Only panels are blurred: the confirmation alert is about 300
  by 150 points, a glass button or pill 40 to 50 high.
- A capture that matches the last delivered one is not blurred again, and the next capture waits longer: 0.5, 1, 2, then 4
  seconds, never less than three times what the last capture cost. "Matches" tolerates a change of up to 16 levels in a
  channel, and of up to 1 % of the pixels: Telegram's blinking caret under the alert changed the capture every half second and
  kept the first version at full price. The wait is dropped at once, to the cost floor, while the run loop is in
  `UITrackingRunLoopMode` (a finger on a scroll view, a deceleration), and when the host is laid out or its effect is set.
- A change that is not a layout or a touch (an animation that starts by itself behind a panel that has been still) is seen at the
  next capture, up to 4 seconds later.

Measured with an injected probe (process CPU of all threads, and display-link ticks on the main run loop), iPhone 4S, iOS 6.1.3,
Telegram 13.0.0 on its "Your Phone" screen, windows of 12 to 16 s, one run each, so a few points are noise:

| Screen                       | Without the class | First version | This version |
| ---------------------------- | ----------------- | ------------- | ------------ |
| Entry, idle                  | 8 %, 60.1 fps     | 22 %, 56.6    | 8 %, 60.0    |
| Country sheet, idle          | 18 %, 58.4        | 61 %, 36.6    | 15 %, 59.0   |
| Country sheet, list scrolled | 25 %, 52.1        | 68 %, 23.1    | 30 %, 50.4   |
| Confirmation alert, open     | 10 %, 60.0        | 53 %, 38.1    | 21 %, 56.7   |

The alert keeps its blur; the three other screens have no effect view at all, so they are back within a few points of the figures
without the class. The 11 % the alert still costs over them are its captures, about 0.2 s each every 4 s, during which the main
thread stops; the alert was measured three times in a row, 21 % and 56.7 to 56.8 fps each time.

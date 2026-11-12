# `CABackdropLayer` on iOS 6

`CABackdropLayer` is the QuartzCore layer that shows what is behind it, through the filters set on it. It is not public:
no SDK header declares it and no framework exports it (`NSClassFromString` finds it by name only). It is in the backports
as the second class the exports report lists as not public, beside `__NSConcreteUUID` (`frameworks/Backports/README.md`,
"Public symbols"), because applications look it up by name and an iOS 6 target has no class of that name.

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
with the host view and everything above it hidden, and blurs the result at a quarter of the scale. The measurement on the
iPhone 4S is below.

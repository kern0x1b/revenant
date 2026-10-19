# UIContextMenuInteraction, iOS 13.0 and 14.0

Introduced in iOS 13.0: the interaction a view is given to show a context menu on a long press or a right click, with a preview the view lifts
into, an animator handed to the delegate, and, since 14.0, a menu that can be updated while it is showing.

iOS 6 has none of the machinery: no menu view, no preview morph, no highlight of the source view, no animator for a presentation. The port
chooses the smallest thing that is honest - **the menu appears as an action sheet** - and says so once in the log the first time it is shown.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `menus`
group) for everything that can be asked without showing a menu, and the header of SDK 16.4. The sheet itself cannot be shown in a Mac
Catalyst tool or a bare device tool; it is exercised on an iPhone 4S or an iPad 2 only.

## As UIKit does

- `-initWithDelegate:` keeps the delegate **weakly**; nil is accepted; `-delegate` answers nil once the delegate is gone.
- `view` is nil until the interaction is added to a view (`UIView+Interactions` sends `-willMoveToView:` and `-didMoveToView:`), and nil again
  after it is removed.
- `-locationInView:` answers `(CGFLOAT_MAX, CGFLOAT_MAX)` when no interaction is in progress. While one is in progress the port
  answers the touch that began it, in the coordinates of the view asked about.
- `-dismissMenu` does nothing when no menu shows; `-updateVisibleMenuWithBlock:` does not call the block when none does.

## What the port does

1. Adding the interaction to a view puts a `UILongPressGestureRecognizer` on the view, and removing it takes the recognizer off. The host installs five
   private recognisers (secondary click, press, touch duration and two relationship recognisers); this is the one iOS 6 has an equivalent of.
2. When the long press begins, the interaction asks the delegate for a configuration at the touch. Nil means nothing happens.
3. It calls the configuration's action provider with an empty array and takes the `UIMenu` it returns. No menu, or one whose elements are all disabled or hidden,
   means nothing is shown and no callback is sent.
4. The menu becomes an action sheet:
   - elements that are `Disabled` or `Hidden` are left out; a menu with the `Inline` option contributes its children to the sheet, and any other submenu is
     a button whose title ends in a `›` and which opens a second sheet with its children;
   - the first element that is `Destructive` (or the first menu with the `Destructive` option) is the sheet's red button, which iOS 6 has one of and puts on
     top; the rest are ordinary buttons in the order of the menu;
   - a state of on puts a check mark before the title, mixed an en dash; a title that is empty falls back on the discoverability title, and an element with
     neither is left out; images are not drawn, since a sheet button has none;
   - a deferred element is asked for its elements, and the sheet waits up to 1.5 seconds for the answers;
   - the sheet has a Cancel button, anchored to the touch in a popover on an iPad and from the window's bottom on an iPhone.
5. `-contextMenuInteraction:willDisplayMenuForConfiguration:animator:` is sent before the sheet is shown, and `...willEndForConfiguration:animator:` when it is
   about to leave, with an animator that runs `-addAnimations:` at once and `-addCompletion:` after the sheet has been presented or has gone, and whose
   `previewViewController` is nil. Choosing an action calls its handler once the sheet is gone; Cancel and a tap outside end the interaction, with `willEnd` sent and no handler run.
6. `-updateVisibleMenuWithBlock:` (14.0) calls the block with a copy of the menu on screen and, if it returns a menu, shows the sheet again
   without animation with it; `-dismissMenu` cancels the sheet.

## What is not done, and how the registry records it

- `-contextMenuInteraction:previewForHighlightingMenuWithConfiguration:`, `...previewForDismissingMenuWithConfiguration:` and
  `...willPerformPreviewActionForMenuWithConfiguration:animator:` are **never called** (`absent`: the port sends none of them), and the preview provider of the configuration
  never runs; nothing is lifted, morphed or tapped.
- `UIContextMenuInteractionCommitAnimating` is never handed out.
- `menuAppearance` is **compact** always, where the host answers rich before a menu shows: a rich menu is the one with a preview, and there is none.
- A second touch or a rotation while the sheet shows is left to the sheet; the interaction does not follow the view as the host's menu does.
- One `Destructive` button is red at most; another `Destructive` element is an ordinary button.

## Commands in a menu

A `UICommand` (`UICommand.md`) is listed as an action is, with its title, its state and the destructive and disabled attributes;
choosing one sends its action down the responder chain from the application, with the command as the sender, where an action runs
its handler. Tables and collection views, and the controls and bar button items that have a menu, use this interaction
(`UIListContextMenus.md`, `UIControlMenus.md`).

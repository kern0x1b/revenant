# The keyboard notification for a new input on iOS 6

When the first responder moves to another text input and the keyboard stays on the screen, iOS 6 posts no keyboard notification,
not even when the keyboard changes its layout. An application that places its views from the window's keyboard height never
hears that the new input has focus. The backports tell it.

## What was seen

Telegram 13.0.0 on an iPhone 4S, iOS 6.1.3. The phone-number screen has the number pad up. A tap on the country row opens the
country sheet, whose search field takes focus and the keyboard turns into the letter keyboard, at the same frame
(`{0, 264, 320, 216}`). A probe that logs every `UIKeyboard*Notification` from launch saw four notifications, all at launch
(will and did, change frame and show, for the number pad) and none after the sheet opened. Display's window keeps the keyboard
height from the last `UIKeyboardWillChangeFrameNotification` and passes it to the sheet's layout only when it changes
(`WindowContent.swift`, `updateLayout` drops an update that leaves the layout equal), so the sheet's search pill stayed at the
bottom of the screen, 412 points down, behind the keyboard, and rose above the keyboard only after a tap in the field.

A notification posted by the probe settled what the cause is. `UIKeyboardWillChangeFrameNotification` with the unchanged frame did
nothing (the pill stayed at 412 through 168 samples of 50 ms). With a frame one point taller the pill moved to 195; a frame change
to "hidden" followed by the shown frame moved it to 412 and then to 196, directly above the keyboard.

## What the backports do

`UIKeyboard+InputSwitch.m` keeps the frame of the keyboard from the notifications UIKit posts, and the keyboard type of the input that
began editing last (`UITextFieldTextDidBeginEditingNotification`, `UITextViewTextDidBeginEditingNotification`). When an input begins
editing with a keyboard type that differs from the last one's, the keyboard is up and no keyboard notification arrives for 0.15 s,
it posts what a later iOS posts around a keyboard that changed: `UIKeyboardWillChangeFrameNotification` to a hidden frame (zero
height on the bottom edge), and back to the shown frame. Both go out in one run-loop turn with a layout pass of every window
between them, so that Display's window lays the sheet out once without the keyboard and once with it.

- Only a portrait keyboard that spans the screen's width and ends at its bottom edge is handled. A landscape or upside-down keyboard
  gets nothing.
- A notification UIKit posts itself within the 0.15 s keeps the shim out.
- The notifications carry `UIKeyboardIsLocalUserInfoKey`, the animation duration 0.25 and the begin and end frames; only the will
  notification is posted, not the did notification.
- For other applications the pair is a keyboard that went away and came back within one turn: a scroll inset or a toolbar that follows
  `UIKeyboardWillChangeFrameNotification` starts an animation to its old value at once, and nothing moves that can be seen.
  Applications that react to the same notification by closing something would see it; that was not measured on another application.

## Where it is not claimed

- Inputs of the same keyboard type: iOS 6 posts nothing and so do the backports. An application that needed the notification there
  is not helped.
- The behaviour of the later iOS is the reason for the pair, but it was not measured: no iPhone with it was at hand. What is
  measured is Telegram's reaction on 6.1.3.
- `UIKeyboardDidChangeFrameNotification` is not posted.

## Tests

`frameworks/Backports/tests/UIKit/keyboard_switch_test.m` (host, target `UIKitBackports_keyboard_switch_test`) checks the decision
(`RevenantKeyboardSwitch.m`): no switch for the first input or the same type, a switch for a new type with the keyboard up, the shim
staying out when UIKit posted, no switch without a keyboard, the hidden frame, and the frames it leaves alone (a keyboard below the
screen, an empty frame, landscape, upside-down). 17 checks, and the negative run fails. The posting itself is UIKit and ran on the
phone: Telegram's country sheet after the deb of this change, the search pill at 196 points from the first frame it appears.

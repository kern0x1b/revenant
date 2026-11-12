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
## Scope: who is affected

The shim lives in `libUIKitBackports.dylib` and runs in every process that loads it, not in Telegram only: any application built with the
Revenant toolchain that links the Backports, on any phone that has the package. Stock iOS 6 applications (SpringBoard, Mail, Safari, Phone,
Messages, Settings) do not load the library and are not touched. The pair is posted only when all of these hold:

1. a `UITextField` or `UITextView` posts its begin-editing notification (a `UISearchBar`'s text field is a `UITextField` and counts);
2. the last keyboard notification left a keyboard on the screen: full screen width, ending at the bottom edge, portrait;
3. the `keyboardType` of that input differs from the one of the input that began editing before it (a number pad then letters, an email keyboard
   then the default one, and so on);
4. UIKit posted no keyboard notification for 0.15 s after the input began editing.

It is not posted for the first input after launch (UIKit shows the keyboard and posts itself), for an input of the same keyboard type, for a
landscape or upside-down keyboard, when the keyboard is hidden, and for inputs in web views (no begin-editing notification reaches it). There
is no switch to turn it off for one application.

What an application sees: two `UIKeyboardWillChangeFrameNotification` in one run-loop turn, the first with an end frame of zero height on the
bottom edge, the second with the keyboard's frame (begin and end frames swapped, duration 0.25, `UIKeyboardIsLocalUserInfoKey` set). An
application that moves a scroll inset or a toolbar from the notification starts a second animation back to the value it already has. An
application that does something else on a keyboard change (closes an accessory, saves a draft, scrolls a field into view) does it twice.

Not measured: the reaction of any application other than Telegram, and of a later iOS to the same sequence. The 0.15 s wait and the choice of the
keyboard type as the trigger are decisions made from the one case that was measured (the country sheet), not from a survey of applications.

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

# UIScrollView.keyboardDismissMode, iOS 7

Introduced in iOS 7.0: what a drag of a scroll view does to the keyboard - nothing (`None`, the default), dismisses it when the
drag starts (`OnDrag`), or dismisses it when the finger reaches it (`Interactive`).

Source: the host's own UIKit under Mac Catalyst for the default (none, on a scroll view, a table view and a collection view) and
for what is stored: the value is kept as a number whatever it is (3, 7 and -1 come back as they were set). The behaviour is held
by `device/keyboarddismiss.m`, which puts a text field outside a scroll view, opens the keyboard on it and drags a real finger
(IOHID) over the scroll view.

## What the port does

The property is kept per scroll view. A mode other than none puts one target on the scroll view's pan recognizer. `OnDrag` resigns
the first responder of the application, wherever it is - a field outside the scroll view, as the input bar of a chat is - when the
pan begins. `Interactive` resigns it when the finger, in the window's coordinates, is at or below the top of the keyboard the last
`UIKeyboardDidShowNotification` gave. Any other value does nothing, as none.

## What differs

The release's interactive mode moves the keyboard with the finger and takes it away on a fling; iOS 6 gives no way to move the
keyboard, so the port takes it away in one step when the finger reaches it, and never puts it back.

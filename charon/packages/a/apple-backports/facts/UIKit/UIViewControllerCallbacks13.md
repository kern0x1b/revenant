# Callbacks the release does not send: view controllers and text fields

Source: the header of SDK 26 for the signatures and the host's own UIKit for the order of the calls, held against the backport by the
`appearing` group of `tests/backports/host/uikit2` and `tests/backports/device/uirest.m` on a device.

## viewIsAppearing:

`-[UIViewController viewIsAppearing:]` is sent by iOS 13 and later to a view controller after `viewWillAppear:` has returned - the
view is in the hierarchy and has its size - and before `viewDidAppear:`, once for each appearance. iOS 6 sends nothing, so the port
does. Every class in a controller's chain that has a `viewWillAppear:` of its own has it wrapped, when the first controller of that
class is made: `-initWithNibName:bundle:` and `-initWithCoder:` of the release are wrapped to wrap the chain of the object that comes
out of them. The wrapper counts how deep it is in `viewWillAppear:` calls on the controller, and when the outermost call returns it
sends `viewIsAppearing:`. A subclass that calls `super` before or after its own work, a class that does not override the method at all
and a controller made from a coder are all called, once. The default does nothing.

The host's UIKit sends `viewIsAppearing:` itself, so the group renames the port's selector and runs both.

## The unwind segue question

iOS 13 renamed `canPerformUnwindSegueAction:fromViewController:withSender:` to `...sender:`. The release sends the old one and an
application built for iOS 13 overrides the new one. The port wraps the old method so that it asks the new one, whose default is the
release's own implementation of the old, kept as it was; a subclass that overrides the old one still gets its call and its `super`
reaches the release. The host's own old method already forwards to the new one, so there is no host test; `uirest.m` checks the
three cases on a device.

## textFieldDidChangeSelection:

`-[UITextFieldDelegate textFieldDidChangeSelection:]` is sent when the selection of a text field changes, and the release has no
signal for a caret that moves by the finger. While a field is being edited the port watches its `selectedTextRange` from a run loop
observer that runs before the loop sleeps, and sends the message when the offsets changed, and once when editing begins. The message
comes at the end of the turn of the run loop in which the change was made, not inside it, and for a change that the field makes and
undoes in one turn there is none.

## Scene delegates

`-[UIWindowSceneDelegate windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:]` is sent when the status bar
orientation changes, with the scene's coordinate space (the one object it has), the orientation it had and the collection it had, made
for that orientation. The other scene messages are those of `UIScene.md`.

## Never sent

The dismissal methods of `UIAdaptivePresentationControllerDelegate`, the attributed and plain user input labels of a picker view's
accessibility delegate, the secure state methods of the application delegate, `application:handlerForIntent:` and the two marked text
methods of a text document proxy are declared and never sent, since what would send them is not on the release: a swipe to dismiss a
modal, Voice Control, secure state restoration, Intents and keyboard extensions.

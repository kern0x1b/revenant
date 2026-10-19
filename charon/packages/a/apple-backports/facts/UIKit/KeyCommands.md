# Key commands, iOS 7

From iOS 7 a responder answers `-keyCommands`, an array of `UIKeyCommand`, and a key pressed on a hardware keyboard runs the
action of the first command that matches it. A command is made of an input string, the modifier flags and an action;
`UIKeyInputUpArrow`, `UIKeyInputDownArrow`, `UIKeyInputLeftArrow`, `UIKeyInputRightArrow` and `UIKeyInputEscape` name the keys
that have no character.

The release hands a hardware key to the application as a GraphicsServices key event, which `-[UIApplication handleKeyEvent:]`
takes, walks up the responder chain and gives to the keyboard as text. The port replaces `-handleKeyEvent:` and looks for a
command first. For a key going down (a repeating key fires again each time) it takes the characters the key makes without
modifiers, or the arrow or escape it is (by the key code of the key on a keyboard, and by the function-key characters
`0xF700` to `0xF703` and `0x1B`), and the modifier flags shift, control, alternate and command, which are the same bits UIKit
gives to `UIKeyModifierShift`, `Control`, `Alternate` and `Command` (caps lock is not looked at). It builds the chain from the
first responder of the key window, or from the window when there is none, through every `nextResponder`, and then the
application delegate; asks each for `-keyCommands`; and for a command whose input equals the key's (case-insensitively) and
whose flags equal the key's exactly, sends the action with `-sendAction:to:from:forEvent:` to that responder, with the command as
the sender. The first command a responder performs ends the search and the key is not given to the keyboard; a command that its
responder does not perform (no such method) is passed over and the search goes on outwards. Every other key, and every key
released, goes on as before, so typing in a text field is not changed.

What it does not do: there is no discoverability overlay (holding the command key shows nothing), `UIKeyCommand`'s
`wantsPriorityOverSystemBehavior` and the two layout properties stay inert as `UIKeyCommandPriority.md` (same folder) describes, and a key
command does not fire while a keyboard of the application other than a hardware one is used, because the software keyboard
sends no key events.

Source: `-[UIApplication handleKeyEvent:]`, `-[UIResponder _handleKeyEvent:]` and `-[UIKeyboardImpl handleKeyEvent:]` as they
run on an iPhone 4S with iOS 6.1.3 (a key event handed to the first was seen walking the responder chain and reaching the
text field); `tests/backports/device/keycommand.m`, which hands the application key events made with `GSEventCreateKeyEvent`
at that same entry. No hardware keyboard was attached to a device, so the arrival of a real keyboard's event at
`-handleKeyEvent:` is taken from the release's own call structure and is not measured; the key codes of the arrows and of
escape are the USB usage numbers and are not measured either.

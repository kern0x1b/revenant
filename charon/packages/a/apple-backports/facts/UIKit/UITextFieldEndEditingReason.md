# -[UITextFieldDelegate textFieldDidEndEditing:reason:], iOS 10

Introduced in iOS 10.0: the delegate of a text field is told that editing ended with the reason: `UITextFieldDidEndEditingReasonCommitted` when the user finished, `UITextFieldDidEndEditingReasonCancelled` when the system took the
editing away. A delegate that implements it is sent it instead of `-textFieldDidEndEditing:`.

Source: the header of the SDK 16.4 and the behaviour of iOS 10 (there is no host oracle: a text field of a headless Mac Catalyst scene does not become the first responder). `device/textfieldreason.m` puts a real text field on
the screen and ends its editing: a delegate with only the reason method is sent it once, with `Committed`; a delegate with only the old method is sent that and nothing else; a field without a delegate ends editing as before.

## How the port does it

An observer of `UITextFieldTextDidEndEditingNotification` sends the reason method to a delegate that has it and lacks the old one, with `Committed`: the release cannot tell a cancelled end of editing from a committed one,
as it has no reason to cancel it. A delegate that has both is sent both, where iOS 10 sends only the reason method.

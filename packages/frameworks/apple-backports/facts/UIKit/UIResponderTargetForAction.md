# -[UIResponder targetForAction:withSender:], iOS 7

Introduced in iOS 7.0: the object in the responder chain that answers an action. The receiver if `-canPerformAction:withSender:` says yes, else the next responder's answer, nil at the end.

Source: the host's own UIKit under Mac Catalyst (`host/show/run.sh`): from a child controller the target of `showViewController:sender:` is the child itself, and the target of an action nobody has is nil. `device/show.m` repeats them on iOS 6.

## How the port does it

The recursion above, on `UIResponder`.

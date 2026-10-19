# UIKeyboardIsLocalUserInfoKey, iOS 9

From iOS 9 the keyboard notifications (`UIKeyboardWillShow`, `DidShow`, `WillHide`, `DidHide`, `WillChangeFrame`, `DidChangeFrame`)
carry `UIKeyboardIsLocalUserInfoKey`, an `NSNumber` that is YES when the keyboard is the one of this application and NO for the
keyboard of another application (split view, slide over). An application that reads the key with `boolValue` and skips the
notification when it is NO would skip every keyboard notification on iOS 6, where the release does not send the key.

The port puts YES under the key in the user info of those six notifications, in `-postNotificationName:object:userInfo:` and
`-postNotification:` of `NSNotificationCenter`, and only when the release did not already give one. iOS 6 has one keyboard and it is
always the application's own, so YES is the right answer, not a default.

Source: the shared caches of iOS 9 and 10 (the userInfo of the keyboard notifications); `tests/backports/device/keyboardlocal.m`,
which shows the real keyboard on the device and reads the key in the notifications UIKit posts.

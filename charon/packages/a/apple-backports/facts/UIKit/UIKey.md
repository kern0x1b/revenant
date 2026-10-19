# UIKey and the key input strings, iOS 13.4

Introduced in iOS 13.4: a key of a hardware keyboard with the characters it produced, its HID usage code and the modifiers held. No
event of iOS 6 carries one - a hardware keyboard reaches an application only as text - so `UIKey` is a value that nothing makes, and
`UIPress.key` has nothing to answer from (`UIPress` itself arrived in iOS 9).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointer` group): properties, equality over ten keys, hashes, copies, the archive and the 14 strings.

## As UIKit does

- `characters`, `charactersIgnoringModifiers`, `keyCode` and `modifierFlags` are what the key was made with; a key made with `-init` has nil
  strings and zeros.
- `-isEqual:` compares the key code and the modifier flags exactly, and **not** the characters; `-hash` is the key code exclusive or the flags.
- `-copy` is another equal object. The class adopts `NSCopying` and `NSCoding` and not `NSSecureCoding`; it archives four keys, `_keyCode`,
  `_modifiedInput`, `_modifierFlags` and `_unmodifiedInput`, and reads them back.
- `-description` is `<UIKey: 0x...: characters=A, unmodified=a, keyCode=4, modifierFlags=131072>`.
- `UIKeyInputHome`, `UIKeyInputEnd` and `UIKeyInputF1` to `UIKeyInputF12` are the strings of their own names.

## Where it differs

- The system's `-description` raises an exception when a string is nil (it builds a dictionary from them); the port's writes `(null)`.
- The port's `-initCharonWithCharacters:unmodified:keyCode:modifierFlags:` makes a key for the tests; the release never does.
- `UIKeyboardHIDUsage` is an enumeration and has no entry.

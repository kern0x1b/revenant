# Smart punctuation and password rules of a text input, iOS 11 and 12

iOS 11 added to `UITextInputTraits` the three kinds of smart substitution a keyboard does - `smartQuotesType`, `smartDashesType` and `smartInsertDeleteType`, each
default, no or yes - and iOS 12 added `passwordRules`, a `UITextInputPasswordRules` that shapes the password the keyboard offers. A text field, a text view and a search bar adopt
the protocol, and an application written for iOS 11 sets and reads them on all three.

Source: UIKit of the arm64 shared cache of iOS 12.0 - `-[UITextInputTraits smartQuotesType]` and the other accessors of the traits object, `-[UITextField setPasswordRules:]`, and of
`UITextInputPasswordRules` the constructor `+passwordRulesWithDescriptor:` at `0x1ad0ba9dc`, `-copyWithZone:`, `-isEqual:`, `-description` and the coding of the descriptor - and the host's UIKit under Mac Catalyst, recorded by
`tests/backports/host/traits11/run.sh` (30 records) and held to the same records on an iPad 2 on iOS 6.1.3 by `tests/backports/device/uikit12.m`, which passed all 100 of its checks there.

## What the port does

The keyboard of iOS 6 makes no smart substitution and offers no generated password, so the port keeps the values and lets typing be as it was: it is inert, and says so once in the log when
an application asks for smart quotes or gives password rules.

- `smartQuotesType`, `smartDashesType` and `smartInsertDeleteType` of a `UITextField`, a `UITextView` and a `UISearchBar` answer what was set to them, default until then, each of its own and each of its own
  object. The values of the three enumerations are those of the SDK.
- `passwordRules` answers a copy of what was set, nil until then. `UITextInputPasswordRules` is a class of its own here: `+passwordRulesWithDescriptor:` keeps a copy of the descriptor,
  `-passwordRulesDescriptor` answers it, a copy is another object that is equal to the first, `-isEqual:` compares the descriptor of an object of the class, `-description` reads
  `<UITextInputPasswordRules: 0x...; passwordRulesDescriptor = ...>`, it is `NSSecureCoding` with the descriptor under the key `passwordRulesDescriptor`, and, as in iOS 12, it defines no `-hash` of its own.
- The descriptor is not parsed: iOS 12 hands it to the keyboard, which is not here.

## Not carried

That the substitution happens: a text typed with smart quotes on keeps its straight quotes.

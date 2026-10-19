# What the keyboard is told about a text field, iOS 10

Introduced in iOS 10.0: the 23 constants `UITextContentTypeName` to `UITextContentTypeCreditCardNumber` and the
`textContentType` property of the classes that adopt `UITextInputTraits`.

Source: UIKit of the armv7s cache of iOS 10.3.4, the strings read from the constants, and the host's UIKit through
Mac Catalyst (`host/textcontent`); the device test `textcontent.m` holds iOS 6 to the same answers.

## The constants

Each is an `NSString` whose value is a token of the HTML autocomplete vocabulary, and the release's own strings are
written here as they are, the two misspellings included: `honorifix-prefix` and `honorifix-suffix` for the name prefix
and suffix, and `address-level1+2` for the city and state together. The rest are `name`, `given-name`,
`additional-name`, `family-name`, `nickname`, `organization-title`, `organization`, `location`, `street-address`,
`address-line1`, `address-line2`, `address-level2` (city), `address-level1` (state), `address-level3` (sublocality),
`country-name`, `postal-code`, `tel`, `email`, `url` and `cc-number`. The host's UIKit answers the same 23 strings.

iOS 11 added `UITextContentTypeUsername` (`username`) and `UITextContentTypePassword` (`password`), and iOS 12
`UITextContentTypeNewPassword` (`new-password`) and `UITextContentTypeOneTimeCode` (`one-time-code`); their strings are
those of UIKitCore in the arm64 cache of iOS 12.0, and the host's UIKit answers the same. They are carried in objects of
their own, one for each release, and the ones of iOS 15 are not here. The corpus of nine applications names `Username` and
`Password` as hard imports in two.

## The property

`textContentType` is declared by `UITextInputTraits`, whose users in UIKit are `UITextField`, `UITextView` and
`UISearchBar`; the release keeps the value in the traits object the view forwards to. It is `copy`, and nil by default.
The port keeps a copy of the string on the view, answers it, and gives the property to those three classes, and to what
inherits from them. A view of a program's own that adopts `UITextInputTraits` keeps its own value, as it always did.

Setting a value the first time says once in the log that it is kept and not used.

It is **inert**: the type is a hint to the keyboard, which offers autofill of contacts and cards from iOS 10, and iOS 6 has
none, so nothing reads the value. Against the host's own views the default, a known type, an unknown string, the empty
string, nil, a mutable string changed after it was set, and a second view left alone all answer the same.

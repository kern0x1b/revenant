# The speech attributes of iOS 7

Source: the UIKit of the host's Mac Catalyst, asked for the value of each key, and the armv7 cache of
iOS 6.0, asked whether it exports them.

`UIAccessibilitySpeechAttributePunctuation`, `UIAccessibilitySpeechAttributeLanguage` and
`UIAccessibilitySpeechAttributePitch` each carry their own name as their value. iOS 6.0 exports none of
the three - of that family its UIKit has only the older `UITextAttribute…` - and that is the whole reason
they are here. An application built against a modern SDK writes the key straight into a dictionary,
`@{UIAccessibilitySpeechAttributeLanguage: @"pl-PL"}`, and a weak import that resolves to nil is a nil
key, which is an `NSInvalidArgumentException` before accessibility is reached at all. With the constants
the string is built and spoken; what is lost is only the attribute, since the release's VoiceOver reads
neither pronunciation nor language nor pitch from an attributed string.

The four keys of iOS 11 in the same family are carried beside them in
`UIKit/NSObject+AccessibilityAttributedStrings.m`, on the same reading.

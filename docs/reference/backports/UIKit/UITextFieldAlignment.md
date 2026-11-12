# The vertical alignment of a `UITextField` on iOS 6

A `UITextField` made in code starts with `contentVerticalAlignment` top on iOS 6 and centered on iOS 7 and later. In a field taller
than its text the text rides at the top. The backports give the field the later start.

## What was seen

Telegram 13.0.0 on an iPhone 4S, iOS 6.1.3. The search pill of the country sheet holds a `UITextField` 48 points high with a 17-point font and
no border. Its `contentVerticalAlignment` answers 1 (top); the text typed into it sits above the baseline of the placeholder and of
the search icon beside it. With the alignment set to 0 on the live field, the text sits on that baseline (two screenshots of the same field
with the same text, taken before and after). The phone-number fields of the entry screen are 57 points high and answer 1 as well.

## What the backports do

`UITextField+VerticalAlignment7.m` replaces `-[UITextField initWithFrame:]` on a system older than iOS 7. After the original initialiser, a
top alignment becomes center (`RevenantTextFieldAlignment.m`); any other value stays. A field loaded from a nib keeps what the nib says
(`initWithCoder:` is not touched), and an alignment an application sets after the initialiser is its own.

An application written for iOS 6 that relied on the top start in a field taller than its text sees the text centered; the backports exist for
applications built for the later behaviour. A field of the standard height shows no difference.

## Tests

`frameworks/Backports/tests/UIKit/text_field_alignment_test.m` (host, target `UIKitBackports_text_field_alignment_test`): top becomes center, center,
bottom and fill stay. 4 checks, and the negative run fails. The initialiser swap ran on the phone (Telegram's country sheet after the deb of this change).

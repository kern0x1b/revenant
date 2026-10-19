# NSTextAlignmentNatural on UILabel, UITextField and UITextView

`NSTextAlignmentNatural` (4) aligns text to the start of its writing direction. The release's attributed strings accept it, but its controls raise an
exception when `textAlignment` is set to it ("textAlignment does not accept NSTextAlignmentNatural"), and applications written for iOS 6 and later set it as a matter of course.

Source: the host's own UIKit under Mac Catalyst, recorded by `tests/backports/host/textalign/run.sh` (22 records: each control with a Latin and with
a Hebrew text, for left, centre, right and natural, the alignment read back and which side the ink of the rendered control is on, a text
changed under a natural label, and a text view's getter), held against the port on the iPad 2 and the iPhone 4S by `tests/backports/device/textalign.m`.

## What the port does

`-setTextAlignment:` of the three classes takes 4: the control keeps that it was asked for natural, sets the alignment it resolves to on the
release's own setter, and `-textAlignment` answers 4 until another value is set. The alignment resolved is what the host resolves:

- `UILabel` follows the direction of the interface (`userInterfaceLayoutDirection` of the application), not that of its text: a Hebrew text in a
  left-to-right application is left-aligned, as on the host (record `label.hebrew.4`).
- `UITextField` and `UITextView` follow the text: the language of the text (`CFStringTokenizerCopyBestStringLanguage`, then
  `+[NSLocale characterDirectionForLanguage:]`) decides, and an empty text or one without a language is resolved by the interface's direction. It is resolved again when
  `-setText:` is sent and when the text changes by editing (`UITextFieldTextDidChangeNotification` and
  `UITextViewTextDidChangeNotification`).

Every other value goes to the release's setter as it was. A label whose text is changed after natural was set keeps the alignment it resolved
(record `label.textChange`), as the host's does.

Not carried: a natural alignment set through an attributed string's paragraph style, which the release handles itself, and the
resolution by the direction of a language in a text longer than 256 characters (the first 256 decide).

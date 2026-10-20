# UIFontPickerViewController, the monospaced system font and the system designs, iOS 13

Introduced in iOS 13: a view controller that lets a person choose a font family or face, and the fonts and font descriptor designs of
the system's own kinds.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by the `fontpicker` group of
`tests/backports/host/uikit2` and, for the font and the constants, by the `views13` group.

## The configuration

A configuration starts with `includeFaces` NO, `displayUsingSystemFont` NO, `filteredTraits` 0 and no languages predicate, and
prints as `<UIFontPickerViewControllerConfiguration: 0x...; includeFaces: NO; displayUsingSystemFont: NO>`. It is copied field by
field and a copy is not equal to it. `+filterPredicateForFilteredLanguages:` is the predicate `ANY {"en", "fr"} IN SELF` of a
comparison predicate, and nil for no languages.

## The picker

A picker keeps a copy of the configuration it is made with, the same object each time it is asked, so that changing the original
afterwards changes nothing; `-init` makes one with an empty configuration and `initWithConfiguration:nil` one with none. The delegate
is weak, `selectedFontDescriptor` is nil until set, and the description is `<UIFontPickerViewController: 0x...; configuration:
"...">`.

## What it cannot do

`UIFontDescriptor` is not on iOS 6 (`UIFontDescriptor.md`), so the picker has no descriptor to give the delegate as the chosen font
and lists no font at all. Its view is a message and a Cancel button, and Cancel sends `fontPickerViewControllerDidCancel:` and nothing
else; `fontPickerViewControllerDidPickFont:` is never sent. The first time the picker appears it says so once in the log. An
application that carries on with a cancelled picker carries on, and one that needs a font has to offer its own list.

## The monospaced system font

`+monospacedSystemFontOfSize:weight:` answers Menlo, bold for a weight above medium and regular otherwise, or Courier when the
release has no Menlo. The system's is SF Mono, which iOS 6 does not have, so the letters are not the same shapes; they are of one
width, as the host's are (the `views13` group compares the widths of four letters).

## The system designs

`UIFontDescriptorSystemDesignDefault`, `...Rounded`, `...Serif` and `...Monospaced` are the strings `NSCTFontUIFontDesignDefault` and
so on, as the host has them. `-[UIFontDescriptor fontDescriptorWithDesign:]` is absent with the class it belongs to.

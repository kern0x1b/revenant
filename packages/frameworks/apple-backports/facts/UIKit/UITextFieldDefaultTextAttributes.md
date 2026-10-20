# UITextField defaultTextAttributes, iOS 7

Source: the host's own UIKit, under Mac Catalyst, asked a field through six settings in turn and held against the
backport by the `misc` group of `tests/backports/host/uikit2/run.sh`, which puts the two side by side and compares
the answers after each; and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through
`tests/backports/device/uikit2.m`.

## What the dictionary holds

`defaultTextAttributes` of a new field holds three attributes and no more: `NSFontAttributeName`, the font of the
field; `NSForegroundColorAttributeName`, its text colour; and `NSParagraphStyleAttributeName`, a paragraph style
whose alignment is the field's `textAlignment` and whose line break mode truncates the tail. The three are the field's
live settings: changing `font`, `textColor` or `textAlignment` changes what the dictionary answers, and an attribute
of another kind that was set stays in the dictionary beside them.

## What setting it does

The dictionary given replaces the whole of the field's default attributes:

- the font, the colour and the alignment of the paragraph style, when they are there, become the field's `font`,
  `textColor` and `textAlignment`;
- one that is left out is not left as it was but goes back to what a new field has - a dictionary with a colour
  only puts the font back to the default font, and an empty dictionary or nil puts all three back;
- the attributes of any other kind are kept as they were given, and a paragraph style is kept as given, with the line
  break mode it carries, so `NSLineBreakByTruncatingHead` is answered back as it was set;
- what was set before and is not in the new dictionary is gone.

## What iOS 6 does differently

A new field of the release has its own font, colour and alignment, and the port reads them off a field of its own
rather than naming them: the answers of a new field are the ones a left-aligned iOS 6 field has, where the newest
release's are natural-aligned ones.

When the field has text, the port gives it back as attributed text in every attribute of the dictionary, so a kerning
or an underline set there shows. The newest release's `attributedText` holds the font and the colour only in the same
case; what the release draws for the other attributes was not read.

# The text attributes, the document types and the tab stops of iOS 7

Up to iOS 6 the text system of UIKit was already the one Mac OS X has, kept in UIFoundation: `NSParagraphStyle` with its tab stops
and lists, `NSTextAttachment`, `NSLayoutManager`, `NSTextStorage`, `NSTextContainer`, and an `NSAttributedString` that reads and
writes RTF and reads HTML through the web engine, all of them there at runtime on iOS 6.1.3. What iOS 7 added, and what an
application built for it names, is smaller than TextKit's size suggests, and this batch carries the part that keeps an
application from starting: the names.

Source: the host's own UIKit for every value and every answer below, and the iPad 2 for what its UIFoundation does with them.
`host/textkit7` records the host's answers for the cases of `device/textkit7-cases.m` and `device/textkit7.m` shows them again, in an
application, on iOS 6: 71 records, 59 equal, 11 tolerated for the differences below and 1 for the quirk of the release, none differing
unexplained.

## The constants

The attribute names `NSTextEffectAttributeName`, `NSUnderlineColorAttributeName`, `NSStrikethroughColorAttributeName`,
`NSObliquenessAttributeName`, `NSExpansionAttributeName` and `NSWritingDirectionAttributeName`, the letterpress style, the tab column
terminators key, the four document types (plain text, RTF, RTFD, HTML), the document attributes (type, default attributes, paper size
and margin, view size, zoom and mode, read only, hyphenation, default tab interval, layout sections) and the reading options (type,
default attributes, character encoding) are defined as the strings the host has. The release reads a document type and an encoding by
those strings already, so `initWithData:options:documentAttributes:error:` with `NSHTMLTextDocumentType` does what it does on iOS 7:
inside an application it reads HTML into runs with fonts, colours, links, underline, strikethrough, lists, headings and sub- and
superscripts, and RTF and plain text as well. What the release draws of the six attributes is in `TextAttributes7.md`: five are drawn, and one - the letterpress effect - is not.

## NSTextTab

The release has an `NSTextTab` with `initWithTextAlignment:location:options:`, the alignment, the location and the options - and does
not export it, so an application that names the class does not start. The library exports the release's name as an alias, a
subclass of the release's class that answers as it (`facts/UIKit/NSTextMembers13.md`, the aliases), so the tabs that are made, the
tabs a paragraph style holds and `[NSTextTab class]` are one class, `isKindOfClass:` holds, and a subclass inherits the release's tab.
`+columnTerminatorsForLocale:` is added to that class: the decimal separator of the locale, or a full stop for none.

## What differs

The import gives the text an explicit black foreground colour where the host gives none, names its fonts as its own
(`TimesNewRomanPSMT` where the host has `Times-Roman`; the sizes, weights and slants agree), and lays a list out natural where
the host lays it out left. A tab made with no options and a tab made with an empty dictionary are not equal on this release.
HTML is read through the web engine, which needs an application to run in: outside one the release fails.

## What it does not carry

The rest of what iOS 7 added to the text system - `NSTextContainer`'s size, exclusion paths and tracking of a text view,
`UITextView`'s `textContainer`, `layoutManager` and `textStorage`, the attachment's bounds, the ninth release's paragraph properties
and the string drawing methods - is not in this batch, and the registry says so where an entry exists.

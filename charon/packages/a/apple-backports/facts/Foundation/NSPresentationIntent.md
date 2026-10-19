# NSPresentationIntent, iOS 15.0

The value a Markdown document's blocks carry: what kind of block a run of text is, the identity the
document gave it, and where in the tree of blocks it sits. An application that lays an attributed
string out by hand reads these instead of parsing the Markdown itself.

Source: the SDK 26.2 headers, and the host's own `NSPresentationIntent` measured through
`tests/backports/host/presentationintent` — 643 checks, the port's class and the system's in one
process, the port's compiled under a name of its own. The device check is
`tests/backports/device/foundation15.m`.

## What it is

A class the release has no use for, so the port implements it whole: the twelve factories, the
eleven properties, `-isEquivalentToPresentationIntent:` and the two coding methods, 24 members and
the class itself. There is no wall anywhere in it — an intent is a value, and the port's own
document parser (or the application's) is what hands these out.

The state is one object kept beside the instance through `objc_setAssociatedObject`: the SDK's
declaration carries no ivar block and the armv7 ABI has nowhere to add one. The object is immutable
once a factory has built it, so a copy shares it.

`-init` and `+new` are `NS_UNAVAILABLE` in the SDK's own header and are **not** carried: the
compiler refuses the call, which is the truth. Inside the port a factory allocates the instance and
runs the superclass's `-init` through `objc_msgSendSuper`, which is what `-init` would have run.

## The indentation, measured

`indentationLevel` is the one member whose rule is not in the header. Measured over every chain of
one, two and three kinds and over runs up to six spans, on the host:

| the intent | the level |
| --- | --- |
| no parent | 0 |
| anything under a paragraph, a header, a list, a code block or a table | 0, except a list item and a block quote, which are 1 |
| a paragraph or a thematic break, whatever holds it | 0 |
| a header, an ordered or unordered list or a code block under a list item or a block quote | the level of the one above it |
| a list item or a block quote | the level of the one above it, plus one |

So the level is a step per span (a list item, a block quote) from the root down, and a paragraph or
a thematic break resets it: the text of a list item is not indented inside it, while a header in the
same place is. A run of spans is all the way to the root, so the document itself is never counted
and the first span answers 1 under a paragraph, 0 at the top.

## What the table factory refuses

`+tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:` raises
`NSInvalidArgumentException` with the reason

    *** +[NSPresentationIntent tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:]: column count does not match count of alignments

unless the number of alignments is the column count — measured for a count too small, too large,
zero against one alignment, and `nil` against two. The alignment *values* are not checked: 9 is kept
as it is, which the port keeps too. Nothing else is validated: a row under a paragraph, a cell under
a table, a negative row and a column past the last one all answer, and the port answers with them.

## Equality

`-isEqual:` is the same as equality with the identity left out, plus the identity itself, and the
parent is compared the same way all the way up the tree. Measured: two headers under two *equal*
paragraphs are equal whatever their identities, two under a paragraph and a block quote are neither
equal nor equivalent, and an intent is never equal to nil.

`-hash` is the one place the port answers a different number, and it is written down here rather
than faked: the host's `-hash` is a private mixing of its own fields (`3` for a paragraph with
identity 3, `1070` for a code block with the hint `c`), and no API fixes the value. What `-hash`
owes is one thing, and the port keeps it: two equal intents hash equal, which is what a set or a
dictionary of intents needs. The differential checks that on both sides and prints the two numbers
rather than holding them equal.

`-description` is the port's own one line, where the host's is a private format of its own fields
(`<NSPresentationIntent 0x…>: Paragraph (id 10)`); no API fixes the text of a description, and a
program that parses it is parsing something private on either release.

## The archive

The keys are the SDK's own, read out of a keyed archive the host wrote:

    NS.intentKind  NS.identity  NS.ordinal  NS.columnCount  NS.columnAlignments
    NS.headerLevel  NS.languageHint  NS.row  NS.column  NS.indentationLevel  NS.parentIntent

`NS.indentationLevel` is written as a value of its own, beside the chain it was computed from, and
the port writes and reads it the same way. A round trip through the port's own coder reads back an
intent that answers for every property as the one that went in.

# The model of TextKit 2

`NSTextContentManager`, `NSTextContentStorage`, `NSTextListElement`, the four
protocols between them — `NSTextElementProvider`, `NSTextStorageObserving`,
`NSTextContentManagerDelegate`, `NSTextContentStorageDelegate` — and `CharonTextLocation`,
the port's own `NSTextLocation`. Whole, from the headers of SDK 26.2:
`NSTextContentManager.h`, `NSTextListElement.h`, `NSTextStorage.h`.

Measured against **UIKitCore 26.2 arm64e under Mac Catalyst**, the host's own UIKit, in
the probe beside this file and held by `tests/backports/host/uikit2/content15_test.m`
(`checks=36 failures=0`).

## What could not be measured, and why

**The host's content storage cannot be made on the measured build.**
`-[NSTextContentManager initWithTextStorage:]` is not there — `instancesRespondToSelector:`
answers NO, and `-init` is the only initializer it has (M1). So the host's own document
cannot be constructed, and every answer about one — its document range, its locations, its
elements, its two conversions — is nil in every state reachable from a process on this build.
That is the single largest limitation of this delivery, and it is a property of the host
build rather than of the port.

So the answers below come from two places, and each is marked which:

- **measured** — the host answered, and the number is in `probe-content.out`;
- **from the header** — the host could not be asked, and the answer is what
  `NSTextContentManager.h` says, written out in full so that it is checkable against the
  header rather than taken on trust.

Every answer the port gives about a document is the second kind. The port's content
storage is constructible where the host's is not, which is a real difference and a useful
one: on a release that has no content storage at all, the port's is the only one there is.

## NSTextContentManager — the base class

**Measured.** A bare manager answers (M2):

| | |
| --- | --- |
| `textLayoutManagers` | empty |
| `hasEditingTransaction` | NO |
| `automaticallySynchronizesTextLayoutManagers` | **YES** |
| `automaticallySynchronizesToBackingStore` | **NO** |
| `delegate` | nil |
| `primaryTextLayoutManager` set to a manager that is not in the list | **nil** |
| `textElementsForRange:nil` | no elements |
| `-description` | `<NSTextContentManager: 0x...>` — the class and the address and nothing else |

The two flags' defaults are the header's own words, and the primary's reset to nil is the
header's rule for setting a manager that is not in the list, which the host confirms.

**From the header.** The list and its two mutators; the transaction, which nests, whose
outermost frame is what `-hasEditingTransaction` reports, and on leaving which the two
synchronisations are sent in the header's order — the layout managers first, then the
backing store. The record of what each edit did, kept while the transaction is open and
cleared with it.

**A transaction that raises still leaves** (`@try`/`@finally` around the block). The header
does not say, and a transaction entered and left by an exception is a transaction that was
entered: leaving `-hasEditingTransaction` YES for ever because a caller's block raised would
block every synchronisation from then on, which is a worse state than the one the raise left.

**D1 — a synchronisation inside a transaction raises nothing (M3).** The header says it
"should block (or fail if synchronous)" while `-hasEditingTransaction` is YES. Measured: the
host asks nothing of the caller and raises nothing, and returns the transaction's own state.
The port does the same. This is a divergence from the header, taken from the system, and it is
recorded rather than corrected — a port that raised here would break a caller the host does not.

**D2 — the abstract manager's own three.** `documentRange` is **nil** on the port, where
`NSTextElementProvider` types it nonnull; `enumerateTextElementsFromLocation:options:usingBlock:`
returns **nil** and never calls the block; `replaceContentsInRange:withTextElements:` does
nothing. The header calls `NSTextContentManager` abstract and says a concrete subclass
overrides the element provider, so the base has no document, and a range over a location of no
document would be a range that pretends to be in one. The nonnull annotation is a statement
about a concrete manager. The host could not be asked: it cannot be made into a concrete
manager here.

## NSTextContentStorage — the document

**From the header**, and this is the part TextKit 2 stands on.

**The document is the backing store's string.** A storage of its own wins over
`-attributedString`, which the header says outright, so setting the string while there is
a storage leaves the document where it is. The port's `-attributedString` answers a copy,
because a document that hands out its own mutable string is a document an application edits
behind the manager's back.

**The locations are the port's own**, `CharonTextLocation`: an offset and the document it is
in. Both are needed, because an offset is only an offset in one document, and
`-offsetFromLocation:toLocation:` is what answers `NSNotFound` for two locations of two
documents — the header's own words for that case. `NSTextLocation` is a protocol with one
method, a comparison, so a location needs nothing else: `-compare:` is the ordering of the two
offsets, and the host's location type is private, which is why the port has one of its own.

**`locationFromLocation:withOffset:`** is nil for a location that is not the storage's own and
for one that would fall outside the document — the header's "could return nil when the inputs
don't produce any legal location". **`offsetFromLocation:toLocation:`** is `NSNotFound` for a
pair that is not one document's, the header's "when locations are not in the same document".

**The elements are the document's paragraphs.** One `NSTextParagraph` per paragraph, cut at
the paragraph endings, and a CR LF pair is one ending of two characters. The header names no
other paragraph separator, so the Unicode line and paragraph separators are ordinary
characters here; that is the port's reading and it is pinned by a case, because nothing
above it would notice a change. The delegate's
`-textContentStorage:textParagraphWithRange:` is asked first and its paragraph used when it
gives one, which is the header's own "custom text paragraph" hook; otherwise the range's
attributes are the paragraph's contents, which is the header's standard mapping.
`-textContentManager:shouldEnumerateTextElement:options:` is asked before each element reaches
the block, and a NO skips it — the header's own rule for a provider that hides elements from
the layout.

**Forward enumeration** starts at the range's start, or at the document's start when the
location is nil, and returns the edge it reached. **Backward enumeration** starts at the
*end* of the document when the location is nil, and at the element *preceding* the one
containing a given location when it is not — the header's own rule, twice, and the two are
different, which is why the port implements them as two directions rather than one with a sign.

**The storage is observed.** `NSTextStorage` asks its observer to process an edit when one is
finished, and the port's content storage is that observer: it rebuilds the document range and
records the edit, which is how a range stays true while the text under it is edited. The
storage's observer is weak, so the storage is held by the content storage and the observer is
moved when it changes. The differential holds the two answers that depend on it: an edit to
the document lengthens the document range, and a paragraph in the port's document derives the
content and separator ranges the range layer was waiting for — four characters without the
newline, and the one newline.

**`-adjustedRangeFromRange:forEditingTextSelection:`** is nil until something has been
edited, and after an edit it is the range the header describes: a range that ends before the
edit began is unchanged, one that begins after it is moved by what the edit did to the
length, and one that meets it is cut at the edit's end. The header says the concrete subclass
should implement it "if the location backing store requires manual adjustment after editing",
and an offset-based one does, so it is implemented rather than left nil.

## NSTextListElement — the one element type that is not a paragraph

Its own file: it arrived in iOS 16 and a file carries the API of one release.

**Measured** (M4). `+textListElementWithChildElements:textList:nestingLevel:` answers **nil**
for no children, which is the header's own "returns nil if childElements.count == 0", and
**raises `NSInvalidArgumentException`** for a negative nesting level, which is the header's
"raises an exception when nestingLevel < 0". Both are held.

**D3 — `-initWithAttributedString:` does not refuse (M5).** The header marks it
`NS_UNAVAILABLE`, and the port's first version raised. The host does not: measured, it makes
an element with the string as *what it displays*, and no list, no contents and no marker of
its own. So the port does the same, and the fact that an application cannot compile the call
is the header's business, not the port's.

**D4 — the item marker is the element's own, not the list's (M6).** The host's displayed
string for the first item of a list whose own `-markerForItemNumber:1` answers `"1"` is
`"\t0\tone"`: tab, zero-based item number, tab, then the contents. So the host's element
numbers its items from zero — which the port's does too — and **delimits the marker with tabs
itself**, rather than asking the list. The port's marker is the list's answer for the item
number, so the two differ in the tabs. The port follows the header here ("derived from
contents/textList configured with the text list element's position inside the tree") and
records the difference. The differential holds both sides' own shape, so a host that starts
agreeing with the port is noticed.

## CharonTextLocation

The port's own `NSTextLocation`, which the range layer's group had carried and then removed as
unused, and this group needs again: a document's locations are the content storage's, and
without a concrete location there is nothing to make a range of.

**It takes no registry entry, and the reason is measured.** `nm -m` of the 6.1.3 gate's
`libUIKitBackports.dylib` shows `_OBJC_CLASS_$_CharonTextLocation` as
`non-external (was a private external)`: the class is in the library and the linker made it
hidden, and the gate's `found.classes` sees exported classes only, so an entry claiming it is
implemented cannot be satisfied — which is what the gate said, by name. The two precedents in
this tree agree: `__NSConcreteUUID` **has** an entry, because `+[NSUUID alloc]` hands that class
out and the system names it; the port's own `CharonListMenuDelegate` and `CharonListMenuHooks` are
hidden in the same library and have **no** entry, because nothing hands them out. Rule R4 is
satisfied by the SDK row that does exist and that the range layer's group already carries:
`NSTextLocation`, the protocol, in `ios15textrange.json`. It holds the document and the
offset, and that is all: `NSTextLocation` asks for a comparison, `-compare:` is the ordering of
the two offsets, and `-isEqual:`/`-hash` follow it so a location can go into a set — which the
header's `NSNotFound` case needs, since that answer is about two locations that are not each
other.

## The protocols

`NSTextElementProvider` is what the range layer's group left to this one: its seven members are
sent from here, by the content storage, and it is `implemented` for that reason. It is also the
one of the four whose protocol object `NSTextContentStorage`'s objects define — measured as the
`__OBJC_PROTOCOL_$_NSTextElementProvider` symbol among the fifteen the objects of this series
define. A lookup by name would not have measured that: the SDK `content15_test.m` compiles
against carries the protocol object itself, and `NSProtocolFromString("NSTextElementProvider")`
answers non-nil in a process with none of this library in it.

The case in `content15_test.m` therefore reads the protocol list off `CharonTextLocation`, which
is the one of the four this package puts on a class of its own: no SDK header declares the name
`CharonTextLocation`, so its declaration in `CharonTextLocation.h` is the only one, and the
protocol on it is this library's. `NSTextElementProvider` has no such class here — the port's
`NSTextElement` adopts nothing in its own source, and the SDK's declaration of that class is what
a runtime would read — so for that one the nm table above is the evidence and no case claims
more.

The other three — the manager's delegate, the storage's, and the selection data source the range
layer is written against — are declared by the build SDK, so a `@protocol` of the same name here
would be a duplicate and the package declares none of them. An application that adopts one
compiles against the SDK's own declaration of it, and on a release that carries no such protocol
object `NSProtocolFromString` answers nil. Their rows say so, and the selectors of the two delegate
protocols the port sends are `implemented` because the port does send them; the nine selectors of
the selection data source that the port never sends are `absent`, each naming the selector the port
asks instead.

## Not measured

- **Every answer about a document on the host**, for the reason at the top.
- **`-includesTextListMarkers`**, a 26.0 member the build SDK does not declare, so the port
  carries no property for it here; its entry says where the port answers it.
- **What the host's element enumeration does**, and therefore whether the paragraph cut, the
  delegate hook and the two directions are right. They are written from the header and are the
  part of this delivery most worth a re-measurement on a build where a content manager can be
  made. What the header does settle is held by fourteen cases in
  `tests/backports/host/uikit2/content15_test.m`: the forward cut for a line feed, a
  carriage-return-and-line-feed pair, a lone carriage return, two endings in a row, a document
  with no ending and a document with none of the separators the header names; the backward walk
  from the end of the document, from a location and from a location at a paragraph's start; the
  same walk over a CR LF document; and a range's own end deciding where the array stops.

## The probe

`probe-content.m` and `probe-content.out`, in `.agent-work/runs/textkit2/`. A separate process
with none of the port's code in it, one case per invocation where a case can fault, built for
Mac Catalyst. What it printed is what the facts above mean by "measured"; each claim carries
its case number.

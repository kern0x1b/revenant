# The range layer of TextKit 2

`NSTextRange`, `NSTextSelection`, `NSTextElement`, `NSTextParagraph`,
`NSTextSelectionNavigation`, and the two protocols the range layer is written
against, `NSTextLocation` and `NSTextSelectionDataSource`. This package declares the protocol on
its own concrete location type: `CharonTextLocation.h` has `CharonTextLocation : NSObject
<NSTextLocation>`, the class is a name no SDK header uses, and the objects define
`__OBJC_PROTOCOL_$_NSTextLocation`. The SDK this library is compiled against declares the protocol
by name, so the name alone proves nothing; the class and the class name are what make the
declaration the port's. `NSTextSelectionDataSource` is declared by the build SDK, so the package
declares no protocol of that name and its row is `absent`: it is a type the sources are written
against, and on a release with no such protocol object `NSProtocolFromString` answers nil. Whole, from the headers
of SDK 26.2: `NSTextRange.h`, `NSTextSelection.h`, `NSTextElement.h`,
`NSTextSelectionNavigation.h`.

Measured against **UIKitCore 26.2 arm64e under Mac Catalyst**, the host's own UIKit,
in the probes named at the end of this file and held by
`tests/backports/host/uikit2/textkit2_test.m` (`checks=2011 failures=0`).

Where the header and the running system disagree, the system decides, and the
divergence is written down here. There are five:

| # | The header says | The system answers |
| --- | --- | --- |
| D1 | a range holds a location when `(location <= l) && (l < endLocation)`, and says nothing about holding a *range* | the end is closed for a range with contents, and open for an empty one |
| D2 | ranges handed to a selection "are reordered and merged" | they are kept as they are given, in the order they are given |
| D3 | nothing: `NSTextSelection.typingAttributes` is `nonnull` | `nil` for a selection that was never given any |
| D4 | a movement that produces no logically valid result answers `nil` | the selection it was handed comes back |
| D5 | nothing: the resolved insertion location needs a selection that is not logical and has a secondary location | the selection's own location, for one of the two writing directions |

D1 is the one that decides the most code. The header's rule is the rule for a
*location*, and `-containsLocation:` follows it with the end exclusive. For a whole
*range* the system closes the end, so a range holds itself. D2 and D3 are
straightforward. D4 and D5 are states the host's own navigation object is never in
- it is always made with a data source - so they are not answers about a movement,
and they are recorded rather than copied; what the port answers instead is said
below.

## NSTextRange

A range is two locations and nothing else, so every question about one is a
comparison of the two. `NSTextLocation` is a protocol with one method, and it is
all the range layer needs to know about a location - which is why a range works over
any document type at all.

**A range with no end is empty at its start.** `-initWithLocation:` with no end
answers its start as its end, which is what the header's comment on the two-argument
initialiser says and what makes the end of a range exclusive in the only way that
works.

**`-isEmpty` is by value.** A range is empty when its two locations are the same
*place*, and two location objects that stand for the same place are one place. This
is the port's first correction: it compared the two locations by identity, so a
range built from two equal locations said it was not empty.

**`-containsLocation:`** is the header's rule, `(location <= l) && (l < endLocation)`,
so the end is exclusive and an empty range contains nothing, itself included. The
host's answers at 0, 5, 10, 11 against `0...10` are 1, 1, 0, 0.

**`-containsRange:`** is not two `-containsLocation:` calls. Measured over a grid of
forty-nine pairs, and printed in full by `probe-range-grid.m`:

- a range with contents is held whole, **closed at both ends**: `0...10` holds `0...10`
  and `0...5`, `0...15` holds `0...10`, `0...5` does not hold `0...10`;
- an **empty** range is held exactly when its one location is, so `0...10` holds
  `3...3` and `0...0` and does **not** hold `10...10`, whose location is at its end;
- an **empty** range holds nothing at all, not even itself: `3...3` holds nothing and
  `0...0` holds nothing.

**`-intersectsWithTextRange:`** is strict overlap between two non-empty ranges: each
one starts before the other one ends. `0...5` and `5...15` share nothing, and an
empty range is in no range, so it shares nothing with any.

**`-textRangeByIntersectingWithTextRange:`** is the later of the two starts and the
earlier of the two ends, and there is one whenever the ranges share contents **or one
of them is inside the other**. So `0...10` with `0...15` is `0...10` and `0...10`
with `5...5` is `5...5`, while `0...5` with `5...10` has none: they only touch,
neither is inside the other, and the header's "returns nil when not intersecting" is
what happens. `0...10` with `20...25` is nil.

**`-textRangeByFormingUnionWithTextRange:`** is not the envelope whenever one of the
two ranges is empty:

- self empty: the answer is the range handed in (`0...0` with `5...10` is `5...10`);
- the other empty: the answer is self (`0...10` with `3...3` is `0...10`);
- both empty: the answer is the range handed in (`0...0` with `3...3` is `3...3`, and
  in the other order it is `0...0`) - the space between them is in neither;
- neither empty: the envelope, the earlier start and the later end (`0...10` with
  `5...15` is `0...15`, `0...10` with `10...20` is `0...20`).

**`-description`** is the two locations and nothing else: `0...10`, and `3...3` for a
range that is empty at 3. No class, no address, so a range printed in a log names the
part of the document it is in and nothing else.

**`-hash` is not a function of the value on the host.** Two equal ranges measured
with different hashes. A hash that disagrees with equality breaks every dictionary
and set a range goes into, so the port's is by value and the divergence is recorded
rather than copied. The differential fails if the host ever starts making it
consistent, so the change would be noticed.

**`-isEqualToTextRange:`** compares the two pairs of locations by value and answers
NO for nil. **`-isEqual:`** is that, and a range is a subclass of nothing but
NSObject. **`+supportsSecureCoding` does not exist** on the host's range class and a
range has no `-initWithCoder:`; the host raises when a selection holding ranges is
archived, and traps on `-[NSKeyedArchiver archivedDataWithRootObject:]`.

**The unavailable initialisers.** `-[NSTextRange init]` and `+[NSTextRange new]`,
`-[NSTextSelection init]`, `-[NSTextSelectionNavigation init]` and
`+[NSTextSelectionNavigation new]` are all `NS_UNAVAILABLE` in the header, and the
host **faults** on every one of them, and on `+[NSTextElement new]` and
`-[NSTextElement init]` as well - measured one call per process in
`probe-initializers-out-of-process.m`, each of which exits 139. A fault is not an
answer a caller can read or survive, so the port raises
`NSInternalInconsistencyException` naming the initialiser to use instead, which is
catchable and never leaves a range with no locations in it. `-[NSTextElement init]`
is the exception: the header does *not* mark it unavailable and an element with no
content manager is a state every answer of that class already has an answer for, so it
gives one.

## NSTextSelection

**A selection is a value.** The host answers `-isEqual:` YES for two separately made
selections that agree on their ranges (in order), affinity, granularity, anchor
offset, typing attributes and logical flag, and NO for two that differ in any one of
them; and its `-hash` *is* a function of the value, unlike a range's - a set holding
two equal selections holds one. All six keys are written out in the port. The
seventh, `-transient`, is left out: the header declares it readonly and nothing sets
it, so two selections on the port cannot differ in it and the host was never asked.

**`-typingAttributes` is `nil` until the setter has been called at all** and a
dictionary from then on (D3). A selection made with an initialiser answers nil; a
selection whose setter was handed nil answers an empty dictionary; the setter copies,
so emptying the caller's dictionary afterwards leaves the selection's alone. The
substitution is in the setter, not the getter.

**`-textSelectionWithTextRanges:`** carries the affinity, the granularity, the
transient flag, the anchor offset, the logical flag, the secondary location and the
typing attributes, and gives an **empty dictionary** where the selection it was made
from had nil. It does *not* put the secondary location through the setter, so a copy
of a selection that is logical and has a secondary location is **still logical** -
where the setter's own side effect would have made it not.

**A selection keeps the ranges it is given** (D2), in the order it is given them,
overlapping and out of order included: three ranges in, three ranges out, and the
order they came out in is the order they went in.

**`-setSecondarySelectionLocation:`** makes the selection not logical, which is the
header's own side effect and the host's answer.

**`-description`** names the two enumerations by their case names and then the ranges
one to a line, with a comma between them and none after the last:
`NSTextSelection:<0x...> granularity=character, affinity=downstream, textRanges=(⏎
    "0...5",⏎    "5...10"⏎)`. A selection of no ranges is `(⏎)`.

**Secure coding.** `+supportsSecureCoding` is YES on both sides. A range is not
secure-coding, so a selection that holds ranges cannot actually be archived: the host
traps on `archivedDataWithRootObject:` and the port's archiver raises. The host's
answer is recorded from a separate process because a trap cannot be caught in the
differential.

## NSTextElement and NSTextParagraph

**The two derived ranges are nil until the paragraph is in a document.** A paragraph
with no content manager has no document to be in, and the host answers nil for both
ranges in that state - whatever the string is (`Hello`, `Hello<LF>`, `Hello<CR><LF>`,
`<LF>`, `a<LF>b`) and whatever element range is set, at 0 or at 100. The port asks
the content manager where the paragraph is (`-offsetFromLocation:toLocation:` from
the document's own start) and for a location that many characters on
(`-locationFromLocation:withOffset:`), so the two ranges come out in the content
manager's own location type; the derivation is written out and is asked of the
manager the moment one is attached. **This is a real dependency and not a finished
answer**: nothing this port carries yet makes an `NSTextContentManager`, so both
ranges are nil until that class lands.

**The derivation**, for when there is a manager: the content is the string without
the trailing newline that ends the paragraph and the separator is that newline, so the
two together are the paragraph's whole range; a carriage return before a line feed is
one separator and not two; a paragraph whose contents do not end in one has no
separator and its contents are the whole string.

**`-childElements`, `-parentElement`, `-isRepresentedElement`** arrived in iOS 16 and
are in a category of their own. An element with no parent has no children, and every
element is one the content manager enumerates - the base class and a paragraph
included. The tree those three describe is the content manager's to make out of
elements an application or a subclass supplies.

**`-isEqual:`** is identity for an element, on both sides: an element is equal to
itself and to no other element.

**`-description`** is `<NSTextElement: 0x...>` and, for a paragraph, the class, the
address and the string it holds: `<NSTextParagraph: 0x... "Hello">`. A paragraph made
with no string prints `(null)`, because that is what the format prints for nil.

## NSTextSelectionNavigation

Every answer this class gives is a question for the data source it was made with, and
nothing this port carries yet makes one, so the whole class is exercised in the state
where it has none. That is the honest reading and it is what the port does; the
header's rule is followed rather than the host's answer in a state the host is never
in.

**`-allowsNonContiguousRanges` starts YES** and `-rotatesCoordinateSystemForLayoutOrientation`
starts NO, which is the host's own pair of defaults, measured. Both are settable.

**`-destinationSelectionForTextSelection:...` is nil with no data source.** Every
answer of this method is a place in a document, and there is no document; the header
says a movement that produces no logically valid result answers nil (D4). The host
hands the selection straight back instead, for every destination and every direction,
but handing back a selection that did not move would say a movement happened. With a
data source the movement is the range between where the selection was and the location
the movement reaches, ordered whichever way it was made, and extending keeps the
selection's first location and moves only its end - which is what makes a backward
extension reach behind the cursor.

**`-deletionRangesForTextSelection:...`** is the selection's own ranges when it has
contents, whatever the destination, which is the header's own rule. For a cursor it
is what a move over the same destination would have selected; with no data source a
move produces nothing, so the range that comes back is the cursor's own 0-length
range - which is what the header asks for after a deletion ("a 0-length range
starting at the location of the first range returned") and what the host answers in
the same state.

**`-textSelectionForSelectionGranularity:enclosingPoint:inContainerAtLocation:`** is
nil, and so is **`-textSelectionsInteractingAtPoint:...`**, an empty array: there is
no line under a point and no data source to ask. The host agrees on both.

**`-textSelectionForSelectionGranularity:enclosingTextSelection:`** is nil on the
port. The host answers the selection's own range, unexpanded; an unexpanded range
would claim an expansion that did not happen, and there are no boundaries to expand
to.

**`-resolvedInsertionLocationForTextSelection:writingDirection:`** is the header's own
rule, which is the whole of it: the secondary location of a selection that is not
logical and has one, and nil otherwise. A secondary location is a location and not a
range, so there are not two ends of it for the writing direction to choose between
and the direction does not enter into the answer. The host answers the selection's own
location for a selection that *is* logical, for the left-to-right writing direction
only, and nil for the other (D5); the port answers nil either way.

**`-flushLayoutCache`** does nothing, because the port asks its data source for
everything each time and caches nothing. **`-description`** is the class and the
address and nothing else, with a data source and without.

## Not measured

- Every answer of `NSTextSelectionNavigation` **with a data source**. There is none to
  make on the measured host: `-[NSTextContentManager initWithTextStorage:]` is not
  there, and the class the navigation object is made for is the next group's work.
  Those answers are written from the header, which says for each of them what it is a
  question about, and each of them is marked in the code as such.
- The two derived ranges of a paragraph **with a content manager**, for the same
  reason.
- Whether the host's `-hash` for a selection is by value in every case, or only for
  the six keys measured here.
- Whether `-[NSTextElement init]` on the host is a fault the port should also refuse.
  It is, measured; the port answers with an element with no manager instead, because
  the header does not mark it unavailable and that state has answers for everything.

## The probes

Each is a separate process with none of the port's code in it, so what it prints is
the host's own UIKit. They are kept under `.agent-work/runs/textkit2/` and the
differential's own log beside them.

| File | What it measured |
| --- | --- |
| `probe-range-grid.m` / `.out` | `-containsRange:` and `-intersectsWithTextRange:` over forty-nine pairs, and the first answers for a range's descriptions and equality |
| `probe-selection-element.m` / `.out` | the typing attributes through the setter, the copy, both element descriptions, and what a selection answers for itself |
| `probe-paragraph-ranges.m` / `.out` | a paragraph's two derived ranges bare, with an element range at 100 and at 0, and the reason there is no case with a content manager: `-[NSTextContentManager initWithTextStorage:]` is not on the measured host |
| `probe-descriptions.m` / `.out` | the paragraph's own text with and without attributes, and equality and hashing for all three classes |
| `probe-selection-equality.m` / `.out` | which keys of a selection decide `-isEqual:`, one pair per key |
| `probe-initializers.m` | the unavailable initialisers, in one process, which is lost on the first fault |
| `probe-initializers-out-of-process.m` / `.out` | the same, one call per process, which is the only way a fault can be attributed: eight faults, all exit 139, and the archive a trap at exit 133 |
| `probe-navigation.m` / `.out` | the union rule over twenty-five pairs, the two flags' defaults, and every answer of the navigation object with no data source |
| `differential.log` | the differential's own run: `checks=2011 failures=0` |

`probe.out` in `.agent-work/runs/textkit2/` is the first probe, from the session before, and
it is a run transcript rather than a source file, so it lives with the run output and not in
this directory. Its reading of `-typingAttributes` - `typing=(nil)` on line 27 - is the one the
earlier commit message got backwards, and this file supersedes it. The rest of it stands and is
reproduced above.

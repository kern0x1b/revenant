# UISearchTextField, UISearchToken and the search bar's text field, iOS 13.0

Introduced in iOS 13.0: the text field of a search bar, which can hold tokens - small labelled chips - before the text. iOS 6 has the
field inside its search bar but no tokens; the port carries the class as a `UITextField` subclass that keeps the tokens and draws each as a
plain chip before the text.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `search` and
`searchcategories` groups), and the header of SDK 16.4.

## UISearchToken, as UIKit does

- `+tokenWithIcon:text:` takes a nil icon and a nil text; `representedObject` is nil and kept as set. A token is not copyable, is not
  secure coding and two tokens are equal only when they are the same object; `-init` makes a blank one.
- The system's `+tokenWithIcon:text:` answers an object of a private subclass (`_UISearchToken`), so its description names that class;
  the port's is a `UISearchToken`. The text is a copy; the icon is kept.

## UISearchTextField, as UIKit does

- A field made with `-initWithFrame:` has a rounded border, a clear button while editing and a magnifier as its left view, always shown;
  `allowsCopyingTokens` and `allowsDeletingTokens` are YES and `tokenBackgroundColor` is the system grey, RGB 142 142 147, until set; setting nil
  brings it back. The port draws the magnifier itself.
- `tokens` is a copy; nil is the empty array; the same token may be there twice. `text` **excludes** the tokens.
- `-insertToken:atIndex:` and the others raise as the system's do: a nil token, a negative index for remove and position:
  `NSInternalInconsistencyException`, "Invalid parameter not satisfying: token != nil" and "... tokenIndex >= 0"; an index out of range:
  `NSRangeException` "Token index 10 out of range: [0, 3)" for insert, remove and replace, `NSInvalidArgumentException` "Token index 4 out of range [0, 4)" for
  the position of a token. An index one past the end of an insert or replace, or the end itself for a remove, raises the message of
  the array the host keeps them in ("NSMutableRLEArray ...: Out of bounds").
- `-replaceTextualPortionOfRange:withToken:atIndex:` takes the text of the range out and puts the token in; a nil range or token raises.
- `searchSuggestions` arrived in iOS 16 and is not answered.

## What the port does

- Each token is a chip - a rounded label in the token background with white text, at most 120 points wide - laid out after the magnifier; the
  text, the placeholder and the editing rectangle start after the last chip, and never leave the text less than 30 points.
- A backspace with the caret at the start and no text deletes the last token when `allowsDeletingTokens` is YES, and sends the field's editing-changed event.
- `allowsCopyingTokens` is kept and does nothing: no token can be selected, so `-searchTextField:itemProviderForCopyingToken:` is never sent,
  and no paste item is made, so `-setSearchTokenResult:` is never sent.

## The two `absent` rows of this page, measured (2026-10-01)

Both rows above carried "the header of SDK 16.4; nothing of a release was read" as their `source`, and both reasons were about the port -
"no token can be selected, so none is copied" and "the release has no paste delegate that makes a token of pasted text". A claim about
the port is a queue entry; `absent` is a claim about the release. This is the release's own.

### The commands, from the root of the repository

```
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua UISearchTextField 6.1.3 4.3 16.0
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua UITextPasteItem   6.1.3 4.3 11.0
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua NSItemProvider    6.1.3 4.3 8.0
printf '%s\n' UISearchTextField UISearchToken UISearchTextFieldPasteItem UITextPasteItem NSItemProvider \
             searchTextField:itemProviderForCopyingToken: setSearchTokenResult: zzNonexistentNameForControl \
  | xmake l tools/cache-index/first-rung.lua
for r in 6.1.3 4.3; do
  for s in searchTextField:itemProviderForCopyingToken: setSearchTokenResult: zzNonexistentSelectorForControl:
  do printf '%s %-48s %s\n' "$r" "$s" "$(strings -a ~/.charon/dyld/$r/dyld_shared_cache_armv7 | grep -cxF "$s")"; done
done
```

### The output

```
6.1.3     ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
         classes 11378, of which UISearchTextField* 0
         protocols 1171, of which UISearchTextField* 0
4.3       ~/.charon/dyld/4.3/dyld_shared_cache_armv7
         classes 7187, of which UISearchTextField* 0
         protocols 564, of which UISearchTextField* 0
16.0      ~/.charon/dyld/16.0/dyld_shared_cache_arm64e
         classes 143137, of which UISearchTextField* 2 (UISearchTextField UISearchTextFieldAccessibility)
         protocols 25549, of which UISearchTextField* 1 (UISearchTextFieldPasteItem)
control: 3 name(s) beginning UISearchTextField found in this run, so a zero on another rung is the release's and not the reader's

6.1.3 / 4.3   UITextPasteItem* 0 classes, 0 protocols
11.0          classes 52768, of which UITextPasteItem* 1 (UITextPasteItem)
              protocols 8954, of which UITextPasteItem* 1 (UITextPasteItem)
control: 2 name(s) beginning UITextPasteItem found in this run

6.1.3 / 4.3   NSItemProvider* 0 classes, 0 protocols
8.0           classes 21641, of which NSItemProvider* 1 (NSItemProvider)
control: 1 name(s) beginning NSItemProvider found in this run
```

Three controls, three different positive rungs, each in its own run: 3 names at 16.0, 2 at 11.0, 1 at 8.0. Each zero is therefore the
release's and not the reader's.

```
UISearchTextField                    16.0
UISearchToken                        16.0
UISearchTextFieldPasteItem           16.0
UITextPasteItem                      11.0
NSItemProvider                        8.0
searchTextField:itemProviderForCopyingToken:  16.0
setSearchTokenResult:                16.0
zzNonexistentNameForControl          NONE     <- the control

6.1.3  searchTextField:itemProviderForCopyingToken:   0
6.1.3  setSearchTokenResult:                          0
6.1.3  zzNonexistentSelectorForControl:               0
4.3    the same three, 0
```

### What each of the two rows rests on

**`-[UISearchTextFieldDelegate searchTextField:itemProviderForCopyingToken:]`.** Three separate absences, each measured on its own:
no class and no protocol of the prefix at either end, so there is no `UISearchTextField` and **no `UISearchTextFieldDelegate`** to ask -
the protocol is not even in 16.0's own metadata, only the paste protocol of that prefix is; the selector is in neither cache; and the
release has no `NSItemProvider` to answer with either, that class first appearing at 8.0. Worth recording separately because the port
**does** carry `NSItemProvider` at minimum 6.0 (`registry/Foundation/ios11.json`), so the return type is available to the port and still
the release cannot answer - which is exactly the distinction `absent` is about.

**`-[UISearchTextFieldPasteItem setSearchTokenResult:]`.** The protocol refines `UITextPasteItem`, and that protocol does not exist below
11.0: 0 classes and 0 protocols at 6.1.3 and at 4.3, one of each at 11.0. `UISearchTextFieldPasteItem` itself is 0 below 16.0. So the
release can hand an application no paste item of any kind, and the port declines `UITextPasteItem` as well
(`registry/UIKit/ios11.json`, `absent`), which is another band's row and is not touched here. A protocol cannot be carried without the one
it refines, and nothing in 6.1.3 refines anything: its own paste path is `UIPasteboard`'s `-setItems:` / `-items` dictionary of
representations, read from the 6.1.3 inventory.

### What a reader should take from this

Both rows stay `absent`, and the verdict is now the release's own rather than a statement about the port: **0 names of the prefix at both
ends, 0 of the refining protocol below 11.0, 0 of the item provider below 8.0, three controls passed in three runs.** The port's own gap -
that its chips cannot be touched and so no token is ever copied - stays where it belongs, in "Where it differs" above, where a reader
looks for what the port does instead.

## Where it differs

- Positions are the release's own, counted over the text: the tokens are **not** characters of the document. `positionOfTokenAtIndex:` answers the
  start of the document for every token, `textualRange` is the whole document, and `tokensInRange:` answers every token for a range that starts at
  the start of the document and none for one that does not or for the range `textualRange` answered (which the host's tokens, being before it, are not in).
  The host counts each token as one position, so a range over just the first position holds one token there and all of them here.
- Tokens are not selected, dragged, copied or shown as bubbles with an icon: the icon is kept and not drawn.

## UISearchBar.searchTextField

- Answers the text field the search bar holds - the release's `UISearchBarTextField`, found among its subviews at any depth - and nil when
  it finds none. That class is not a `UISearchTextField`, so the port gives the field a subclass of its own class, made once, with the token members
  added, and switches the field to it: the tokens are **kept and not drawn** there, and a backspace does not delete one. The object is the same each
  time it is asked, and it answers `isKindOfClass:` for its own class and not for `UISearchTextField`. A field that is already a `UISearchTextField` is
  answered as it is.

## UISearchController

- `automaticallyShowsCancelButton`, `automaticallyShowsSearchResultsController` and `showsSearchResultsController` of iOS 13 are carried by
  `UISearchController` itself; see `UISearchController.md`.
- `automaticallyShowsScopeBar` is kept, starts NO (Manual), as the host measures it on the iPad idiom (the header gives no default) and changes
  nothing: the controller never shows the scope bar of its search bar, and says so once in the log when the property is set.

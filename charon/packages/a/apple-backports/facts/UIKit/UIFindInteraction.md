# UIFindInteraction, iOS 16

`UIFindInteraction` (iOS 16) is the find navigator's interaction: an application makes one with a delegate that supplies a session, adds it to
a view, and presents the navigator. The delegate is asked for a `UIFindSession` for the view and is told when a search begins and ends. The port
builds the state and the conversation with the delegate. It draws no find bar: the navigator's visibility is kept, and the delegate sees it begin
and end, as on the host.

Source: the host's own UIKit under Mac Catalyst (macOS 27), measured by `tests/backports/host/find-interaction`: a bundled application with the iPad
idiom (`UIDeviceFamily` 2), a key window, a view and a text view in it. 37 checks compared line for line with the port's classes; five planted
controls fail (the session cleared on dismissal, the session never reused, the search text copied, the navigator never shown, the delegate held
strongly). The host-only observations are written beside the checks and are not compared.

## What the host does, measured

- `initWithSessionDelegate:` keeps the delegate weakly. Released, `delegate` reads nil.
- The defaults: the navigator is not visible, there is no active session, and the search text, the replacement text and the options-menu provider
  are nil.
- The search text and the replacement text are kept as the object given. The readback follows a change made to a mutable string after it was
  given, so the setter does not copy. Setting nil clears the text.
- The options-menu provider is kept as a block and reads back set, and clears to nil.
- Presenting the navigator (`presentFindNavigatorShowingReplace:`) with an attached view asks the delegate for a session with
  `findInteraction:sessionForView:`, passing the view the interaction is attached to.
  - With a nil session the navigator stays hidden, and no begin or end callback is made.
  - With a session the navigator is visible, the session is the active one, the delegate is told `didBeginFindSession:`, and the active session
    is the one the application made.
- Dismissing a shown navigator (`dismissFindNavigator`) hides it and tells the delegate `didEndFindSession:`. Dismissing one that is not shown
  makes no callback.
- **After a dismissal the active session stays set.** Presenting again then does not ask the delegate for a session: the held one is reused and
  the begin callback names it.
- A session made with `UITextSearchingFindSession` on a text view reads: no results (`resultCount` 0), no highlighted result
  (`highlightedResultIndex` NSNotFound), the display style 0, no replacement support, and `searchableObject` the text view it was made with.
  Its replacement support is NO whether or not the replace field was asked for.
- Attached to a view, the interaction is the view's; `removeInteraction:` makes `view` nil.

## What the port does

- Keeps the delegate weakly, the view the interaction is attached to, the search text, the replacement text and the provider as given (not copied
  for the texts; the provider is copied, as its block type is).
- Presenting, on an attached view, reuses the active session or asks the delegate for one; a session makes the navigator visible and tells the
  delegate the search began. A nil session does nothing.
- Dismissing a shown navigator hides it and tells the delegate the search ended; the active session stays.
- `findNext`, `findPrevious` and `updateResultCount` do nothing: the port has no results to step through.
- Presenting an interaction that is not attached to a view does nothing. The host's answer there is not measured.
- `UIFindSession` answers the empty session's values measured above, and `UITextSearchingFindSession` holds its searchable object weakly.

## Not built

- The navigator's drawing: the port shows no find bar.
- The session's searching: `performSearchWithQuery:options:`, the replacement methods, `highlightNextResultInDirection:` and
  `invalidateFoundResults` are not built, so a call raises. A session that searches needs the `UITextSearching` protocol's methods, whose rows
  stay owed.
- `UITextView.findInteraction` and `findInteractionEnabled`, and the text view's own find. Measured as host-only evidence in the harness:
  enabling the property adds a `UIFindInteraction` to the text view, whose view is the text view, whose delegate is the text view, and which the
  text view's interactions contain. Presenting that interaction on the host makes the navigator visible with a `UITextSearchingFindSession` over
  the text view, and that session's replacement support is YES, where a session the application makes reads NO. The port has no reason yet for
  that difference, so the text view's properties stay owed.
- The host's session-for-view call with the text view as the delegate: the port's text view does not answer it.

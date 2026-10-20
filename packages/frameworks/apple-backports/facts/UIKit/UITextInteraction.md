# UITextInteraction, iOS 13

Introduced in iOS 13: the interaction that gives a custom text input the caret, selection and menu gestures of the system's own text
views.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0) for the defaults and the accessors; the behaviour of the gestures is the
port's own, checked by the `textinteraction` group of `tests/backports/host/uikit2` against a text field, and by `uirest.m` on a
device. The host's recognisers, handles and loupe are not something a test can read.

## What the interaction does

`+textInteractionForMode:` makes the interaction for the editable or the non-editable mode and keeps the mode, even for a value that is
neither. `textInput` and `delegate` are weak. `gesturesForFailureRequirements` is empty until the interaction is added to a view; then it
is four recognisers on that view - taps of one, two and three, each requiring the next to fail, and a long press.

The gestures work through the text input protocol the view already has, so they suit a custom input whose positions and tokenizer
are its own; the input is `textInput`, or else the view itself when it is one.

- A tap asks the delegate `interactionShouldBegin:atPoint:` and, if it agrees, `interactionWillBegin:`, makes the input first
  responder if the interaction is editable, puts the caret at `closestPositionToPoint:` and tells `interactionDidEnd:`.
- Two taps select the word under the point with the tokenizer and three the paragraph, and show the menu for the selection with
  `UIMenuController`; they take the first responder in either mode, since the menu needs one.
- A long press moves the caret with the finger from where it began and ends the interaction when it ends. It is for the editable mode
  only.

## What it is not

The system's interaction draws selection handles and a magnifier, and a caret that follows the finger with feedback; the release has
no public way to draw them and the port does not. The selection is the input's own, so an input that draws it draws it. The delegate's
three messages are sent as described.

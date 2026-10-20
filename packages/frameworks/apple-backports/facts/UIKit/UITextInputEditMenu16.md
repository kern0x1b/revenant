# UITextInput's iOS 16 edit-menu methods, on UITextField and UITextView

`-editMenuForTextRange:suggestedActions:`, `-willPresentEditMenuWithAnimator:` and
`-willDismissEditMenuWithAnimator:` are `@optional` members of the `UITextInput` protocol (SDK
`UITextInput.h`), which the release's own `UITextField` and `UITextView` already conform to on
iOS 6.1.3 - the protocol predates it. Demand: a subclass overriding one of the three and calling
`[super ...]` inside the override, which crashed with an unrecognised selector when the
superclass carried none of them.

`UITextField+EditMenu16.m` and `UITextView+EditMenu16.m` each add a category defining all three,
with the return each is documented to accept when a caller does not customise the menu:
`editMenuForTextRange:suggestedActions:` returns `nil`, which the header documents as "present
the default system menu"; the two lifecycle callbacks are no-ops, the same as a class that never
overrides them.

## What this does not do

The release's own long-press/selection interaction on iOS 6.1.3 builds its menu with the old
`UIMenuController`, not `UIEditMenuInteraction` - that type does not exist here (no
`UIEditMenuInteractionAnimating` presentation on this release), so neither `UITextField` nor
`UITextView` ever calls its own `editMenuForTextRange:suggestedActions:` or the two lifecycle
methods internally, and an override placed on either class is never invoked by the system - only
reachable through direct calls or `[super ...]`. That is a real wall (no `UIEditMenuInteraction`
substrate on iOS 6.1.3), but it does not change what these three methods must answer when called
directly, which is well-defined regardless of who calls them.

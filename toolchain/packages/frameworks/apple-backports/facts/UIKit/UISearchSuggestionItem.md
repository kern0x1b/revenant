# UISearchSuggestionItem and UISearchSuggestion, iOS 16.0

Introduced in iOS 16.0: a suggestion listed under a search field, with the text it suggests, an optional attributed form, a description, an
icon, and an object the app attaches (`representedObject`). The protocol `UISearchSuggestion` is what a search controller's
`searchSuggestions` holds; the item is the class an app makes. The port has no search field that shows a suggestion list
(`facts/UIKit/UISearchController.md`, `facts/UIKit/UISearchTextField.md`), so the items are values the app holds, and nothing draws them.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0`).
The protocol has `localizedSuggestion`, `localizedAttributedSuggestion` and `representedObject` required, and `localizedDescription` and
`iconImage` optional. The class conforms to it. The header marks the attributed initialisers and factories unavailable on tvOS.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/suggestion-item`, which compiles the port
source beside the host's class in one process and prints the same checks for both.

## As UIKit does

- A plain initialiser (`initWithLocalizedSuggestion:`, with or without a description and icon) keeps the suggestion copied (a mutable string
  changed afterwards does not change it); the description is copied the same way; the icon is kept as the object given.
- A plain initialiser leaves the attributed suggestion nil.
- An attributed initialiser keeps the attributed suggestion as the object given (the same object comes back), and sets the plain suggestion to
  its text.
- A nil suggestion does not make a nil object: the initialiser answers an item whose suggestion is nil.
- `representedObject` is stored as set, the object given, and a nil clears it.
- Equality compares the suggestion, the attributed suggestion, the description, the icon (as objects) and the represented object. Two equal
  items hash alike, and a nil never equals a set value. Two items with nil suggestions are equal.
- The runtime `-init` answers an item with a nil suggestion.

## What the port does

- `UIKit/UISearchSuggestionItem.m`: the designated initialisers are the three-argument ones (plain and attributed); the shorter initialisers and
  the factories call them. Strings are copied, as the release copies them; the attributed suggestion, the icon and the represented object are
  kept as given.
- `isEqual:` compares the five values with the equality the release uses (`isEqual:` on the objects, identity for the nil case), and `hash`
  follows the suggestion and the description, which every equal pair shares.
- The class declares `<UISearchSuggestion>`, so the port's object emits the protocol. Measured on the armv7 object of `UISearchSuggestionItem.m`
  compiled for 6.1.3 against the 16.4 SDK: `__objc_protolist` lists `__OBJC_LABEL_PROTOCOL_$_UISearchSuggestion`, so `NSProtocolFromString`
  answers the name in the port's image.

## Named differences

- None measured in the differential. The host's class has no hidden setters for these values (`setLocalizedSuggestion:` is absent on both sides),
  and it is not `NSCopying` on either side.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The class is plain Objective-C state and its equality, so the host
  run is its oracle; the protocol emission was read from the object, not run on the device.
- The differential compares the items the factories and initialisers make. The attributed suggestion's attributes (colour, font) are carried as
  the object given; the comparison does not look inside them beyond `isEqual:`.

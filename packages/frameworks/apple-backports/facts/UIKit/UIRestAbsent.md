# What of iOS 13 and 14 is absent, or is sent nothing, and why

Each of these was weighed for a substitute that would work on iOS 6; the reason is what stopped it.

## Absent

- **`NSToolbar` and the two sidebar separator identifiers.** AppKit's toolbar, reachable from UIKit only under Mac Catalyst. Nothing
  on iOS 6 has one, and no application built for iOS can name it.
- **The columns of `UISplitViewController`, iOS 14** (`initWithStyle:`, the column widths, the split behaviour, `showColumn:`,
  `viewControllerForColumn:` and their delegate). The release's split view controller is the iPad's two column controller and raises
  on an iPhone; the three column design would have to be laid out by a class of the port that could not be the release's class. An
  application that checks for the members first, as it must for any earlier release, uses its own layout.
- **The document picker made of `UTType`s, iOS 14.** `UniformTypeIdentifiers`, which makes the types, is not on iOS 6, so the argument
  cannot be made; the picker of iOS 8 and 11 to 13 is there.
- **`UIStoryboard` creators, iOS 13.** The release unarchives a storyboard's controllers itself and gives application code no coder to
  make one from. A substitute would have to take over the first `initWithCoder:` of the controller class during instantiation and
  give it to the creator, and there is no storyboard on the host to hold that against (no compiler for them without Xcode), so it is
  left rather than shipped unproved.
- **`UIColor.accessibilityName`.** A table of localised colour names that the release does not have.
- **`initWithAttributedName:...` of `UIAccessibilityCustomAction`.** As iOS 11's, since VoiceOver of the release never asks.
- **`-[UIFontDescriptor fontDescriptorWithDesign:]`** with `UIFontDescriptor` (`UIFontDescriptor.md`).

## Ignored: declared, and never sent

The delegates of the interactions that never fire, the preview and multiple selection methods of table and collection view
delegates, and the other methods listed in `UIViewControllerCallbacks13.md`. Each is a message the release would have to send for
something that does not exist there, and an application that implements it is not called.

## Pasteboard patterns

`-[UIPasteboard detectPatternsForPatterns:...]` and `detectValuesForPatterns:...` complete on the main queue with no pattern found
and say so once in the log. The host's own never completes in a process that is not the frontmost application, so there is no
evidence to derive its classification of "probable web search" from; an application that decides what to offer by the answer offers
nothing, which is the safe reading.

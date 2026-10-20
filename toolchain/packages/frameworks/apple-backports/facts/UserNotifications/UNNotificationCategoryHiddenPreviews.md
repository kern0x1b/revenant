# The placeholder and the summary of a notification category, iOS 11 and 12

iOS 11 added to a `UNNotificationCategory` the text a notification shows in place of its body while previews are hidden, and iOS 12 the format of the line that summarizes a group of its notifications. Both come with
factory methods that take them, and two properties that answer them.

Source: UserNotifications of the arm64 shared cache of iOS 12.0 - `+categoryWithIdentifier:actions:intentIdentifiers:hiddenPreviewsBodyPlaceholder:options:` at `0x18b344700`, the one with a summary format at `0x18b3448f0`, the
factory of iOS 10 at `0x18b344548`, the two getters and `-isEqual:` at `0x18b344ebc` - and the host's UserNotifications under Mac Catalyst, held against the port by `tests/backports/host/usernotifications/run.sh` (the differential of the whole
framework, 6062 checks) and its `mutants.sh`.

## What the port does

- The two factories make the category the factory of iOS 10 makes, and keep a copy of the placeholder and of the summary format; the one of iOS 11 gives the summary format the empty string, as the release does.
- The getters answer what was kept; a category made by the factory of iOS 10 answers the empty string for both, as the release does, and a placeholder or a format that was given as nil answers nil.
- Two categories are equal when their identifiers, actions, intents and options are equal and so are their placeholders and their summary formats, as in iOS 12.
- A category copies to itself, as it does in the release.

The placeholder is kept with the category and is not part of its coding: a category archived and read back is the category of iOS 10, with the empty placeholder and format.

## Not carried

That a notification is drawn with the placeholder: iOS 6 has no hidden previews, and the port hands `UILocalNotification` no title, subtitle or placeholder of a category.

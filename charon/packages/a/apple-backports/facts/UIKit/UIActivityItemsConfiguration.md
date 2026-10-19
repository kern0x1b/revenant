# UIActivityItemsConfiguration and the activity view controller made of one, iOS 13 and 14

Introduced in iOS 13: an object that tells the share machinery what a responder can share - item providers, metadata, previews,
application activities - and in iOS 14 `-[UIActivityViewController initWithActivityItemsConfiguration:]`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by the `activityitems` group of
`tests/backports/host/uikit2`; `tests/backports/device/uirest.m` for the sheet on a device.

## The configuration

`+activityItemsConfigurationWithObjects:` and `-initWithObjects:` make one item provider for each object, with `NSItemProvider`
`-initWithObject:`; an object that cannot be written raises the unrecognised selector `writableTypeIdentifiersForItemProvider`, and nil
objects raise "-[UIActivityItemsConfiguration initWithObjects:]: objects parameter cannot be nil." The objects are copied at once. The
providers are made again on each call, so two calls answer two arrays. `+activityItemsConfigurationWithItemProviders:` keeps the
providers it is given. `+new` and `-init` are unavailable in the header and make a configuration.

`supportedInteractions` answers the share interaction; the host also lists the copy interaction that iOS 16.4 added, which the port
does not carry. `localObject`, the four block properties and the interactions are read and written as they are given, the blocks
copied. `-activityItemsConfigurationSupportsInteraction:` is whether the interaction is in the list; the two metadata questions and
the preview question ask their block, and answer nil when there is none. The four answers of the reading protocol are the ones an
application's own class can give.

## What differs

The host's providers for a string also carry a `public.file-url` representation, written to a temporary file when the provider is
asked for it, so that an app that takes files can take the text. The port's do not: the providers are `NSItemProvider`'s own of the
port, holding the object.

## The activity view controller

`-initWithActivityItemsConfiguration:` is `-initWithActivityItems:applicationActivities:` of the release, with one activity item
source for each item provider and the configuration's application activities. A source answers a placeholder of the provider's kind - a
URL for a provider that can load one, an empty string otherwise - and loads the real object when the sheet asks for the item, waiting
for the provider on the main run loop for up to ten seconds. A provider that offers neither a URL nor a string gives no item.

## The responder

`UIResponder.activityItemsConfiguration` is kept and answers nil at first. iOS 6 has no Share command in an edit menu and no keyboard
shortcut for sharing, so nothing reads it, and the first one set says so once in the log. `editingInteractionConfiguration` answers the
default, as UIKit's does for a responder that does not override it.

# NSExtensionItem, iOS 8

Introduced in iOS 8: what an application hands to an app extension, such as a share or action extension, and what the
extension hands back: an attributed title, attributed text, attachments that are `NSItemProvider`s and a dictionary.

Source: the host's own Foundation, asked for the defaults, the properties and the archive, and held against the port by
the `extensionItem` record of `tests/backports/device/itemprovider-cases.m`.

## What the port does as the system does

The dictionary is the storage: the title, the text and the attachments are kept in it under
`NSExtensionItemAttributedTitleKey`, `NSExtensionItemAttributedContentTextKey` and `NSExtensionItemAttachmentsKey`, and
read back from it, so a new item has an empty dictionary and no title, text or attachments; setting a property to `nil`
takes its key out; and setting `userInfo` replaces the dictionary, taking the title, text and attachments with it, and
`nil` leaves none. An item is copied and archived, under the single key `NSExtensionItemUserInfoKey`, whatever it holds.

## What differs

The system keeps an attributed string in the dictionary as RTF data, which iOS 6 cannot write, so the port keeps the
archive of the string; an application that reads the dictionary as data finds another encoding. The copy of an item is
not held to the system's, which leaves out the title and text of an item whose dictionary was replaced.

## What it cannot do

iOS 6 has no app extensions: nothing hands an item to an extension, and an extension never runs, so the class is
`inert`. The application that builds an item to share with `UIActivityViewController` finds the release's sheet ignoring
it.

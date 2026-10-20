# UIDocumentMenuViewController, iOS 8

Introduced in iOS 8.0 (deprecated in iOS 11): the menu an application presents before it opens a document picker - the places a document can come from (iCloud Drive, the applications
that provide documents, options the application adds itself) - which answers its delegate with the picker the person chose, or with a cancel.

Source: the host's own UIKit under Mac Catalyst (`host/documentmenu/run.sh`): the presentation style of a new menu (100, a value of its own), no delegate, a popover presentation controller that is the same one every time,
the modes each initializer takes and the words it refuses the others in (`initWithDocumentTypes:inMode:` takes import and open, `initWithURL:inMode:` export and move and a file that is there),
the plain `init` refused, options added. `device/documentmenu.m` repeats them and shows the menu on an iPad 2 and an iPhone 4S.

## What the port does

The menu is a view controller of the class, and presenting it does not present it: the port's presentation hook answers the presentation with an action sheet of the port's `UIAlertController`, from the
popover presentation controller's source view (or bar button item) on an iPad and from the window on a phone. The sheet lists the options the application added with `UIDocumentMenuOrderFirst`,
then Browse, then those with `UIDocumentMenuOrderLast`, and Cancel last. An option runs its handler; Browse makes a `UIDocumentPickerViewController` for the menu's types or URL and mode
and sends `documentMenu:didPickDocumentPicker:` to the delegate, which presents it; Cancel sends `documentMenuWasCancelled:`. There is no iCloud Drive and no provider on iOS 6, so
the one place a document comes from is the picker's own browser (`UIDocumentPickerViewController.md`), and the images of options are not shown (an action sheet has none).

## What differs

The menu is not itself the presented controller: `presentedViewController` of the presenter is the port's sheet, not the menu, and dismissing the menu does nothing since the sheet dismisses itself on a choice.
The title of the way to the picker is "Browse", not the names of the release's providers.

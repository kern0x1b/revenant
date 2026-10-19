# UIDocumentPickerViewController, iOS 8

Introduced in iOS 8: the view controller through which an application opens or imports a document, and exports or
moves one. iOS 11 added the plural `initWithURLs:` and `allowsMultipleSelection`, iOS 13 `shouldShowFileExtensions`
and `directoryURL`, and iOS 14 the four `UTType`-based initializers below.

Source: the host's own UIKit under Mac Catalyst, asked for every initializer and mode and held against the port by the
`documentpicker` group of `tests/backports/host/uikit2/run.sh`; and `tests/backports/device/documentpicker.m`, which
drives the browser with real touches on iOS 6. The iOS 14 pair's defaults are not from Catalyst but from the local
machine's own SDK header - `UIDocumentPickerViewController.h` under `/Library/Developer/CommandLineTools/SDKs/
MacOSX26.5.sdk` - which documents each default in its doc comment; see `UTType.md` for the class the two pairs take.

## What the port does as the system does

`initWithDocumentTypes:inMode:` takes the import and open modes and raises `NSInternalInconsistencyException` for the
others; `initWithURL:inMode:` and `initWithURLs:inMode:` take the export and move modes and raise the same for the
others, with the system's reasons. The export and move initializers also refuse a `nil` URL or `nil` array ("must be
called with a valid URL") and a file URL whose file is not there ("must be called with a URL pointing to an existing
file", followed by the error `-checkResourceIsReachableAndReturnError:` gave); a folder, a web address and an empty
array are taken. The reason names the initializer the caller used, so `initForExportingURLs:asCopy:` is named for
itself, not for the `initWithURLs:inMode:` it stands on. `init` and `initWithNibName:bundle:` raise `NSInvalidArgumentException`. The
properties are kept and the delegate is weak.

## The iOS 14 initializers

`initForOpeningContentTypes:contentTypes asCopy:asCopy` reduces `contentTypes` to their `UTType.identifier` and calls
`initWithDocumentTypes:inMode:` with Import if `asCopy` is set, Open otherwise - the same Import/Open distinction the
port's browser already implements. `initForOpeningContentTypes:` calls it with `asCopy:NO`, matching the header's own
doc comment ("giving you access to the original document").

`initForExportingURLs:urls asCopy:asCopy` takes the same route as `initWithURLs:inMode:` with Export if `asCopy` is set, Move otherwise.
`initForExportingURLs:` calls it with `asCopy:NO`, matching the header's own doc comment for the single-argument form
("the original document will be moved to the destination") - the opposite default from the opening pair, read
directly off the header rather than assumed to match.

## The browser

iOS 6 has no document providers, so the picker is a file browser over the device's own file system, in a navigation
controller inside the picker, presented as a form sheet.

- The first page lists the locations: the application's home, `/var/mobile/Media`, `/var/mobile/Documents`,
  `/var/mobile` and `/`, each only if the application can read it. `directoryURL`, when it is an existing folder, opens
  the browser inside it with the trail back to its location.
- A folder lists folders first, then files, by name; hidden files are not shown. Extensions are hidden unless
  `shouldShowFileExtensions` is set.
- `documentTypes` filter the files through the UTI of their extension (`UTTypeConformsTo`); a file that does not
  conform is greyed and cannot be chosen. `public.item` accepts everything; folders are always entered.
- Open mode answers the chosen file's own URL. Import mode answers a copy in a fresh folder of the temporary directory,
  as the system does. With `allowsMultipleSelection` rows are ticked and a Done button answers all of them, in the order
  chosen. The plural delegate method is used when the delegate has it, else the singular one.
- Export and move show a folder browser whose button, "Copy" or "Move", answers the URLs of the copies or the moved
  files inside the folder shown; a name already taken there gets a number.

- Cancel dismisses the picker and then sends `documentPickerWasCancelled:`; a choice dismisses it and then sends the URL.

## What differs from the system

There is no iCloud Drive, no other application's documents, no recents and no tags, and no security scope
(`NSURL` answers YES to `startAccessingSecurityScopedResource`; see `NSURL.md`). The browser is the system's file
system, unsandboxed on a jailbroken device.

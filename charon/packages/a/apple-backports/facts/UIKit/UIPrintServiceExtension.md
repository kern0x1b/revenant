# UIPrintServiceExtension, iOS 14.5

Introduced in iOS 14.5 as the base class of a print service extension's principal object: the system asks it for the
printer destinations a print job can go to. The SDK 16.4 header is the contract (`UIPrintServiceExtension.h`):
`-printerDestinationsForPrintInfo:` answers `NSArray<UIPrinterDestination *>`, and the class is `NSObject`.

The release (6.1.3) has no extension system, so nothing asks a print service extension for destinations. The base class
answers what the host answers before a subclass overrides it: no destinations.

## Answers, measured on the host

A probe on Mac Catalyst, and the differential in `tests/backports/host/uikit-printer/` for the matching lines:

- `-init` works.
- `-printerDestinationsForPrintInfo:` answers an empty `NSArray` (count 0) for a nil print info and for
  `+[UIPrintInfo printInfo]`.

## What the port does

- `-printerDestinationsForPrintInfo:` answers an empty array for any print info, the same answer as the host.
- Nothing else is declared. The port has no print service extension to call it: a subclass in an application overrides
  the method, and on 6.1.3 no system call reaches it.

## Open

- The host's answer comes from the extension machinery, which the release does not have. The port's answer is the base
  class's default and does not read any printer: an application that overrides the method is the only source of
  destinations on this release.

## Device

Not run on a device. The class has no system caller on 6.1.3, so there is nothing to measure there.

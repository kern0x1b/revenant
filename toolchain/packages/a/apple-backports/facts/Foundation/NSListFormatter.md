# NSListFormatter, iOS 13

A formatter that joins items into a localized list ("a, b, and c").

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The patterns (start, middle, end, two, and the unit-list variants) are read from the host per locale into CharonListPatterns.h, with the bidi isolates the host inserts and the context rules for es, he and th. Canonical identifier aliases are resolved before lookup. itemFormatter formats each item; without one, each item is its description. stringForObjectValue: answers nil for anything but an array.

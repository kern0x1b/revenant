# CLGeocoder preferredLocale, postal addresses, and CLPlacemark timeZone and postalAddress, iOS 9 and 11

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction:
`-[CLGeocoder geocodeAddressString:inRegion:preferredLocale:completionHandler:]` at `0x187d9d9a8`,
`-reverseGeocodeLocation:preferredLocale:completionHandler:` at `0x187d9ce2c`, `-[CLPlacemark timeZone]` at `0x187da5d48`; the
SDK headers of iOS 16.4 for `CLGeocoder.h` and `CLPlacemark.h`; and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2,
through `tests/backports/device/corelocation.m`.

## What is read of the newest release

- The two preferred-locale methods put a block on a queue of the geocoder and call the geocoder's internal request with the
  locale; the locale decides the language of the placemark that comes back, which the geocoding server chooses, not
  CoreLocation.
- `-[CLPlacemark timeZone]` reads a field of the placemark's own internal object and answers it.
- The postal address methods and `-[CLPlacemark postalAddress]` take and answer `CNPostalAddress`, a class of the Contacts
  framework of iOS 9.

## What the port does

iOS 6 has the geocoder and its two requests without a locale, and the placemark it makes carries no time zone. The two
preferred-locale methods are those requests: they send the release's `-geocodeAddressString:inRegion:completionHandler:` and
`-reverseGeocodeLocation:completionHandler:` and drop the locale, so the language of a result is the one the device is set
to and an application that asked for another gets that one. `-[CLPlacemark timeZone]` answers nil, which its header allows,
and says so once in the log. The postal address methods and `postalAddress` are absent because the class they need is not in
the release.

## What was measured

The emulated iOS 6.0, an iPad 2 and an iPhone 4S on iOS 6.1.3, the same answers on all three: the geocoder answers both
preferred-locale selectors and does not answer `geocodePostalAddress:completionHandler:`; a placemark made with `-init` has a
nil `timeZone`, with its line written to the log once, and does not answer `postalAddress`. No address was geocoded, since
that needs the network and the language of the answer is the server's, so that the locale is dropped was read, not observed.

## The time zone of a placemark, measured on the host

The host's `-[CLPlacemark timeZone]` is not nil for a placemark the geocoder made from a coordinate. Measured on the
Catalyst host with the network (a reverse geocode of each coordinate, a 15-second wait for each answer):

- 51.5074, -0.1278 (London): locality "London", time zone `Europe/London`.
- 35.6812, 139.7671 (Tokyo): locality "Chiyoda", time zone `Asia/Tokyo`.

The zone is the placemark's own answer for the place, which the geocoder gives with the placemark. The release's
placemark has no such field, and `NSTimeZone` on iOS 6 has no lookup by coordinate, so the port cannot answer the
host's value without zone boundary data it does not carry. That is why `CLPlacemark.timeZone` stays owed; the port's
nil is the release's own answer for a placemark it has no zone for, and is not the host's answer.

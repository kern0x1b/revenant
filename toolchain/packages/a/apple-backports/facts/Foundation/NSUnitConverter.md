# NSUnitConverter

Introduced in iOS 10.0. The abstract converter. Its own implementation converts
nothing.

Source: the host's Foundation and the armv7s shared cache of iOS 10.0.1.

| member | behaviour |
|---|---|
| `-baseUnitValueFromValue:` | returns the value unchanged. |
| `-valueFromBaseUnitValue:` | returns the value unchanged. |
| `-copyWithZone:` | returns the receiver. This is where the copy of a converter that `NSDimension` makes ends up: the subclasses do not implement `NSCopying` themselves. |

The class declares no ivars and is not archivable on its own.

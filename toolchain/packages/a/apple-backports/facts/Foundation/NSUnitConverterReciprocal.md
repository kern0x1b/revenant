# NSUnitConverterReciprocal

Introduced in iOS 10.0. Private: it is in no SDK header. Converts by `y = r / x`
in both directions.

Source: the armv7s shared cache of iOS 10.0.1, confirmed on the host, where the
class still carries this name and `-[NSUnitFuelEfficiency milesPerGallon]` still
uses it.

It is carried under Apple's own name rather than a Charon one because
`NSDimension` archives its converter as an object, so the class name is written
into the archive. Under any other name an archive written here would not open in
the real Foundation, and one written there would not open here — and archive
compatibility is observable behaviour, which is what this package exists to
carry.
## Carried under Apple's name, but only where there is none

The class is private, so the framework exports no symbol for it. A band can drop
and re-export an object whose symbols the release already exports; here there are
none to match, so the object would stay in every band and a release that has the
class would end up with two of that name.

The name cannot simply be given up, because an archive names the class and an
unarchiver looks it up by that name. So the class is defined under a Charon name
and Apple's name is registered **for** it, as a subclass made at run time, and only
where `objc_getClass` shows the runtime has none. On iOS 6 ours answers to the
name; on a release that has its own, nothing is registered and the system's is
used.

The registration happens when the library loads, not when the first instance is
made. That is not a detail: an unarchiver resolves a class by name before anything
has had a reason to make one, so a lazy registration would leave an archive
written by the real framework undecodable. The device test caught exactly that -
`NSClassFromString` answered nil until something else had built a curve.


## Behaviour

| member | behaviour |
|---|---|
| `-initWithReciprocalValue:` | stores the value. |
| `-baseUnitValueFromValue:` | `reciprocalValue / value`. |
| `-valueFromBaseUnitValue:` | `reciprocalValue / value`. The conversion is its own inverse. |
| `-copyWithZone:` | returns the receiver. |
| `-isEqual:` | the reciprocal values are compared. |
| `-description` | `[super description]` with `" reciprocalValue = %f"` appended. |
| `+supportsSecureCoding` | `YES`. |

Only `NSUnitFuelEfficiency` uses it: miles per gallon is not proportional to
litres per 100 km but inverse to it.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.reciprocalValue` | `-encodeDouble:forKey:` | `-decodeDoubleForKey:` |

Non-keyed coders raise `NSInvalidArgumentException`:

- encoding: `NSUnitConverterReciprocal encoder does not allow non-keyed coding!`
- decoding: `NSUnitConverterReciprocal cannot be decoded by non-keyed archivers`

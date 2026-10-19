# NSDimension

Introduced in iOS 10.0. A unit that knows how to convert to and from the base
unit of its dimension.

Source: the host's Foundation and the armv7s shared cache of iOS 10.0.1.

## Behaviour

| member | behaviour |
|---|---|
| `-initWithSymbol:converter:` | forwards to `-initWithSpecifier:symbol:converter:` with `NSUIntegerMax`. |
| `-initWithSpecifier:symbol:converter:` | private; `[super initWithSymbol:]`, then the converter is **copied**. |
| `-converter` | the stored converter. |
| `-specifier` | private; the `_reserved` ivar the SDK header declares. |
| `-isEqual:` | `[super isEqual:]`, then the converters are compared. |
| `+baseUnit` | raises `NSInvalidArgumentException`: `*** You must override %s in your class %s to define its base unit.` A subclass overrides it. |

The converter is copied through `NSCopying`, which `NSUnitConverter` implements
by returning the receiver; `NSUnitConverterLinear` does not implement it and
inherits that.

## The specifier

`_reserved` holds the private specifier, a number identifying the unit to the
unit formatter. Charon implements it under its own name because a unit archived
by the real Foundation carries it, and an archive that loses it is not the same
archive. The value per unit is in each dimension's own facts file.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.symbol` | inherited from `NSUnit` | inherited from `NSUnit` |
| `NS.specifier` | `-encodeInteger:forKey:` | `-decodeIntegerForKey:` |
| `NS.converter` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSUnitConverter class] forKey:` |

Decoding calls `[super initWithCoder:]` first and then re-initialises the
object through `-initWithSpecifier:symbol:converter:` with the symbol super
decoded. Non-keyed coders raise `NSInvalidArgumentException`:

- encoding: `NSDimension encoder does not allow non-keyed coding!`
- decoding: `NSDimension cannot be decoded by non-keyed archivers`

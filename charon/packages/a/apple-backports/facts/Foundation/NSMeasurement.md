# NSMeasurement

Introduced in iOS 10.0. A number and the unit it is in.

Source: the host's Foundation and the armv7s shared cache of iOS 10.0.1.

## Behaviour

| member | behaviour |
|---|---|
| `-initWithDoubleValue:unit:` | designated; the unit is copied. A receiver that is not an `NSUnit` raises `NSInvalidArgumentException`: `Must pass in an NSUnit object!` |
| `-copyWithZone:` | returns the receiver. |
| `-isEqual:` | the values are compared with `==` and the units with `-isEqual:`. 2 km is **not** equal to 2000 m: no conversion happens. |
| `-description` | `[super description]` with `" value: %f unit: %@"` appended, where the last argument is the unit's **symbol**, not the unit. |
| `+supportsSecureCoding` | `YES`. |

## Unit kinds

`-canBeConvertedToUnit:` answers whether two units are of one kind:

- both are dimensions: their kinds must be the same, where the kind of a unit is
  the ancestor of its class whose superclass is `NSDimension`. The walk matters
  because Foundation hands out units of private subclasses (`_NSStatic_NSUnitLength`),
  whose kind is still `NSUnitLength`.
- neither is a dimension: their classes must be the same. Two different plain
  `NSUnit` instances are therefore convertible to one another, even with
  different symbols.
- one is and the other is not: never.

## Conversion and arithmetic

`-measurementByConvertingToUnit:` converts through the base unit: the receiver's
converter to the base value, the target's converter back. A unit equal to the
receiver's is a straight copy of the value.

Addition and subtraction share one path, and the order of its tests is what
decides which complaint comes out:

1. the units are equal: the values are combined and the result keeps that unit.
2. the receiver's unit is not a dimension: raises `Cannot add differing units that are non-dimensional! lhs: %@ rhs: %@`.
3. the units are of different kinds: raises `Cannot add measurements of differing unit types! lhs: %@ rhs: %@`.
4. otherwise both are converted to the **base unit** of the dimension, combined
   there, and the result carries the base unit. 2 km + 500 m is 2500 m, not 2.5 km.

Subtraction raises the same texts with `subtract` in place of `add`. The
arguments are the **classes** of the two units, not the units.

Reversing tests 2 and 3 is wrong in a way only a differential test catches: a
plain unit added to metres complains about being non-dimensional, while metres
added to a plain unit complains about differing unit types.

`-measurementByConvertingToUnit:` raises
`Cannot convert measurements of differing unit types! self: %@ unit: %@`.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.value` | `-encodeDouble:forKey:` | `-decodeDoubleForKey:` |
| `NS.unit` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSUnit class] forKey:` |

A missing unit fails the decode with an `NSError` reading
`Unit class object has been corrupted!` rather than raising. Non-keyed coders
raise `NSInvalidArgumentException`; here both directions read
`NSMeasurement cannot be encoded by non-keyed archivers` and
`NSMeasurement cannot be decoded by non-keyed archivers`.

The ivars `_unit` and `_doubleValue` are declared `@private` by the SDK header.

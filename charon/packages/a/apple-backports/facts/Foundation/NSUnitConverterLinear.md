# NSUnitConverterLinear

Introduced in iOS 10.0. Converts by `y = ax + b`.

Source: the host's Foundation and the armv7s shared cache of iOS 10.0.1.

## Behaviour

| member | behaviour |
|---|---|
| `-initWithCoefficient:` | forwards to `-initWithCoefficient:constant:` with a constant of 0. |
| `-baseUnitValueFromValue:` | `coefficient * value + constant`. |
| `-valueFromBaseUnitValue:` | `(value + (-1 * constant)) / coefficient`. The SDK header states this form, and it is kept as written: the arithmetic is not reassociated, so the result is bit for bit the one Foundation gives. |
| `-isEqual:` | the coefficient and the constant are compared. |
| `-description` | `[super description]` with `" coefficient = %f, constant = %f"` appended. |
| `+supportsSecureCoding` | `YES`. |

Dividing by a coefficient of zero gives an infinity, as it does in Foundation.
Nothing guards it.

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.coefficient` | `-encodeDouble:forKey:` | `-decodeDoubleForKey:` |
| `NS.constant` | `-encodeDouble:forKey:` | `-decodeDoubleForKey:` |

Non-keyed coders raise `NSInvalidArgumentException`:

- encoding: `NSUnitConverterLinear encoder does not allow non-keyed coding!`
- decoding: `NSUnitConverterLinear cannot be decoded by non-keyed archivers`

The ivars `_coefficient` and `_constant` are declared `@private` by the SDK
header.

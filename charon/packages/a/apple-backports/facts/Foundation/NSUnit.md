# NSUnit

Introduced in iOS 10.0. A symbol and nothing else; the root of the unit classes.

Source: the host's Foundation, the newest implementation available, and the
armv7s shared cache of iOS 10.0.1 for the archive keys and the exception texts.
The two agree.

## Behaviour

| member | behaviour |
|---|---|
| `-init` | raises `NSGenericException`: `-init should never be called on NSUnit!` (11.0, `0x1816dae68`). 10.3.4 has no `-init` of its own and hands out a unit with no symbol; the later answer is carried. |
| `-initWithSymbol:` | designated; copies the symbol. |
| `-copyWithZone:` | returns the receiver. A unit is immutable. |
| `-isEqual:` | `[object isKindOfClass:[self class]]`, then the two classes must be the same, then the symbols are compared. 10.3.4 and 11.0 (`0x1816dafa8`) stop at the first test, so a plain `NSUnit` of symbol `m` equals `NSUnitLength.meters`; 18.0 (`0x181a04914`) and the host add the second, and it is carried. |
| `-description` | `[super description]` with `" %@"` of the symbol appended. |
| `+supportsSecureCoding` | `YES`. |

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `NS.symbol` | `-encodeObject:forKey:` | `-decodeObjectOfClass:[NSString class] forKey:` |

A symbol that is missing fails the coder rather than making a unit of none:
`-failWithError:` with `NSCocoaErrorDomain` 4865, `NSCoderValueNotFoundError`, and
no user info, and the answer is nil (10.3.4 `0x1b86ec1a`, and 11.0).

A coder that does not allow keyed coding raises `NSInvalidArgumentException`.
The two texts differ between the directions and are reproduced exactly:

- encoding: `NSUnit encoder does not allow non-keyed coding!`
- decoding: `NSUnit cannot be decoded by non-keyed archivers`

The ivar `_symbol` is declared `@private` by the SDK header, so Charon does not
declare it again.

# NSUnitAngle

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+degrees`.

Source of truth: the host's Foundation, the newest implementation available,
read through the public `coefficient` and `constant` of each unit's converter.
Cross-checked against the armv7s shared caches of iOS 10.0.1 and 10.3.4, which
agree with each other everywhere. Differences from iOS 10 are named below.

## Units

`specifier` is the private argument of `-[NSDimension initWithSpecifier:symbol:converter:]`,
stored in the `_reserved` ivar the SDK header declares and archived under `NS.specifier`.
A unit that ICU has no measure unit for carries none, and is built with
`-initWithSymbol:converter:`, which passes `NSUIntegerMax`.

| unit | symbol | converter | coefficient | constant | specifier |
|---|---|---|---|---|---|
| `degrees` | `°` | linear | 1 | 0 | 256 |
| `arcMinutes` | `ʹ` | linear | 0.016667 | 0 | 257 |
| `arcSeconds` | `ʺ` | linear | 0.00027778 | 0 | 258 |
| `radians` | `rad` | linear | 57.29577951308232 | 0 | 259 |
| `gradians` | `grad` | linear | 0.9 | 0 | — |
| `revolutions` | `rev` | linear | 360 | 0 | 260 |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `radians`: iOS 10 uses coefficient 57.2958, constant 0. The corrected value is used.

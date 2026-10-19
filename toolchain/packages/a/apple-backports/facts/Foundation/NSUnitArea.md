# NSUnitArea

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+squareMeters`.

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
| `squareMegameters` | `Mm²` | linear | 1000000000000 | 0 | — |
| `squareKilometers` | `km²` | linear | 1000000 | 0 | 513 |
| `squareMeters` | `m²` | linear | 1 | 0 | 512 |
| `squareCentimeters` | `cm²` | linear | 0.0001 | 0 | 518 |
| `squareMillimeters` | `mm²` | linear | 1e-06 | 0 | — |
| `squareMicrometers` | `µm²` | linear | 1e-12 | 0 | — |
| `squareNanometers` | `nm²` | linear | 1e-18 | 0 | — |
| `squareInches` | `in²` | linear | 0.00064516 | 0 | 519 |
| `squareFeet` | `ft²` | linear | 0.09290304 | 0 | 514 |
| `squareYards` | `yd²` | linear | 0.83612736 | 0 | 520 |
| `squareMiles` | `mi²` | linear | 2589988.110336 | 0 | 515 |
| `acres` | `ac` | linear | 4046.8564224 | 0 | 516 |
| `ares` | `a` | linear | 100 | 0 | — |
| `hectares` | `ha` | linear | 10000 | 0 | 517 |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `squareFeet`: iOS 10 uses coefficient 0.092903, constant 0. The corrected value is used.
- `squareYards`: iOS 10 uses coefficient 0.836127, constant 0. The corrected value is used.
- `squareMiles`: iOS 10 uses coefficient 2590000, constant 0. The corrected value is used.
- `acres`: iOS 10 uses coefficient 4046.86, constant 0. The corrected value is used.

# NSUnitMass

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+kilograms`.

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
| `kilograms` | `kg` | linear | 1 | 0 | 1537 |
| `grams` | `g` | linear | 0.001 | 0 | 1536 |
| `decigrams` | `dg` | linear | 0.0001 | 0 | — |
| `centigrams` | `cg` | linear | 1e-05 | 0 | — |
| `milligrams` | `mg` | linear | 1e-06 | 0 | 1542 |
| `micrograms` | `µg` | linear | 1e-09 | 0 | 1541 |
| `nanograms` | `ng` | linear | 1e-12 | 0 | — |
| `picograms` | `pg` | linear | 1e-15 | 0 | — |
| `ounces` | `oz` | linear | 0.0283495 | 0 | 1538 |
| `poundsMass` | `lb` | linear | 0.453592 | 0 | 1539 |
| `stones` | `st` | linear | 6.35029 | 0 | 1540 |
| `metricTons` | `t` | linear | 1000 | 0 | 1543 |
| `shortTons` | `ton` | linear | 907.185 | 0 | 1544 |
| `carats` | `ct` | linear | 0.0002 | 0 | 1545 |
| `ouncesTroy` | `oz t` | linear | 0.03110348 | 0 | 1546 |
| `slugs` | `slug` | linear | 14.5939 | 0 | — |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `stones`: iOS 10 uses coefficient 0.157473, constant 0. The corrected value is used.

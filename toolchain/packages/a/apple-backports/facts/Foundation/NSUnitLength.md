# NSUnitLength

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+meters`.

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
| `megameters` | `Mm` | linear | 1000000 | 0 | — |
| `kilometers` | `km` | linear | 1000 | 0 | 1282 |
| `hectometers` | `hm` | linear | 100 | 0 | — |
| `decameters` | `dam` | linear | 10 | 0 | — |
| `meters` | `m` | linear | 1 | 0 | 1280 |
| `decimeters` | `dm` | linear | 0.1 | 0 | 1290 |
| `centimeters` | `cm` | linear | 0.01 | 0 | 1281 |
| `millimeters` | `mm` | linear | 0.001 | 0 | 1283 |
| `micrometers` | `µm` | linear | 1e-06 | 0 | 1291 |
| `nanometers` | `nm` | linear | 1e-09 | 0 | 1292 |
| `picometers` | `pm` | linear | 1e-12 | 0 | 1284 |
| `inches` | `in` | linear | 0.0254 | 0 | 1286 |
| `feet` | `ft` | linear | 0.3048 | 0 | 1285 |
| `yards` | `yd` | linear | 0.9144 | 0 | 1288 |
| `miles` | `mi` | linear | 1609.344 | 0 | 1287 |
| `scandinavianMiles` | `smi` | linear | 10000 | 0 | 1298 |
| `lightyears` | `ly` | linear | 9460730472580800 | 0 | 1289 |
| `nauticalMiles` | `NM` | linear | 1852 | 0 | 1293 |
| `fathoms` | `ftm` | linear | 1.8288 | 0 | 1294 |
| `furlongs` | `fur` | linear | 201.168 | 0 | 1295 |
| `astronomicalUnits` | `ua` | linear | 149597870700 | 0 | 1296 |
| `parsecs` | `pc` | linear | 3.085677581491367e+16 | 0 | 1297 |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `miles`: iOS 10 uses coefficient 1609.34, constant 0. The corrected value is used.
- `lightyears`: iOS 10 uses coefficient 9461000000000000, constant 0. The corrected value is used.
- `astronomicalUnits`: iOS 10 uses coefficient 149600000000, constant 0. The corrected value is used.
- `parsecs`: iOS 10 uses coefficient 3.086e+16, constant 0. The corrected value is used.

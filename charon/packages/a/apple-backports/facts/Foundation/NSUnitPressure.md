# NSUnitPressure

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+newtonsPerMetersSquared`.

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
| `newtonsPerMetersSquared` | `N/m²` | linear | 1 | 0 | — |
| `gigapascals` | `GPa` | linear | 1000000000 | 0 | — |
| `megapascals` | `MPa` | linear | 1000000 | 0 | — |
| `kilopascals` | `kPa` | linear | 1000 | 0 | — |
| `hectopascals` | `hPa` | linear | 100 | 0 | 2048 |
| `inchesOfMercury` | `inHg` | linear | 3386.39 | 0 | 2049 |
| `bars` | `bar` | linear | 100000 | 0 | — |
| `millibars` | `mbar` | linear | 100 | 0 | 2050 |
| `millimetersOfMercury` | `mmHg` | linear | 133.322 | 0 | 2051 |
| `poundsForcePerSquareInch` | `psi` | linear | 6894.76 | 0 | 2052 |

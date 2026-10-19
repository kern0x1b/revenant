# NSUnitPower

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+watts`.

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
| `terawatts` | `TW` | linear | 1000000000000 | 0 | — |
| `gigawatts` | `GW` | linear | 1000000000 | 0 | 1797 |
| `megawatts` | `MW` | linear | 1000000 | 0 | 1796 |
| `kilowatts` | `kW` | linear | 1000 | 0 | 1793 |
| `watts` | `W` | linear | 1 | 0 | 1792 |
| `milliwatts` | `mW` | linear | 0.001 | 0 | 1795 |
| `microwatts` | `µW` | linear | 1e-06 | 0 | — |
| `nanowatts` | `nW` | linear | 1e-09 | 0 | — |
| `picowatts` | `pW` | linear | 1e-12 | 0 | — |
| `femtowatts` | `fW` | linear | 1e-15 | 0 | — |
| `horsepower` | `hp` | linear | 745.7 | 0 | 1794 |

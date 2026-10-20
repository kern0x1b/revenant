# NSUnitElectricPotentialDifference

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+volts`.

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
| `megavolts` | `MV` | linear | 1000000 | 0 | — |
| `kilovolts` | `kV` | linear | 1000 | 0 | — |
| `volts` | `V` | linear | 1 | 0 | 3843 |
| `millivolts` | `mV` | linear | 0.001 | 0 | — |
| `microvolts` | `µV` | linear | 1e-06 | 0 | — |

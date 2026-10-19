# NSUnitElectricResistance

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+ohms`.

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
| `megaohms` | `MΩ` | linear | 1000000 | 0 | — |
| `kiloohms` | `kΩ` | linear | 1000 | 0 | — |
| `ohms` | `Ω` | linear | 1 | 0 | 3842 |
| `milliohms` | `mΩ` | linear | 0.001 | 0 | — |
| `microohms` | `µΩ` | linear | 1e-06 | 0 | — |

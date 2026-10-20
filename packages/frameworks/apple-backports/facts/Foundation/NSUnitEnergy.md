# NSUnitEnergy

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+joules`.

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
| `kilojoules` | `kJ` | linear | 1000 | 0 | 3076 |
| `joules` | `J` | linear | 1 | 0 | 3074 |
| `kilocalories` | `kCal` | linear | 4184 | 0 | 3075 |
| `calories` | `cal` | linear | 4.184 | 0 | 3072 |
| `kilowattHours` | `kWh` | linear | 3600000 | 0 | 3077 |

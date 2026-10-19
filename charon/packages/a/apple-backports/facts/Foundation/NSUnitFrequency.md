# NSUnitFrequency

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+hertz`.

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
| `terahertz` | `THz` | linear | 1000000000000 | 0 | — |
| `gigahertz` | `GHz` | linear | 1000000000 | 0 | 4099 |
| `megahertz` | `MHz` | linear | 1000000 | 0 | 4098 |
| `kilohertz` | `kHz` | linear | 1000 | 0 | 4097 |
| `hertz` | `Hz` | linear | 1 | 0 | 4096 |
| `millihertz` | `mHz` | linear | 0.001 | 0 | — |
| `microhertz` | `µHz` | linear | 1e-06 | 0 | — |
| `nanohertz` | `nHz` | linear | 1e-09 | 0 | — |
| `framesPerSecond` | `fps` | linear | 1 | 0 | — |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `framesPerSecond` is in no iOS 10 cache at all, although the SDK marks it `ios(10.0)`; Apple annotated it after the fact. Its source is the host alone.

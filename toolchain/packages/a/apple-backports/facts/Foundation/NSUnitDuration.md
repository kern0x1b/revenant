# NSUnitDuration

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+seconds`.

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
| `hours` | `hr` | linear | 3600 | 0 | 1028 |
| `minutes` | `min` | linear | 60 | 0 | 1029 |
| `seconds` | `s` | linear | 1 | 0 | 1030 |
| `milliseconds` | `ms` | linear | 0.001 | 0 | — |
| `microseconds` | `µs` | linear | 1e-06 | 0 | — |
| `nanoseconds` | `ns` | linear | 1e-09 | 0 | — |
| `picoseconds` | `ps` | linear | 1e-12 | 0 | — |

## Differences from iOS 10

Charon takes the corrected numbers: a measurement asked for in stones is asked
for in stones, not in the defect Apple itself withdrew.

- `milliseconds` is in no iOS 10 cache at all, although the SDK marks it `ios(10.0)`; Apple annotated it after the fact. Its source is the host alone.
- `microseconds` is in no iOS 10 cache at all, although the SDK marks it `ios(10.0)`; Apple annotated it after the fact. Its source is the host alone.
- `nanoseconds` is in no iOS 10 cache at all, although the SDK marks it `ios(10.0)`; Apple annotated it after the fact. Its source is the host alone.
- `picoseconds` is in no iOS 10 cache at all, although the SDK marks it `ios(10.0)`; Apple annotated it after the fact. Its source is the host alone.

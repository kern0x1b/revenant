# NSUnitVolume

Introduced in iOS 10.0. A dimension: every unit of it converts to and from the
base unit, which is `+liters`.

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
| `megaliters` | `ML` | linear | 1000000 | 0 | 2823 |
| `kiloliters` | `kL` | linear | 1000 | 0 | — |
| `liters` | `L` | linear | 1 | 0 | 2816 |
| `deciliters` | `dL` | linear | 0.1 | 0 | 2821 |
| `centiliters` | `cL` | linear | 0.01 | 0 | 2820 |
| `milliliters` | `mL` | linear | 0.001 | 0 | 2819 |
| `cubicKilometers` | `km³` | linear | 1000000000000 | 0 | 2817 |
| `cubicMeters` | `m³` | linear | 1000 | 0 | 2825 |
| `cubicDecimeters` | `dm³` | linear | 1 | 0 | — |
| `cubicCentimeters` | `cm³` | linear | 0.001 | 0 | 2824 |
| `cubicMillimeters` | `mm³` | linear | 1e-06 | 0 | 2824 |
| `cubicInches` | `in³` | linear | 0.0163871 | 0 | 2826 |
| `cubicFeet` | `ft³` | linear | 28.3168 | 0 | 2827 |
| `cubicYards` | `yd³` | linear | 764.555 | 0 | 2828 |
| `cubicMiles` | `mi³` | linear | 4168000000000 | 0 | 2818 |
| `acreFeet` | `af` | linear | 1233000 | 0 | 2829 |
| `bushels` | `bsh` | linear | 35.2391 | 0 | 2830 |
| `teaspoons` | `tsp` | linear | 0.00492892 | 0 | 2831 |
| `tablespoons` | `tbsp` | linear | 0.0147868 | 0 | 2832 |
| `fluidOunces` | `fl oz` | linear | 0.0295735 | 0 | 2833 |
| `cups` | `cup` | linear | 0.24 | 0 | 2834 |
| `pints` | `pt` | linear | 0.473176 | 0 | 2835 |
| `quarts` | `qt` | linear | 0.946353 | 0 | 2836 |
| `gallons` | `gal` | linear | 3.78541 | 0 | 2837 |
| `imperialTeaspoons` | `tsp` | linear | 0.00591939 | 0 | 2831 |
| `imperialTablespoons` | `tbsp` | linear | 0.0177582 | 0 | 2832 |
| `imperialFluidOunces` | `fl oz` | linear | 0.0284131 | 0 | 2833 |
| `imperialPints` | `pt` | linear | 0.568261 | 0 | 2835 |
| `imperialQuarts` | `qt` | linear | 1.13652 | 0 | 2836 |
| `imperialGallons` | `gal` | linear | 4.54609 | 0 | 2840 |
| `metricCups` | `metric cup` | linear | 0.25 | 0 | 2838 |

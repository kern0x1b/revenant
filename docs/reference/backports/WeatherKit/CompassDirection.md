# Wind.CompassDirection, measured

What `frameworks/Backports/src/WeatherKit/Wind.swift` carries of `Wind`, and what it was checked against. The numbers
come from the commands named here, run on 2026-10-17 from the `v-impl-swift-apps-r3` worktree.

## What is carried

The spec rows are `the deleted registry package spec/WeatherKit/swift.tsv`, the `Wind.CompassDirection`
container: 25 rows (the enum row, 16 cases, `abbreviation`, `description`, `accessibilityDescription`,
`init(rawValue:)`, `AllCases`, `RawValue`, `allCases` and `rawValue`).

All 25 are in the file. The conformances the host shows (below) are carried too.

`Wind` itself is declared in the file as the container the nested type needs, with no members. Its
own rows are open: `direction`, `speed`, `gust` and `compassDirection` (each a
`Foundation.Measurement`, or `Wind.CompassDirection`), `==`, `encode(to:)` and `init(from:)`. The
`Wind` struct row is therefore closed by declaration only, and nothing in the file can read a wind.

## Measured against the host

The oracle is the host's WeatherKit, read through `frameworks/Backports/tests/SwiftRuntime/WeatherKit/compass/main.swift`, built twice:
`swiftc -O main.swift` against the host, and `swiftc -DOURS -O main.swift files/WeatherKit/Wind.swift`.

- Host: macOS 27, Swift 6.4, locale en_US.
- The 16 cases, their descriptions and abbreviations match the host one line each (for example
  `northNortheast` is `North Northeast` and `NNE`).
- The raw value of each case is its case name, not its abbreviation: `eastSoutheast`. So
  `init(rawValue: "N")` is nil on both, and `init(rawValue: "north")` is `north` on both.
- `accessibilityDescription` equals `description` for every case on the host (`true`), so the file
  returns the description.
- The host type is `Codable`, `Hashable` and `Sendable`; so is the file. `AllCases` and `RawValue`
  are `[Wind.CompassDirection]` and `String` on both.
- The string interpolation of a case is its description on both.
- Result: 23 lines, identical, `diff` exits 0.

## armv7

`swiftc -target armv7-apple-ios6.1.3 -sdk iPhoneOS16.4.sdk -resource-dir <scratch>
-parse-as-library -typecheck files/WeatherKit/Wind.swift` exits 0, no diagnostics. The object,
`-wmo -O -module-name WeatherKit -c`, is a Mach-O `arm_v7` file of 16916 bytes with 71 defined
symbols (`llvm-nm -g --defined-only`). The resource directory is the run-folder symlink farm over the
runtime's `lib/swift`, with the toolchain's `legacy_layouts/iphoneos/layouts-armv7.yaml` beside it.

## Not measured

- The object was not linked and not run on an armv7 image.
- `Wind`'s members, which need `Foundation.Measurement` and the `UnitSpeed` and `UnitAngle` units. Not
  checked whether iOS 6.1.3's Foundation carries them.
- Locales other than en-US.

# WeatherCondition, measured

What `frameworks/Backports/src/WeatherKit/WeatherCondition.swift` carries and what it was checked against. The
numbers come from the commands named here, run on 2026-10-16 from the `v-impl-swift-apps` worktree.

## What is carried

The spec rows are `the deleted registry package spec/WeatherKit/swift.tsv`, the WeatherCondition
container: 41 rows (34 cases, `init(rawValue:)`, `description`, `accessibilityDescription`,
`allCases`, `rawValue`, and the two typealiases `AllCases` and `RawValue`).

All 41 are in the file. The conformances the host shows (below) are carried too: the spec does not
list conformances, so they are there because the host has them.

## Measured against the host

The oracle is the host's WeatherKit, read through `frameworks/Backports/tests/SwiftRuntime/WeatherKit/main.swift`. It is built twice:
`swiftc -O main.swift` against the host, and `swiftc -DOURS -O main.swift files/WeatherKit/WeatherCondition.swift`.

- Host: macOS 27, Swift 6.4. Locale at run time: `AppleLocale` en_US, `AppleLanguages` en-US first.
  The descriptions are the host's English strings; other locales are not measured and not carried.
- The 34 cases, their raw values and their descriptions match the host one line each. The raw value
  of every case is its case name (`blowingDust`, not `Dust`). `"\(c)"` is the description on the host,
  so the type conforms to `CustomStringConvertible`; the first version of the file did not, and the
  differential showed it on two lines: `string-interpolation`, and `condition.init`, which prints the
  case through the same interpolation.
- `accessibilityDescription` equals `description.lowercased()` for every case on the host
  (`lowercase-rule true`), so the file derives it that way.
- The host type is `Codable`, `Hashable` and `Sendable`; so is the file. `JSONEncoder` writes
  `"hurricane"` for `.hurricane` on both, and the decode returns `hurricane` on both.
- `WeatherCondition(rawValue: "noSuch")` is nil on both; `(rawValue: "clear")` is `.clear` on both.
- Result: 41 lines, identical, `diff` exits 0.

## armv7

`swiftc -target armv7-apple-ios6.1.3 -sdk iPhoneOS16.4.sdk -resource-dir <scratch>
-vfsoverlay <swift-runtime 1b938f...>/share/lift/vfs.yaml -parse-as-library -wmo -O -module-name WeatherKit -c`
writes a Mach-O `arm_v7` object of 18720 bytes with 65 exported symbols. The resource directory is a
run-folder symlink farm over the runtime's `lib/swift`, with the toolchain's
`legacy_layouts/iphoneos/layouts-armv7.yaml` beside it: the runtime install does not carry that file,
and without it the compiler stops with `Cannot read legacy layout file`.

## Not measured

- The object was not linked and not run on an armv7 image.
- `Wind.CompassDirection` is not in this file: it is a member of `Wind`, a struct whose other members
  belong to the Wind group. Its 25 rows wait for that group.
- Locales other than en-US.

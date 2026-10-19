# WidgetKit value types, measured

What `files/WidgetKit/Values.swift` carries, what it was checked against, and where each value comes
from. Measured on 2026-10-17 from the `v-impl-appintents` worktree of charon.

## What is carried

Spec rows: `packages/a/apple-backports/spec/WidgetKit/swift.tsv` (the containers below) and
`swiftinterface.tsv` (the declaration order of the 26.2 SDK's cases, and which are unavailable on iOS).

| Type | Rows | Source of the shape |
| --- | --- | --- |
| `TimelineEntryRelevance` (score, duration, Codable, Hashable) | 9 | swift.tsv |
| `TimelineEntry` (date, relevance with a nil default) | 4 | swift.tsv |
| `Timeline<EntryType>` (entries, policy, init) | 4 | swift.tsv |
| `TimelineReloadPolicy` (atEnd, never, after(_:), ==) | 5 | swift.tsv |
| `WidgetRenderingMode` (fullColor, accented, vibrant, description, ==) | 6 | swift.tsv |
| `WidgetAccentedRenderingMode` (4 cases, ==, Hashable) | 8 | swift.tsv |
| `WidgetFamily` (9 cases, rawValue, init(rawValue:), RawValue) | 13 | swift.tsv and swiftinterface.tsv |
| `LevelOfDetail` (default, simplified, ==) | 4 | swift.tsv and swiftinterface.tsv |
| `WidgetLocation` (7 cases, ==, Hashable) | 9 | swift.tsv and swiftinterface.tsv |
| `WidgetMountingStyle` (elevated, recessed, Hashable) | 6 | swift.tsv and swiftinterface.tsv |

68 rows in all. 45 of them are named in the file. The other 23 are carried without a verbatim name:
the explicit initialisers and `after(_:)`, and the members the conformances synthesise (`==`,
`hash(into:)`, `hashValue`, `init(from:)`, `encode(to:)`, `init(rawValue:)`, `rawValue`, `RawValue`).

Not carried: `WidgetRelevance`, `WidgetRelevanceAttribute`, `WidgetRelevanceGroup`, `WidgetInfo`,
`TimelineProvider` and the other protocols that name AppIntents or Intents types. They belong to the
AppIntents and Intents groups, not to this file.

## WidgetFamily raw values

The raw value of a case is its position in the 26.2 SDK's declaration order, counting from 0. The
interface table lists the cases in that order:

    systemSmall 0, systemMedium 1, systemLarge 2, systemExtraLarge 3, systemExtraLargePortrait 4,
    accessoryCorner 5, accessoryCircular 6, accessoryRectangular 7, accessoryInline 8

Two sources, and they agree as far as they reach:

- The macOS host gives 0 to 4: `systemSmall` through `systemExtraLargePortrait`, the probe's
  `family-raw` lines. Identical to the file.
- The host has no case from 5: `WidgetFamily(rawValue: n)` is nil for n = 5 to 12. So 5 to 8 are
  not measured. They are the declaration order's values, and an inference from the IR's order.
  Per the ruling for this band, that is the source.

The macOS host does not have the accessory cases, so no host value can confirm 5 to 8.

## Measured against the host

The oracle is the macOS host's WidgetKit (macOS 27, Swift 6.4). The probe is
`harness/WidgetKit/values/main.swift`, built twice: `swiftc -O main.swift` against the host, and
`swiftc -DOURS -O main.swift files/WidgetKit/Values.swift` against the file. Both runs print 26
lines, and they are identical (`diff` exits 0).

| Probe | Result |
| --- | --- |
| The four small and large families: case name, rawValue, description, debugDescription | identical |
| `WidgetFamily(rawValue:)` for -1 to 4 | identical (4 is `systemExtraLargePortrait`) |
| `WidgetRenderingMode` cases and `description` | identical (`fullColor`, `accented`, `vibrant`) |
| `WidgetRenderingMode` ==, `WidgetAccentedRenderingMode` ==, and its Set count (4) | identical |
| `TimelineReloadPolicy` ==, `after(_:)` with the same and a different date | identical |
| `Timeline` entries count, dates, policy; an empty timeline | identical |
| `TimelineEntry` default `relevance` is nil | identical (true) |
| `TimelineEntryRelevance` JSON with sorted keys: `{"duration":60,"score":0.5}` | identical |
| JSON round trip, ==, Set count | identical |

### Planted control

A copy of the file with `WidgetRenderingMode.description` changed to append an `x` was built and
diffed against the host output. The diff shows the three `rendering` lines and the `rendering-equal`
line. The probe sees a changed description.

## Not measured by the host

Three types are unavailable on the macOS host: `LevelOfDetail`, `WidgetLocation`, `WidgetMountingStyle`
(`'X' is unavailable in macOS`, the host's own error). They cannot go in the differential. Their
values come from the 26.2 declarations and the contract. `harness/WidgetKit/contract/main.swift` is
built against the file only, and it prints:

    family-raw-accessory accessoryCorner accessoryCircular accessoryRectangular accessoryInline
    family-raw-9 nil
    family-accessory-raw 5 6 7 8
    detail true false
    location-equal (identity matrix of 7)
    location-set 7
    mounting true false 2

These lines are the contract's, not the host's. They check the file against its own declaration order
and equality, and they are the only evidence for those three types in this group.

`WidgetLocation.watchFace` and `smartStack` are declared unavailable on iOS in the interface table
(the `yes` marks). The file carries them, so the shape is complete and an app that uses them is refused
by the SDK at compile time, as on a device.

## Method note

The first build of the file made `WidgetFamily.description` interpolate `self` under a
`CustomStringConvertible` conformance. The description called itself, and the probe died with exit
139 before printing anything. The conformance is removed; the description is a plain property, and
the interpolation prints the case name. The probe now prints 26 lines, identical to the host.

## armv7

Toolchain: charon@swift 6.4.0. SDK: iPhoneOS16.4 from the `iphoneos-sdk` 16.4 package. Runtime
resource: the same run-folder farm as the AuthenticationServices error group, over the installed
swift-runtime 6.4.0 variant named in the CKError facts.

- Typecheck: `swiftc -target armv7-apple-ios6.1.3 -sdk <iPhoneOS16.4.sdk> -resource-dir <farm>
  -vfsoverlay <variant>/share/lift/vfs.yaml -parse-as-library -typecheck files/WidgetKit/Values.swift`
  exits 0.
- Object: the same flags with `-wmo -O -module-name WidgetKit -c`. A Mach-O `arm_v7` object of 62444
  bytes with 274 defined global symbols.

## Against the generated skeleton

`swiftcode` rendered WidgetKit's skeleton (395 declarations, `tools/gen.lua swiftcode`, 26.2 SDK). The file
was checked against it:

- Conformances: the skeleton gives `WidgetFamily` Int, CustomDebugStringConvertible,
  CustomStringConvertible, Equatable, Hashable, RawRepresentable and Sendable; `WidgetRenderingMode`
  CustomStringConvertible and Equatable; `WidgetLocation` and `WidgetMountingStyle` Equatable, Hashable
  and Sendable; `TimelineEntryRelevance` Decodable, Encodable, Equatable and Hashable. The file has each of
  these. Two were missing before this check (the description conformances, and `Sendable` on the two
  placement types) and are added.
- Cases: the skeleton lists seven `WidgetFamily` cases, the iOS-available ones. The renderer omits the two
  the interface table marks unavailable on iOS (`systemExtraLargePortrait`, `accessoryCorner`). The file
  has all nine. The raw values count those two, because a Swift enum's raw values count every declared
  case, available or not; that is why `accessoryCircular` is 6 and not 4. This is the one place the
  skeleton and the file differ on purpose, and the reason is the rule above, not a host measurement.
- Members: the skeleton's names and types match the file's for the ten containers, with one difference:
  the skeleton lists five `WidgetLocation` statics and omits `watchFace` and `smartStack`, which the
  interface table marks unavailable on iOS. The file carries them, by the same rule as the two
  `WidgetFamily` cases above.

## Not measured

- The object was not linked and not run on an armv7 image, the emulator or a 4S.
- The accessory raw values against an iOS 26.2 runtime (see above).
- The recipe does not name `files/WidgetKit`. Wiring waits for the swift-runtime install, which is
  blocked on the lift's measured set.

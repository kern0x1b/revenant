---
name: project
description: Lay out the app's project for Charon and xmake — the directory, the app target in xmake.lua (the app rule and the values it reads, apple_minimum and architectures, frameworks, -fobjc-arc on compile and link), Info.plist written by hand with CFBundleIdentifier, icons and launch images as plain PNG resources (no asset catalogs, nibs or storyboards), and the lock files to commit. Use after install and firmware, before writing code, whenever xmake.lua or Info.plist is created or changed, or when asked how an old-iOS app project is structured, which release an architecture needs, or why an icon or bundle identifier is missing.
---

# The project: xmake.lua, Info.plist, resources

Write every file for this app from `PROJECT.md`; nothing here is a template to copy. The skill
`install` already wrote the project-wide lines of `xmake.lua` (the pin, `apple_minimum`, the
`apple-ios` include, the default platform and architecture). This step adds the app target, the
`Info.plist`, the resources, and checks that the project configures.

## 1. The directory

At the project root: `xmake.lua`, `Info.plist`, `PROJECT.md`, a folder of sources (e.g. `src/`),
a folder of resources copied into the bundle (e.g. `resources/`), `.logs/` for run output.
xmake writes `build/` and `.xmake/`; neither is source. If the project is a git repository,
ignore `build/`, `.xmake/` and `.logs/`, and commit `xmake-requires.lock` and `xmake-addons.lock`.

## 2. Release and architectures

`apple_minimum` is the lowest release the app runs on; it decides the architectures, and Charon
refuses a pair that no device runs:

| Architecture | Releases | Devices |
| --- | --- | --- |
| armv6 | 2.0 – 4.2.1 | original iPhone, 3G, iPod touch 1–2 |
| armv7 | 3.0 and later | 3GS, 4, 4S, iPad 1–2, iPod touch 3–4, and every later 32-bit device |
| armv7s | 6.0 and later | iPhone 5, 5c, iPad 4 |
| arm64 | 7.0 and later | 64-bit devices |

- One architecture: the default set by `install` (`set_defaultarchs("iphoneos|armv7")`) is
  enough, or configure it explicitly with `xmake f -p iphoneos -a armv7 -y`.
- An app for armv7 on iOS 6 and arm64 devices: add
  `add_values("apple.architectures", "armv7", "arm64")` to the target and keep `armv7` as the
  configured one. `xmake deb` then builds the arm64 slice for 7.0 beside armv7 at 6.0 and merges
  them; write `MinimumOSVersion` into `Info.plist` yourself, because every other file must be the
  same in both slices. The import check reads 7.0 for arm64 (skill `firmware`). Charon documents
  this path, but it is not verified end to end: treat its first `xmake deb` as the test and
  read that log closely.

## 3. The app target

Add one target to `xmake.lua`, named after the app. Its name is the executable's, the bundle's
(`<Name>.app`) and, unless `Info.plist` says otherwise, `CFBundleName` and `CFBundleDisplayName`.
Write these lines yourself, one decision each:

- the rule that makes a bundle: `add_rules("@addon/charon/app")`;
- the sources, e.g. `add_files("src/*.m")` (and `.c`, `.mm` as the app has them);
- the frameworks the code uses, e.g. `add_frameworks("UIKit", "Foundation", "CoreGraphics")`;
  a framework the lowest release does not have links against the SDK and is then refused by the
  import check, which is the truth about the release;
- ARC for Objective-C, **on compile and on link**:
  ```lua
  add_mflags("-fobjc-arc")
  add_ldflags("-fobjc-arc")
  ```
  (`add_mxflags` too for `.mm`). The link flag makes clang force-load Charon's arclite, which
  carries what older releases lack (the ARC entry points below 5.0, collection subscripting
  below 6.0). An iOS 6.0 app links green without it, which is why it is easy to lose; a lower
  release then refuses the build (below 5.0) or lacks the collection subscripts (5.x). Keep both
  from the start (the skill `objc` says what each release needs);
- the property list: `set_values("app.plist-file", "Info.plist")`;
- the resources: `set_values("app.resources", "resources")`. Each named folder's contents are
  copied flat into the bundle; a named file is copied as is;
- optional: `add_values("app.plist", "KEY=VALUE")` overrides one string key over the file;
  `set_values("app.url-scheme", "<scheme>")` registers one URL scheme and replaces any
  `CFBundleURLTypes` the plist has (write the key yourself for more than one); `app.frameworks`
  bundles into `Frameworks/` a shared-library target of the project or a package the target adds,
  by the name the target knows it by.

A Swift target adds Charon's `swift` rule and the Swift runtime packages (skill `xmake-swift`), and
`charon@styx` for Combine (skill `combine`); the code is the skill `swift`. The package control file
and maintainer are the skill `package`'s.

## 4. Info.plist

Write it by hand as an XML property list. Charon fills in only what is missing among
`CFBundleName`, `CFBundleDisplayName`, `CFBundleExecutable`, `CFBundleVersion`,
`CFBundleShortVersionString` (both from `set_version`) and `MinimumOSVersion` (from
`apple_minimum`). Everything else is yours:

- `CFBundleIdentifier` — the bundle identifier from `PROJECT.md`. **Charon neither derives nor
  requires it**: a plist without one builds green, and the app has no identity on the device.
- `CFBundleDisplayName` — the name under the icon, if not the target's name.
- `CFBundlePackageType` = `APPL`.
- `CFBundleIconFiles` — an array naming the icon PNGs (step 5).
- `UIRequiredDeviceCapabilities` — an array, e.g. `armv7`.
- `UISupportedInterfaceOrientations` (and `UISupportedInterfaceOrientations~ipad`).
- `UIDeviceFamily` — an array of integers, `1` iPhone/iPod, `2` iPad; Xcode used to add it, here
  you do. Without `2`, an iPad runs the app in the iPhone-sized compatibility window.
- The keys the app's features need (URL types, background modes, status bar style, …).

Do not write `CFBundleExecutable` unless it equals the target name (the build refuses a mismatch).
Leave `MinimumOSVersion` to Charon except for a universal app (step 2).

How to know it worked: `plutil -lint Info.plist` prints `Info.plist: OK`.

## 5. Icons and launch images

There is no asset catalog compiler (actool) and no nib or storyboard compiler (ibtool) in this
toolchain: icons and launch images are plain PNG files in the resources folder, and the
interface is built in code. The user supplies the icon, or you draw one (never Apple artwork).
Sizes by the device's convention:

- iPhone/iPod on iOS 6 and earlier: `Icon.png` 57×57, `Icon@2x.png` 114×114 (Retina: iPhone 4,
  4S, iPod touch 4); iPad: `Icon-72.png` 72×72 (`Icon-72@2x.png` 144×144). An app for iOS 7 and
  later adds 60×60/120×120 (iPhone) and 76×76/152×152 (iPad). List every file in
  `CFBundleIconFiles`.
- Launch images: `Default.png` 320×480, `Default@2x.png` 640×960, and `Default-568h@2x.png`
  640×1136, which also tells iOS 6 the app fills the iPhone 5's taller screen.

Resize a large PNG with macOS's own `sips`:

```
sips -z 114 114 icon-large.png --out resources/Icon@2x.png
```

How to know it worked: `file resources/*.png` names each as `PNG image data, W x H`. Whether
SpringBoard shows the icon is only seen on a device: the emulator cannot launch an app through
SpringBoard yet (skill `emulate`).

## 6. Configure and look at the target

```
xmake f -y > .logs/configure.log 2>&1
xmake show -t <Name>
```

How to know it worked: the configure log has no `error:`; `xmake show -t <Name>` lists
`@addon/charon/app` under `rules`, `-fobjc-arc` under both `mflags` and `ldflags`, the
frameworks, and the files. The linker line it prints carries `-miphoneos-version-min=<release>`.

Refusals that show here or at the first `xmake` (the architecture check runs when the target
loads for a build), and what they mean:

- `target(<Name>) builds for apple-ios and its project names no oldest release` → the
  `set_config("apple_minimum", …)` line is missing or after the include.
- `target(<Name>) builds for apple-ios without includes("@addon/charon/apple-ios")` → the include
  is missing.
- `apple_minimum <r> is older than <first>, the first release an <arch> device runs; …` or
  `… is newer than 4.2.1, the last release an armv6 device runs` → the architecture and release
  disagree; go back to `PROJECT.md`, do not pick another pair silently.

## 7. Record it

In `PROJECT.md` under `## Progress`, the project line: the target name, release and
architectures, `plutil -lint` OK, the `xmake show` check, `.logs/configure.log`.

Then write the code (skill `objc` for Objective-C, `swift` for Swift), and build with the skill `build`.

## Traps

- `-fobjc-arc` only in `add_mflags` → also `add_ldflags`. Reason: arclite is force-loaded at the
  link only when the link itself has the flag; at 6.0 nothing complains, below it the release
  lacks what arclite would have carried.
- A storyboard, `.xib` or `Assets.xcassets` in the project → build the interface in code and ship
  PNGs. Reason: nothing here compiles them; they would be copied raw and never read.
- No `CFBundleIdentifier` because "the build passed" → write it. Reason: Charon does not check it.
- `CFBundleExecutable` different from the target name → drop it or match it. Reason: the build
  refuses a bundle whose plist names another executable.
- Copying an Xcode project's `Info.plist` with `$(PRODUCT_BUNDLE_IDENTIFIER)` or
  `$(EXECUTABLE_NAME)` → write literal values. Reason: nothing expands Xcode's build variables.
- `add_rules("@addon/charon/app")` on a target whose project lacks the `apple-ios` include, or the
  include before `set_config("apple_minimum", …)` → keep the order the skill `install` wrote.
- A project folder nested inside another checkout → run `xmake -P .` from it. Reason: the rules
  refuse to build a checkout nested inside another xmake project, which would lock the outer one.

---
name: backports
description: Use API that later iOS releases added (UIStackView, layout anchors, UIAlertController, NSURLSession, NSURLComponents, UNUserNotificationCenter, WKWebView, Core Data's persistent container and more) in an app for an older release through the `frameworks/Backports` targets - decide per API between a backport, the release's own older API and a change of design, and say which backport library an app depends on. Use it when an app or a port calls a member the target release lacks, when a member is reported missing or unimplemented, or when a Backports library must be added to a target.
---

# Backports

The SDK the toolchain compiles against is a modern one, so its headers declare API the target release
does not have. What the device exports is decided by that release's own libraries. A member the release
lacks is implemented in `frameworks/Backports/src/<Framework>`, and each framework is one shared library,
`lib<Name>Backports.dylib`, whose target is named `<Name>Backports` in `frameworks/Backports/xmake.lua`.

For each API the app needs after `apple_minimum`, there are three answers. Pick one per API:

1. **A backport**: the app calls the modern API and depends on the target that implements it.
2. **The release's own older API**: the app calls what the release has, behind `#available` or a version check.
3. **A change of design**: the app stops needing the API.

## 1. Look the member up

- The sources: `frameworks/Backports/src/<Framework>/`. A member the sources do not implement is
  reported by the skeleton the generator writes, which fails with the member's name when it is called,
  for example `not implemented: -[NSUUID UUIDString]`.
- The specs: `docs/reference/backports/<Framework>/`, clean-room text written from Apple's documentation
  and measurements. Read the spec before writing an implementation; do not read Apple's headers into it.
- The generator: `./xmakew l -P . frameworks/Backports/tools/generate.lua` writes the facts and the
  skeleton into the build folder. It is never committed.

## 2. Choose the target

The target is the framework's library: `FoundationBackports`, `UIKitBackports`, `CoreDataBackports`, and
so on, listed with the frameworks it weakly imports and the other Backports it depends on in
`frameworks/Backports/xmake.lua`. The component option `--component=Backports` configures only this
component and what it needs.

## 3. Depend on it

Inside the project, a target that needs a library adds it with `add_deps`:

```lua
target("MyPort")
    add_deps("UIKitBackports", "CoreDataBackports")
```

A target that depends on a Backports library reads its build products from its dependency closure, and
packaging does not yet install them (see the last step). An application outside this repository has no
package to require: it cannot depend on these targets through `revenant@...` yet.

## 4. Write the code

- Call the modern API the way the SDK declares it. A backport answers only the members it implements;
  the rest fail with their names, so an unimplemented call is visible and not silently absent.
- The system's own implementation wins where it exists: Objective-C classes resolve through the class
  alias, and C and Swift symbols through a forwarder. Write code that is correct on both.

## 5. Read the build

- `frameworks/Backports/tools/status.lua` prints `implemented X of Y` per framework after a build.
- `frameworks/Backports/tools/exports.lua` checks every key of the objects against the built libraries,
  and lists the keys no library exports (missing) and those two or more export (duplicated).

## 6. What packaging needs

The one `.deb` of the repository that installs the libraries under `/usr/lib/revenant/` is not written
yet. A target that links a Backports library cannot be packaged: `platform.lua` refuses it and names
the target, so nothing is shipped that would fail on the device. The design and what is measured are in
[the backports loading note](../../../docs/explanation/backports-loading.md).

## Traps

- A class is one proxy under its name `Revenant<X>`; no two classes share a name. Do not register a
  class under a system name from a backport.
- A Swift member is counted, not implemented: Swift overlays live beside their framework in `src` and
  are compiled by the Swift packages, not by the Backports targets.

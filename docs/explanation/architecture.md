# Architecture

revenant has three layers. Every top-level folder belongs to one of them, and every piece of code belongs to exactly one.

## The three layers

**Components** are our code. Each component is a folder with its own `xmake.lua`, which defines its targets and its tests: `emulator/`, `recompiler/`, `frameworks/<Framework>` (Backports, Combine, SwiftUI, WebKit), `agent-skills/`, and the `src/` of `toolchain/`. A component builds its own sources and uses another component only through the build graph: `add_deps` for a target of the same checkout, or `add_packages` for a package. It never reaches into another component's folder by a path.

**The package repository** holds external code and nothing else. A package is `packages/<letter>/<name>/`: the upstream by url and version or commit, our changes as `patches/` applied in order, and the build glue of an upstream that has no build files of its own (`port/`). The toolchain's inputs are packages too: llvm, swift, the iPhoneOS SDK, ld64 and the rest. `addons/<letter>/<name>/` is the one recipe that installs the addon itself.

**The addon and the toolchain** are `toolchain/`, the xmake addon `revenant`. It holds the `apple-ios` toolchain, the rules that build an app, a daemon, a tweak, a library or Swift code, the checks that run against a built binary, and the `deb` and `emulate` plugins. Stock xmake installs it from `addons/r/revenant/xmake.lua`, which pins a commit; inside the checkout `./xmakew` takes it from `toolchain/` directly.

## What each top-level folder is

| Folder | Layer | What it holds |
| --- | --- | --- |
| `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md` | | the documents of the repository |
| `LICENSES/`, `REUSE.toml` | | every licence text once, and which paths each covers |
| `xmake.lua`, `xmakew` | | the one build graph, and the pinned xmake that runs it |
| `tools/` | | the repository's Lua tools: layout, keys, comments, clean, publish |
| `docs/` | | all documentation, by kind and then by component |
| `emulator/`, `recompiler/`, `frameworks/`, `agent-skills/` | components | our code |
| `toolchain/` | addon | the addon `revenant`, and the `src/` of the tools and shims it builds |
| `packages/` | package repository | external code, by letter and name |
| `addons/` | package repository | the recipe that installs the addon |

## How it fits together

```
  components (our code)     emulator/  recompiler/  frameworks/*  toolchain/src/*
        |                   each folder: xmake.lua defines its targets
        |  add_deps (a target of this checkout)
        |  add_packages (a package, by name)
        v
  package repository        packages/<l>/<name>/   url + commit, patches/, port/
  (external code)           addons/<l>/<name>/     the addon's recipe
        |
        |  add_requires("revenant@<name>")
        v
  addon and toolchain       toolchain/: apple-ios toolchain, rules, checks, plugins
```

## How an outside project gets our libraries

An app built by a project outside this checkout takes our libraries in two ways, and each one is standard xmake.

1. **The addon**, which supplies the toolchain and the rules (`includes("@addon/revenant/apple-ios")`, `add_rules("@addon/revenant/app")`). It is stock xmake's `add_addons("revenant ...")`, from the pinned commit in `addons/r/revenant/xmake.lua`.
2. **The packages of our components**, which the checkout writes with `xmake package`. The package action builds each target and writes a package per target into `<dir>/packages/<letter>/<name>/`, with an `xmake.lua` whose `on_fetch` returns the libraries, the link directories and the include directories. The outside project names that directory as a repository and requires the package. This is the shape; the package names are the target names in lower case:

```lua
add_repositories("revenant <checkout>")
add_repositories("built <dir>")
add_addons("revenant ...")
add_requires("swiftui")
add_packages("swiftui")
```

`<checkout>` supplies the external packages the outside project also needs (the Swift runtime, libc++, the SDK), and `<dir>` supplies the packages generated from our targets. The mechanism was checked on a host library: a package generated with `./xmakew package -P . -o <dir>` was built and run by a separate project that named `<dir>` as its repository. The iOS route is not yet checked; see the status below.

The Backports libraries come as one package, `org.revenant.backports`, which `./xmakew deb -P .` writes; see [decision 0012](decisions/0012-one-backports-package.md).

Why packages and not a copy of our sources: a package names one target and its links, so an outside project takes exactly what the target builds, and the same target serves the checkout and every outside project.

## What is a target and what is a package now

Our code is a target of its component, and the component's `xmake.lua` defines it:

- `frameworks/SwiftUI`: the `SwiftUI` target, which takes Combine from the package.
- `frameworks/Combine`: the test targets only. The module is the package `combine`.
- `frameworks/Backports`: the Objective-C libraries, `RevenantCoding`, the wrapper `RevenantCKWebAuth` and the tweak `revenant-callkit-screen`.

External code stays a package: `combine` (OpenCombine with our patches in `patches/`), `micro-ecc` (the upstream library, unmodified), and the rest of `packages/`.

A package of our own code is allowed only as a **thin wrapper**: a recipe with no url, whose `on_install` generates a project that includes one component and installs that component's targets, and that holds no sources and no build logic of its own. `emulator`, `emulator-guest` and `firmware-tools` are wrappers of this kind, and the addon's rules and plugins take them by name, as they take any package. The layout check (`tools/layout.lua`) enforces it: a recipe with no url must be a wrapper or be listed in `UNCONVERTED`.

The rules behind this layout are short records, each with the check that enforces it: [the decisions](decisions/README.md).

## Status

The layout check lists what is not converted, in `tools/layout.lua`:

- `UNCONVERTED`: empty. Every recipe with no url is a thin wrapper of a component: `apple-compat`, the Swift backports, `swift-embedded` (its Swift module and Unicode tables are built by a target of `toolchain/src/swift-embedded`).
- `REACHING`: empty. The RealityFoundation, RealityKit, Spatial, CloudKit, WeatherKit and Network overlays are Swift targets of the Backports component, shared libraries built against the runtime with the runtime's own resource dir, and each has a thin wrapper package. The SceneKit apinotes merge the overlays need lives in `frameworks/Backports/tools/apinotes.lua`, and the Spatial templates are expanded by the component's target. The other packages that reached into a component folder (`ggml`, `iphoneos-sdk`, `libcxx`, `swift-crypto`, `swift-system`) read it through the addon, or through a generated `port/digest.lua`, or their shim is a source of the component's own target.

A recipe that converts while still listed fails the check, and so does a listed recipe that no longer needs to be.

The swift rule installs the `.swiftmodule` of a static or a shared Swift target into `lib/swift/iphoneos`, so a wrapper of a Swift target hands its module to a consumer.

CI configures three things and no others: the checks job configures the host, the backports job configures the `Backports` component, and the swift job configures the `Swift` component and builds and installs its seven targets through their wrappers. The whole iOS graph does not configure yet: `swift-runtime` and `libcxx` have no release for the keys these recipes have now, so a configure would build them from source. `docs/guides/prebuilt.md` says which releases are missing. Until they exist, nothing configures the whole graph, so the `Combine` target is not built by CI yet.

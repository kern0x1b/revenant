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

Why packages and not a copy of our sources: a package names one target and its links, so an outside project takes exactly what the target builds, and the same target serves the checkout and every outside project.

## What is a target and what is a package now

Our code is a target of its component, and the component's `xmake.lua` defines it:

- `frameworks/SwiftUI`: the `SwiftUI` target, which takes Combine from the package.
- `frameworks/Combine`: the test targets only. The module is the package `combine`.
- `frameworks/Backports`: the Objective-C libraries, `RevenantCoding`, the wrapper `RevenantCKWebAuth` and the tweak `revenant-callkit-screen`.

External code stays a package: `combine` (OpenCombine with our patches in `patches/`), `micro-ecc` (the upstream library, unmodified), and the rest of `packages/`.

## Status

These are not converted yet, and the layout check lists them by name in `tools/layout.lua`, in `UNCONVERTED` (a recipe with no url that builds our code) and `REACHING` (a recipe that reaches into a component by a path). Each list must shrink: a converted recipe that is still listed fails the check.

- `emulator`, `emulator-guest`: the component has the targets; the `emulate` include and plugin still take the packages.
- `firmware-tools`: a host tool that every app, daemon and tweak rule takes as a package.
- `apple-compat`: its shims are a dependency of packages that are external (libc++, picotls, quicly, matter, swift-crypto). Converting it needs a way for those packages to take one of our targets at build time, which is not decided.
- The Swift backports `activitykit`, `appintents`, `createml`, `musickit`, `swift-data`, `tipkit`, `widgetkit`: their sources are in `frameworks/Backports/src`, and they are still compiled by their recipes.
- `swift-embedded`: builds the Embedded Swift standard library of the `swift` package; it is a toolchain input without a url.
- Relative paths into `toolchain/modules` (and into `frameworks/`, in `ggml`): the recipes import the addon's modules by a path. `llvm`, `ld64` and `swift` cannot change, because their keys are computed from their own recipe files.

The iOS configuration of the whole graph is not built by any CI job: the Backports job configures and builds the `Backports` component only, and the checks job configures the host. The `SwiftUI` and `Combine` targets are therefore not built by CI yet.

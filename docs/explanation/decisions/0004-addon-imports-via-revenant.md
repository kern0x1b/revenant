# 0004: Addon modules are imported as `@addon.revenant.<module>`

Status: accepted

## Context

The addon's modules (`toolchain/modules/`) are shared by the rules, the packages and the tools. A component
that imports one by path (`rootdir` pointing into `toolchain/modules`) works until the addon moves, and then
breaks silently, because the path is not checked by anything.

## Decision

Inside a project (an `xmake.lua`, a rule, a package recipe), the addon's modules are imported as
`import("@addon.revenant.<module>")`. Code inside `toolchain/` imports its own modules by `rootdir`, which is
its business.

A `./xmakew l` script or a test that is not inside a project cannot always load the addon, so a few of them
reach `toolchain/modules` by path. They are listed in `BY_PATH` in `tools/layout.lua` as debt. Each listed file
still has to contain the path, so the list cannot go stale.

## Consequences

- A new component or package imports the addon through `@addon.revenant`, with no path to the addon's folder.
- The five files in `BY_PATH` move to `@addon.revenant` when the script can load the addon; then they leave the list.

## Enforced by

`repository/layout`: a `.lua` file outside `toolchain/` that contains `"toolchain", "modules"` fails, unless it is
in `BY_PATH`. A listed file that no longer contains it also fails.

## Not enforced

That an `@addon.revenant.<module>` names a module that exists. The import fails when the project loads, which is
the test that counts.

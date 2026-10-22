# 0004: Addon modules are imported as `@addon.revenant.<module>`

Status: accepted

## Context

The addon's modules (`toolchain/modules/`) are shared by the rules, the packages and the tools. A component
that imports one by path (`rootdir` pointing into `toolchain/modules`) works until the addon moves, and then
breaks silently, because the path is not checked by anything.

## Decision

Outside `toolchain/`, the addon's modules are imported as `import("@addon.revenant.<module>")`: from a project
file (an `xmake.lua`, a rule, a package recipe), and from a script or test that `./xmakew` runs, since the
project loads the addon for them too. Code inside `toolchain/` imports its own modules by `rootdir`, which is
its business.

## Consequences

- No component, package or test names the addon's folder. A module that moves is found by xmake, or it fails
  the import, not a path that silently points at nothing.
- A file that wants an addon module imports it through `@addon.revenant`; there is no list of exceptions.

## Enforced by

`repository/layout`: a `.lua` file outside `toolchain/` that contains `"toolchain", "modules"` fails, and so does an
`@addon.revenant.<module>` that names no file in `toolchain/modules/`. The check has no exception list.

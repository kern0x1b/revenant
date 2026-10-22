# 0001: Three layers

Status: accepted

## Context

The repository holds our own code (the emulator, the recompiler, the frameworks, the toolchain), the
third-party code we build but do not write, and the xmake addon that every package and app uses. Without
a rule for which is which, a fix to an upstream lands in our tree, or our code is hidden in a package.

## Decision

revenant has three layers, and every top-level folder belongs to exactly one:

- **Components** are our code. Each is a folder with its own `xmake.lua`: `emulator/`, `recompiler/`,
  `frameworks/<Framework>`, `agent-skills/`, and the `src/` of `toolchain/`.
- **The package repository** (`packages/`, `addons/`) holds external code: an upstream by url and version,
  our patches, and the build glue of an upstream with no build files. See 0002.
- **The addon** is `toolchain/`, the xmake addon `revenant`: the `apple-ios` toolchain, the rules, and the
  plugins. Stock xmake installs it from the checkout.

## Consequences

- A change to an upstream is a patch in `packages/<letter>/<name>/patches/`, never an edit in a component.
- A component builds its sources through the build graph; it does not reach into another component's folder
  by a relative path.
- Adding a top-level folder means changing the layout in `tools/layout.lua`, so the decision is visible in review.

## Enforced by

`repository/layout` (`tools/layout.lua`): the top-level folders, the shape of each component and of the addon,
the recipe shape, and the list `REACHING` of the packages whose recipes reach into a component folder.

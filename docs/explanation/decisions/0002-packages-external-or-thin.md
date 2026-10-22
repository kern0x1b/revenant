# 0002: A package is an upstream by url, or a thin wrapper

Status: accepted

## Context

`packages/` is where third-party code enters the build. If a package could also hold code of its own, the
repository would grow a second, unreviewed copy of a component inside the package tree.

## Decision

Each `packages/<letter>/<name>/` is one of two things:

- **An upstream**: its `xmake.lua` names the source by `add_urls` and `add_versions`, with our changes as
  `patches/NNNN-name.patch` applied in order, and the build glue of an upstream without build files in `port/`.
- **A thin wrapper**: it includes one component's build and installs that component's targets, and holds no
  sources of its own. It is recognised by `@addon.revenant.apple.wrapper` or by an `includes` of the component
  followed by `install`.

A package with neither shape is an error, unless it is listed in `UNCONVERTED` as debt.

## Consequences

- Patches are the only place we change upstream code, and they are numbered, so the order is in the file names.
- A wrapper's sources are the component's sources; fixing them means changing the component.
- `port/` holds build files only (`project.lua`, `config.h`, generated Lua, `.exp` lists); the sources a package
  builds are in its component's `src/`.

## Enforced by

`repository/layout`: the recipe check (a url or a thin wrapper), the `patches/` and `port/` shape, and `REACHING`.
`UNCONVERTED` is the list of packages that are neither yet; it is empty.

# 0003: One entry point, `./xmakew`

Status: accepted

## Context

A build needs a pinned xmake, the revenant addon taken from the checkout, a cache that is ours, and a test
runner. Each of those, run by hand, is a way to build against the wrong xmake or the installed addon.

## Decision

Every build, test and tool runs through `./xmakew`, the launcher that builds the pinned and patched xmake of
`packages/x/xmake` on first use, sets `XMAKE_GLOBALDIR` to the cache, and takes the addon from `toolchain/`.
Tools run as `./xmakew l <script>`; tests run as `./xmakew test -P .`.

## Consequences

- No shell script, Makefile or other launcher is added beside `xmakew`. A new tool is a Lua script run by `./xmakew l`.
- Documentation gives commands in the `./xmakew` form only.
- `frameworks/WebKit/src/packaging/DEBIAN/postinst` is the one file that runs outside xmake: it is a hook of the
  `.deb` format, run by the package installer on a device, not by us.

## Enforced by

`repository/layout`: no tracked file ends in `.sh`, and none is named `Makefile`. The `postinst` hook has no
extension, so the check does not see it; it is named here instead.

## Not enforced

That the docs use `./xmakew` throughout. Nothing checks the prose.

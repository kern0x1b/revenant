# 0003: One entry point, `./xmakew`

Status: accepted

## Context

A build needs a pinned xmake, the revenant addon taken from the checkout, a cache that is ours, and a test
runner. Each of those, run by hand, is a way to build against the wrong xmake or the installed addon.

## Decision

Every build, test and tool run against this checkout goes through `./xmakew`, the launcher that builds the pinned
and patched xmake of `packages/x/xmake` on first use, sets `XMAKE_GLOBALDIR` to the cache, and takes the addon from
`toolchain/`. Tools run as `./xmakew l -P . <script>`; tests run as `./xmakew test -P .`. Examples for applications
built outside this checkout use the xmake executable installed for that application.

## Consequences

- No shell script, Makefile or other launcher is added beside `xmakew`. A new tool is a Lua script run by `./xmakew l -P .`.
- Commands that operate on this checkout use the `./xmakew` form. Consumer-project examples use the project's xmake.
- `frameworks/WebKit/src/packaging/DEBIAN/postinst` is the one file that runs outside xmake: it is a hook of the
  `.deb` format, run by the package installer on a device, not by us.

## Enforced by

`repository/layout`: no tracked file ends in `.sh`, none is named `Makefile`, and no tracked file starts with `#!`
except `xmakew` and the Debian maintainer scripts under `DEBIAN/`, which dpkg runs.

## Not enforced

That a command example is labeled with the correct project context. The distinction is described in each guide, but
no check parses the prose.

# 0013: An upstream's own build keeps its Python

Status: accepted

## Context

0005 made the repository's own tools Lua. It was then read as forbidding Python anywhere in a build, so upstreams whose
own build runs Python were being ported instead: dav1d builds only with meson, WebKit generates sources with 26 Python
scripts of about 29,000 lines, and Swift expands its `.gyb` templates with `gyb.py`. A port of an upstream's build
logic is code the upstream never tests, and it has to be redone at every update.

## Decision

A package builds an upstream the way the upstream builds itself. When that build is meson, or runs the upstream's own
Python generators, the package runs it through xmake's package tools (`package.tools.meson` and the like), with the
interpreter the upstream needs. 0005 still holds for everything the repository itself writes: its tools, tests and
build logic are Lua, and no Python is tracked in it.

## Consequences

- dav1d is a meson package; WebKit's generators run as WebKit ships them, and no Lua port of them is made.
- The Lua ports that already exist (`modules/gyb`, the ICU data trim) stay while they are correct and tested; a new
  upstream generator is not ported.
- An upstream that needs Python needs it on the build machine and on CI, as it needs its other build tools.

## Enforced by

`repository/layout`: a tracked file ending in `.py` fails (0005). Patches to an upstream's own Python are not
tracked `.py` files and are allowed.

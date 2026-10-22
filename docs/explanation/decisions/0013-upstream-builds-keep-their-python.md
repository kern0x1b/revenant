# 0013: An upstream's own build keeps its own tooling

Status: accepted

## Context

0003 and 0005 made the repository's own tools Lua behind one entry point, `./xmakew`. They were then read as
forbidding Python, shell and the like anywhere in a build, so upstreams whose own build runs them were being ported
instead: dav1d builds only with meson, WebKit generates sources with 26 Python scripts of about 29,000 lines, libvpx
runs shell and perl, and Swift expands its `.gyb` templates with `gyb.py`. A port of an upstream's build logic is code
the upstream never tests, and it has to be redone at every update.

## Decision

A package builds an upstream the way the upstream builds itself, with whatever the upstream ships or names for that:
its build system (meson, autotools, cmake), its scripts in any language (Python, shell, perl) and the helper tools it
documents, such as FFmpeg's `gas-preprocessor.pl`. The package runs them through xmake's package tools
(`package.tools.meson`, `package.tools.autoconf` and the like), with the interpreters they need.

0003 and 0005 still hold for everything this repository writes itself: its tools, tests, build logic, and the local
overlays it keeps for an app under test are Lua run by `./xmakew`, with no Python and no shell script of its own.

## Consequences

- dav1d is a meson package; WebKit's generators run as WebKit ships them, and no Lua port of them is made.
- The Lua ports that already exist (`modules/gyb`, the ICU data trim) stay while they are correct and tested; a new
  upstream generator or script is not ported.
- An upstream that needs Python, perl or a shell needs it on the build machine and on CI, as it needs its other build
  tools.

## Enforced by

`repository/layout`: a tracked file ending in `.py` fails (0005), and so does a shell script (0003). Patches to an
upstream's own scripts are not tracked scripts and are allowed.

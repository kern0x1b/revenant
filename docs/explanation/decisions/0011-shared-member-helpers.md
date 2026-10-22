# 0011: One set of path and argument helpers for a member's tools

Status: accepted

## Context

Each framework member keeps a `tools/lib/tree.lua` that its tools import as `lib.tree`. SwiftUI's
and WebKit's had the same functions under different names: `root(...)` in one, `member(...)` in the other, both the
member's folder, and `revenant(...)`, the checkout's root. They differ in everything else. SwiftUI's tools use the
addon's workspace (`run`, `fresh`, `sdk`, the `demo` target). WebKit's tools use `where(name)` (xmake's package
folder for WebKit), `engine_source`, the packaging `patches` and `recipe`, and `arguments(argv, flags)`, a
flag parser. Eighteen tools and three device tests call these, and the copies had already diverged.

The three device tests in `frameworks/WebKit/tests/device/` import the same file with `rootdir` into `tools/lib`,
which is the path form ADR 0004 forbids for the addon's own modules. That import is of the member's file, so it is
allowed, but it is one more reason the helper's location matters.

## Options

- **A. Keep both files.** Nothing moves. The copies drift further: a fix to `revenant(...)` has to be made twice.
- **B. One addon module with the shared part, and a thin binding per member.** The addon module
  `toolchain/modules/member.lua`, imported as `@addon.revenant.member`, holds the path helpers that take the calling
  tool's folder, and the argument parser, which is not specific to any member. Each member's `lib/tree.lua` keeps
  only its own functions and delegates the shared ones, so the call sites do not change.
- **C. Move everything into the addon.** The WebKit and SwiftUI functions are specific to their members, so this
  moves member knowledge into the addon. Rejected.

## Decision

Option B, implemented. `toolchain/modules/member.lua` holds `root(folder, ...)` (a member's folder, from the folder of
its `tools/lib`), `checkout(member_root, ...)` (the checkout's root, from a member's folder) and `arguments(argv, flags)`.
Each member's `tools/lib/tree.lua` imports it once as `shared` and keeps `root`/`member`, `revenant` and its own
functions as bindings. The member-specific functions stay in the member. The addon module takes the folder of the
caller as an argument, because a module under `toolchain/modules` cannot know which member imported it.

## Consequences

- One definition of the member and checkout paths and of the flag parser. A fix is made once.
- The member files keep their names and their call sites; the change is inside `lib/tree.lua`.
- The addon module is part of the toolchain's public surface, so its names are kept stable from here on.

## Enforced by

`repository/layout` (`tools/layout.lua`): a member's `tools/lib/tree.lua` must import `@addon.revenant.member`, and
must not define `arguments`, so a copy of the parser cannot come back in a member.

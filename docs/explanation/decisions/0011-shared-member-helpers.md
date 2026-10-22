# 0011: One set of path and argument helpers for a member's tools

Status: proposed

## Context

Each framework member keeps a `tools/lib/tree.lua` that its tools import as `lib.tree`. SwiftUI's
(`frameworks/SwiftUI/tools/lib/tree.lua`, 43 lines) and WebKit's (`frameworks/WebKit/tools/lib/tree.lua`, 60 lines)
have the same first two functions under different names: `root(...)` in one, `member(...)` in the other, both the
member's folder, and `revenant(...)`, the checkout's root. They differ in everything else. SwiftUI's tools use the
addon's workspace (`run`, `fresh`, `sdk`, the `demo` target). WebKit's tools use `where(name)` (xmake's package
folder for WebKit), `engine_source`, the packaging `patches` and `recipe`, and `arguments(argv, flags)`, a
flag parser. Fifteen tools and three device tests call these, and the copies have already diverged.

The three device tests in `frameworks/WebKit/tests/device/` import the same file with `rootdir` into `tools/lib`,
which is the path form ADR 0004 forbids for the addon's own modules. That import is of the member's file, so it is
allowed, but it is one more reason the helper's location matters.

## Options

- **A. Keep both files.** Nothing moves. The copies drift further: a fix to `revenant(...)` has to be made twice.
- **B. One addon module with the shared part, and a thin binding per member.** The addon module (for example
  `toolchain/modules/member.lua`, imported as `@addon.revenant.member`) holds the path helpers that take the calling
  tool's folder, and the argument parser, which is not specific to any member. Each member's `lib/tree.lua` keeps
  only its own functions and delegates the shared ones, so the call sites do not change.
- **C. Move everything into the addon.** The WebKit and SwiftUI functions are specific to their members, so this
  moves member knowledge into the addon. Rejected.

## Decision (proposed)

Option B. The shared part is the member and checkout paths and the argument parser. The member-specific functions stay
in the member. The addon module takes the folder of the caller as an argument, because a module under
`toolchain/modules` cannot know which member imported it.

## Consequences

- One definition of `revenant(...)` and of the flag parser. A fix is made once.
- The member files keep their names and their call sites; the change is inside `lib/tree.lua`.
- The addon module is part of the toolchain's public surface, so its names are kept stable once it lands.

## Enforced by

Not enforced yet. Proposed: a repository check that no two `lib/tree.lua` files define the same function name, so a
copy cannot come back unnoticed once B is in place.

# Vendored skills

Copied verbatim (not modified) from [xmake-io/xmake-skills](https://github.com/xmake-io/xmake-skills),
commit `ef67caa`, under the Apache License 2.0 (see that project's `LICENSE.md`).

## Vendored here

- `xmake-swift` — Use when building Swift projects with xmake — binary/library targets with `.swift` sources, Swift ↔ C++/Objective-C interop (`swift.interop` value), Swift module name configuration, and iOS/macOS builds.
- `xmake-packages` — Use when adding third-party C/C++ dependencies to an Xmake project — via `add_requires` / `add_packages`, configuring package options, pinning versions, or using `xrepo` from the command line.

`rtpkg/` is a real xmake package project (`xmake.lua`, `control`, `main.swift`) that builds a Swift
target through Charon's `@addon/charon/swift` rule and pulls its runtime dependencies with
`add_requires`/`add_packages` — hence both skills. `xmake-troubleshooting` was left out: nothing in
this repository's build scripts or docs shows real xmake debugging friction to warrant it.

To update: re-clone the source repo at a newer commit and replace these directories wholesale;
do not hand-edit vendored skill text. A workspace or repository rule always overrides a vendored
skill's advice where the two conflict (see this repository's AGENTS.md).

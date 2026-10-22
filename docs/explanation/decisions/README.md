# Decisions

Each decision here is short: the context it answers, what was decided, what follows from it, and the
check that enforces it. Where no check enforces a decision yet, the record says so under "Not enforced".
A decision that changes gets a new record that supersedes the old one; the old one stays.

| Record | Decision | Enforced by |
| --- | --- | --- |
| [0001](0001-three-layers.md) | Three layers: components, the package repository, the addon | `repository/layout` |
| [0002](0002-packages-external-or-thin.md) | A package is an upstream by url, or a thin wrapper of one component | `repository/layout` |
| [0003](0003-one-entry-point.md) | One entry point, `./xmakew` | `repository/layout` (no shell scripts or Makefiles) |
| [0004](0004-addon-imports-via-revenant.md) | Addon modules are imported as `@addon.revenant.<module>` | `repository/layout` |
| [0005](0005-lua-only.md) | Lua only, no Python | `repository/layout` (no `.py` files) |
| [0006](0006-no-comments.md) | No comments, except a licence header | `repository/comments_check` |
| [0007](0007-prebuilt-packages.md) | Prebuilt packages, and the keys that name them | `digest_test` (the digest files only) |
| [0008](0008-backports-loud-stubs.md) | Backports live in `frameworks/Backports`; a gap is a loud stub | the build (`open_gap` raises) |
| [0009](0009-app-under-test.md) | The Telegram test is read-only source plus an overlay outside the repository | `repository/layout` (no tracked path names it) |
| [0010](0010-collation-of-xmake.md) | xmake sorts with the collation `./xmakew` sets (`en_US.UTF-8`) | none yet (see the record) |
| [0011](0011-shared-member-helpers.md) | One set of path and argument helpers for a member's tools (proposed) | none yet (see the record) |
| [0012](0012-one-backports-package.md) | One package for every Backports library, depending on the shared packages it names | `toolchain_packages/backports_package_test` |

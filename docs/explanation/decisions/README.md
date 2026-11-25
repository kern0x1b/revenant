# Decisions

Each decision here gives its context, what was decided, what follows from it, and the check that enforces it.
Where a decision has no check, the record says so under "Not enforced".
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
| [0008](0008-backports-loud-stubs.md) | Backports live in `frameworks/Backports`; a gap is a loud stub | the build (`open_gap` raises); `repository/open_gaps` (every gap is named in the README) |
| [0009](0009-app-under-test.md) | The Telegram test is read-only source plus an overlay outside the repository | `repository/layout` (no tracked path names it) |
| [0010](0010-collation-of-xmake.md) | xmake sorts with the collation `./xmakew` sets (`en_US.UTF-8`); superseded by 0017 | none (superseded) |
| [0011](0011-shared-member-helpers.md) | One set of path and argument helpers for a member's tools | `repository/layout` (a member's `tree.lua` binds the shared module) |
| [0012](0012-one-backports-package.md) | One package for every Backports library, depending on the shared packages it names | `toolchain_packages/backports_package_test` |
| [0013](0013-upstream-builds-keep-their-python.md) | An upstream's own build keeps its own tooling; ours is Lua | `repository/layout` (no tracked `.py` or shell files) |
| [0014](0014-performance-is-a-requirement.md) | Speed and memory on the A5 are part of correctness; claims are measurements | not enforced (a benchmark group is the check it needs) |
| [0015](0015-urlcomponents-follows-the-sdk-it-is-linked-against.md) | NSURLComponents parses as macOS does: the lenient grammar the 26.2-linked apps get | `frameworks/Backports/tests/url_components_oracle_test.lua` (run by hand; not in a group yet) |
| [0016](0016-swift-overlays-self-contained.md) | A Swift overlay is self-contained over the backport's own layers on every release; no Swift symbol is forwarded to the system or to a renamed copy | not enforced |
| [0017](0017-build-hash-sorts-by-byte.md) | xmake's build hash sorts by byte, so a key does not depend on the locale | `toolchain/tests/addon/patch_set_test.lua`, `repository/layout` (no pinned collation) |
| [0018](0018-source-folder-per-build.md) | A build of a package patches and builds in its own APFS copy of the pinned sources, not in the folder two builds share | `toolchain_light/source_lock_test`, `toolchain_light/checkout_test` |
| [0019](0019-one-package-store-per-machine.md) | One package store per machine at a fixed path, read by every worktree through links; no per-worktree clone, no path rewrite | `toolchain_light/shared_store_test`, `toolchain_light/cache_test` |
| [0020](0020-dependent-hash-follows-strict-dependencies.md) | A package's key follows how its strict dependencies differ from their defaults | `toolchain_light/dependency_keys_test`, `toolchain_packages/dependency_images_test` |

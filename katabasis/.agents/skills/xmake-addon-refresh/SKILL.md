---
name: xmake-addon-refresh
description: Diagnose, read-only, a stale charon xmake addon payload when a charon-addon-consuming build fails with a missing include, a missing symbol, or a check() result that doesn't match current charon source. Use when addons.conf's active pointer, the repository URL, or the project-local cache all look correct but the build still behaves like an old charon.
---

# Diagnose a stale xmake addon payload

`add_addons("charon latest")` in a target's `xmake.lua` resolves against a shared,
already-installed payload directory, `<XMAKE_GLOBALDIR>/addons/charon/<version>/` (for the
"latest" bucket, `.../charon/latest/`). Nothing in the ordinary build path refreshes that
directory's *contents* once it exists on disk. If charon's source has moved on since that
directory was populated, the build keeps using the old payload no matter what else changes.

Symptoms that mean the payload — not the addon registration — is stale:

- `includes(@addon/charon/apple-ios) not found!` even though `addons.conf` names a version whose
  `repo.commit`/`repo.url` point at current `charon` `main`.
- A `dyld.lua` behavior (e.g. the `ordering`/`exempt` split) that doesn't match what's in the
  current `charon` checkout's `modules/apple/dyld.lua`.

Things that look like fixes but do not touch the payload, so don't waste a cycle on them first:

- Editing `addons.conf`'s `active` field to a version whose metadata points at current `charon` —
  a manifest entry is not evidence of a completed install.
- Deleting a project-local `xmake-addons.lock` or `.xmake` cache — lets the build run further
  instead of failing instantly on `includes()`, but the underlying payload on disk is untouched.
- Repointing this project's own `add_repositories` at a valid, current local clone —
  `add_addons("charon latest")` resolves against the shared, already-installed `latest` bucket,
  not a fresh resolution through the project's declared repository.

## Procedure

The payload directory is shared machine-wide and is never edited by hand: no copying files into
it, no `xmake addon --remove`, no re-registration. Removing or reinstalling the addon pulls every
other in-flight build's plugins (`device`/`deb`/`emulate`) out from under it, and on xmake 3.1.1
any install makes itself the machine's `active` version (`coordination/crutches.md`, the xmake
addon lock entry). What this skill does is diagnose, read-only, and hand the finding over.

1. Find the active payload directory: `<XMAKE_GLOBALDIR>/addons/charon/<active-version-or-latest>/`.
2. Diff its `{modules,rules,toolchains,includes,plugins}` trees against the same trees in a
   current `charon` `main` checkout. Diff by path, not by version label.
3. Ground truth for what is on disk is the installed file itself: a marker count (for example
   `grep -c ordering <installed-dyld.lua>`) and its `mtime`, next to the checkout's own value.
   Do not trust `addons.conf`'s `active` field or a build log's cosmetic `upgrade charon: ...`
   message. Both can look current while the payload is still stale.
4. Send the differing paths and the measurements to the coordinator. The coordinator decides how
   the shared payload is refreshed.
5. To check that a given charon version behaves as expected, follow the contract's rule in
   `AGENTS.md`, "The charon addon". For a build's verdict, read its *final* line
   (`[100%]: build ok` or `error:`), not an intermediate `imports: ... resolves against N exports`,
   which also prints in a build that later fails at link.

## When to branch out

This repository vendors no xmake skills; the ones below are in charon, at
`$HOME/Git/projects/ios/charon/.agents/skills/<name>/SKILL.md`.

- Addon install/registration mechanics (`add_addons`, `@addon/<name>/<rule>`, `addons.conf`) →
  charon's `xmake-addons` skill.
- What `XMAKE_GLOBALDIR` actually controls → charon's `xmake-env-vars` skill. Never use that
  skill's general debugging advice to `rm -rf` or force-reinstall anything under the shared
  addon/package store — this workspace's rule against touching the shared store overrides it.

# 0019: One package store per machine, at a fixed path

Status: accepted

## Context

Each worktree had a cache of its own with a package store inside, made by cloning another cache
(`tools/private_cache.lua`) and rewriting every absolute path in the clone. On one machine that was 75 stores, the same
package keys built two to four times (libcxx three times in one morning), 16 million files that every create and delete
passed through the file-system event daemon, and, when a cache was made by hand instead of cloned, a cold build of every
package (63 minutes on 2026-11-16). A clone was only as warm as the cache it came from, and a path that the rewrite did
not know about (a text file that named the source cache) kept pointing at the other cache.

The clone existed because an install records absolute paths (a CMake cache, a manifest, a `.pc` file, a response file), so
a store could not be moved or shared between two places. A store that never moves needs no rewrite.

## Decision

- There is one store per machine, a folder at a fixed absolute path: `REVENANT_STORE`, default `~/.revenant/store`.
  It holds the pinned xmake (`<store>/xmake/<key>`, one build per machine) and the package store
  (`<store>/xmake-global`, `XMAKE_GLOBALDIR`).
- The xmake of a key is built under a lock on `<store>/xmake/<key>.lock` (`flock` or `lockf`), re-checked under the lock, so
  launchers that ask at once wait for one build and use it; the build works in a folder of its own and is moved into place
  once, and it leaves its log only when it fails. The wait is bounded: the launcher says every 30 seconds who holds the lock
  (the builder writes its process and start to `<store>/xmake/<key>.holder`) and for how long, and stops with an error after
  1800 seconds (`REVENANT_XMAKE_BUILD_WAIT`, `REVENANT_XMAKE_BUILD_POLL`), because a build that hangs under a lock with no
  limit blocks every launcher of its key and says nothing.
- `./xmakew` links `xmake` and `xmake-global` of the cache to those folders and runs xmake with
  `XMAKE_GLOBALDIR=<store>/xmake-global`. A worktree's cache holds only what is the worktree's own: the token pool, the
  scratch of its tasks, the lowered caches, `dyld` and `firmware` when a task needs them. A relative `REVENANT_STORE` is
  refused.
- A cache from before the store, with a package store of its own, is refused before `./xmakew` makes anything (no store, no
  link), and it prints the command that makes the cache the store once, run with an xmake binary of that cache because
  the seeding refuses a store that has anything in it (`<cache>/xmake/<key>/bin/xmake l -P . tools/private_cache.lua <store>
  --from <cache> --only xmake,xmake-global`, only while the store does not exist). A real `xmake-global` beside the store's
  would be read by the tools that read it, and it is not the store's.
- The store is bounded and rooted. `tools/cache.lua` drops what no root names when the store passes
  `REVENANT_STORE_GB` (80 GB); a root is a file `<store>/roots/*.txt` of `<letter>/<package>/<version>/<key>[.g<token>]`
  lines, the format of Telegram's `bazel/store-pins.txt`. The check is throttled (`.cap-checked`, 600 s) and runs in one
  process at a time (`<store>/.trim.lock`; a process that finds it held leaves the trim to the holder). A store that cannot
  be brought under its cap is reported by the build that found it and does not stop that build. An entry whose lock
  (`<installdir>.lock`, `<sourcedir>.lock`) another process holds is not evicted, whatever the list of open files said when
  it was taken. `.cache` keeps its own cap (`REVENANT_CACHE_GB`, 50 GB), which does not count the linked store parts.
- Two installs of one package key never run at once (the install, download included, is locked per folder, `<installdir>.lock`),
  and two keys
  of one package build in their own copies of the sources ([ADR 0018](0018-source-folder-per-build.md)), so one store
  serves any number of processes.

## Consequences

- A key is built once per machine, whatever worktree asks for it. A new worktree has all the packages at once.
- Nothing is rewritten, so nothing can be left pointing at another cache. `tools/private_cache.lua` is only the way
  to seed the store the first time (or to make a scratch store for an experiment).
- `xmakew` changes, so its key changes: every machine builds xmake once more, into the store.
- A task that must not share packages (a trial) sets `REVENANT_STORE` and `REVENANT_CACHE` to empty folders and builds
  its own xmake and packages.
- The store is shared by every project that runs `xmakew` on the machine, and it is capped; a package no root names is
  the first to go when the cap is reached.

## Enforced by

`toolchain_light/shared_store_test`: the launcher takes the store from `REVENANT_STORE`, links the cache to it, runs xmake
with `XMAKE_GLOBALDIR` in it, takes a linked worktree's own `.cache` or any folder `REVENANT_CACHE` names, refuses a cache
that has a package store of its own with the seeding command, and refuses a relative store. `toolchain_light/cache_test`
holds the roots, the cap, the throttle and the rule that the cache's cap does not count the store.

# 0018: A build of a package works in its own copy of the sources

Status: accepted

## Context

A package's sources are downloaded once into `<cache>/packages/<month>/<letter>/<name>/<version>/source`, and the folder
is named by the package and its version, not by the build: two builds of one package (the libcxx of two applications,
whose configs or digests differ, so whose build hashes differ) installed by two xmake processes on one store share
it. `checkout.pinned` resets that folder with `git checkout -- .` and `git clean -fd` at every download, and four
recipes (llvm, libcxx, swift-runtime, swift) patched it with `git apply` and built in it. A download of the second
build reset the files the first one was compiling: a patched `cxa_thread_atexit.cpp` and `libcxxabi/src/CMakeLists.txt`
became the upstream ones in the middle of a compile, and `libc++abi.1.0.dylib` failed to link with
`___cxa_thread_atexit` undefined (2026-11-20, two applications on one store, the objects of one build made from the
sources of two).

A lock around the download, the patches and the build would make the second build wait for the first, 45 minutes
for llvm. The sources are the same for both builds; only what a build does to them differs.

## Decision

- `checkout.pinned` only keeps the shared folder pristine, under a lock on `source.lock` held for the clone or the
  reset, which is seconds. Nothing builds in it.
- A recipe that patches or builds in its sources calls `checkout.keyed(os.curdir(), package:buildhash())` after its
  prebuilt early return and works in the folder it returns: `source-<build hash>`, an APFS clone (`cp -cR`) of the
  pristine shared folder. A clone shares its blocks with the shared folder, so it costs a few seconds and almost no
  disk (llvm's 180,000-file checkout: 18 s under load average 25, 45 MB).
- A copy that exists and was made from the same pinned sources (their stamp, `revenant-sources.txt`, is equal) is reset
  with `git checkout -- .` and `git clean -fd`, which keeps an ignored build directory, so a build that was interrupted
  resumes where it stopped, as it did in the shared folder. A copy of other sources is made again.
- The lock is `toolchain/modules/exclusive.lua`: an flock that a waiting coroutine retries with `os.sleep`, so one
  xmake process holding the lock in one coroutine does not stop the other coroutines of the process.

A package that only reads its sources (tessdata, libsql) keeps working in the shared folder.

## Consequences

- Two builds of one package run at once on one store and each compiles the sources it patched.
- A package's cache holds one more copy of the sources per build hash that was built from source; they are removed with
  the package's cache folder.

## Enforced by

`toolchain_light/source_lock_test`: two processes install two builds of one package, the second downloading while the
first is patching. In the shared folder (the control) one of them compiles the unpatched source; with `keyed` both
compile the patched one. `toolchain_light/checkout_test` holds the copies: separate folders, a patch in one reaching
no other, a reset that keeps an ignored build directory, a copy made again when the pinned sources change.

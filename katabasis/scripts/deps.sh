#!/bin/sh
# deps.sh OUT -- reproduce the lifter's dependency tree from scratch: clone rellume and its
# subprojects at the commits deps/patches/*-base-commit.txt pin, apply deps/patches/*.patch on top
# in the order listed there, and build librellume.dylib. OUT must be a directory scripts/deps.sh
# itself owns (a fresh, empty one, or one it created on an earlier run of its own): the shared
# checkout every worktree's `deps` symlink points at is not it, on purpose (reviewed r8: a bare
# `sh scripts/deps.sh` defaulting to that checkout would `reset --hard`/`clean -fdx` whatever
# uncommitted work someone else's band has sitting there). A fresh OUT reproduces the whole tree
# this band's patches are checked against, which is the point -- deps/ itself is gitignored (a
# fetched build dependency, not source), only deps/patches/ is tracked.
#
# xlate/CMakeLists.txt's RELLUME_DIR defaults to ../deps/rellume but honors -DRELLUME_DIR on the
# command line, so a clean-room build against OUT (not the shared checkout) is:
#   cmake -B /tmp/xlate-check -DRELLUME_DIR=$OUT/rellume -DLLVM_DIR=... -DClang_DIR=... xlate
#   cmake --build /tmp/xlate-check --target xlate xlgen
set -eu
LAB=$(cd "$(dirname "$0")/.." && pwd)
PATCHES="$LAB/deps/patches"
if [ $# -lt 1 ]; then
  echo "usage: $0 OUT -- OUT must be a directory this script owns (fresh, or made by an earlier run of its own); it is reset --hard and cleaned" >&2
  exit 2
fi
out=$1
mkdir -p "$out"
owned="$out/.deps-sh-owns-this"
if [ -e "$owned" ]; then
  : # a directory an earlier run of this script created: safe to reuse
elif [ -z "$(ls -A "$out" 2>/dev/null)" ]; then
  : # empty (including newly made by the mkdir -p above): ours from here on
else
  echo "deps.sh: $out exists, is not empty, and was not created by this script (no $owned) -- refusing to touch it. Pass an empty or fresh directory." >&2
  exit 1
fi
touch "$owned"

clone_at() {  # clone_at NAME URL COMMIT -- a scratch clone under OUT, which the check above has
              # already established this script either created or owns from an earlier run of
              # itself: reset hard and clean, so a re-run applies patches onto the pinned commit
              # fresh rather than on top of what an earlier run of THIS script already applied
              # (that dirt -- our own patches from last time -- is exactly what reset/clean is for;
              # the check above is what stops it from ever running on someone else's directory).
  name=$1 url=$2 commit=$3
  if [ ! -d "$out/$name/.git" ]; then
    echo "cloning $name"
    git clone -q "$url" "$out/$name"
  fi
  git -C "$out/$name" fetch -q origin "$commit" 2>/dev/null || true
  git -C "$out/$name" checkout -q "$commit"
  git -C "$out/$name" reset -q --hard "$commit"
  git -C "$out/$name" clean -q -fdx
}

# Every deps/patches/<prefix>*.patch, in the (deterministic, alphabetical) order ls gives them --
# a second patch to the same repo is meant to apply after the first, and file names sort that way.
apply_patches() {  # apply_patches REPO PREFIX
  repo=$1 prefix=$2
  for patch in "$PATCHES/$prefix"*.patch; do
    [ -e "$patch" ] || continue
    echo "applying $(basename "$patch") to $repo"
    git -C "$out/$repo" apply --whitespace=nowarn "$patch"
  done
}

clone_at rellume https://github.com/aengelke/rellume "$(cat "$PATCHES/rellume-base-commit.txt")"
apply_patches rellume rellume-

clone_at rellume/subprojects/farmdec https://github.com/okitec/farmdec.git "$(cat "$PATCHES/farmdec-base-commit.txt")"
apply_patches rellume/subprojects/farmdec farmdec-

# fadec (x86-64) and frvdec (riscv) are the OTHER guest architectures rellume's own meson.build
# always configures alongside aarch64 (xlate uses none of their code); no patches here touch them.
clone_at rellume/subprojects/fadec https://github.com/aengelke/fadec.git "$(cat "$PATCHES/fadec-base-commit.txt")"
clone_at rellume/subprojects/frvdec https://git.sr.ht/~aengelke/frvdec "$(cat "$PATCHES/frvdec-base-commit.txt")"

[ -d "$out/BlocksRuntime" ] || git clone -q https://github.com/mackyle/blocksruntime "$out/BlocksRuntime"

# meson needs llvm-config on PATH; this checkout's own venv (or the system meson, if that already
# works) is the meson to use -- whichever one exists, tried in that order, so a stale absolute path
# baked into a PREVIOUS build directory (this one hit, from before the workspace now called
# katabasis was renamed from emulator-lab/recompile) never comes back: --wipe forces meson to
# regenerate build.ninja's own "how to reconfigure" command from the CURRENT invocation, not read it.
LLVM_BIN=/opt/homebrew/opt/llvm/bin
# The venv lives beside the main checkout, not necessarily this one -- LAB is a worktree of the same
# repo when run from one, and worktrees do not share dotfiles. git-common-dir's parent is the main
# checkout regardless of which worktree deps.sh runs from.
MAIN_CHECKOUT=$(dirname "$(cd "$LAB" && git rev-parse --path-format=absolute --git-common-dir)")
MESON=""
if command -v meson >/dev/null 2>&1 && meson --version >/dev/null 2>&1; then
  MESON="meson"
else
  for venv in "$LAB/.venv" "$MAIN_CHECKOUT/.venv"; do
    if [ -x "$venv/bin/python3" ]; then
      MESON="$venv/bin/python3 -m mesonbuild.mesonmain"
      break
    fi
  done
fi
if [ -z "$MESON" ]; then
  echo "deps.sh: no working meson found (checked PATH, $LAB/.venv, $MAIN_CHECKOUT/.venv); pip install meson ninja into one of them" >&2
  exit 1
fi
PATH="$LLVM_BIN:$PATH" $MESON setup --wipe "$out/rellume/build" "$out/rellume" -Dbuildtype=release
PATH="$LLVM_BIN:$PATH" ninja -C "$out/rellume/build"
echo "deps.sh: built $out/rellume/build/src/librellume.dylib"

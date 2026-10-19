#!/usr/bin/env python3
"""Check that every path the build flags name actually exists.

    tests/scripts/flag-paths-exist.py

A flag that names a folder which is not there does not fail at configure time: it
fails later, as a missing standard header, hundreds of lines into a compile log.
This reads the cache variables Conan wrote for each build tree and refuses when a
path in them is absent. It caught nothing when it was written - it exists because
a doubled include path got past a comparison that never looked at the flags.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
FLAGS = ("CMAKE_CXX_FLAGS", "CMAKE_C_FLAGS", "CMAKE_OBJCXX_FLAGS", "CMAKE_OBJC_FLAGS",
         "CMAKE_SHARED_LINKER_FLAGS", "CMAKE_EXE_LINKER_FLAGS", "CMAKE_MODULE_LINKER_FLAGS")
CARRY_A_PATH = ("-isystem", "-isysroot", "-I", "-L", "-F", "-B", "-include")


def presets():
    return sorted(BUILD.glob("*/conan/CMakePresets.json"))


def cache_variables(path):
    with path.open() as handle:
        document = json.load(handle)
    found = {}
    for preset in document.get("configurePresets", []):
        for name, value in (preset.get("cacheVariables") or {}).items():
            found.setdefault(name, value)
    return found


def paths_in(flags):
    words, found = flags.split(), []
    for index, word in enumerate(words):
        for prefix in CARRY_A_PATH:
            if word == prefix and index + 1 < len(words):
                found.append((prefix, words[index + 1]))
            elif word.startswith(prefix) and len(word) > len(prefix) and word[len(prefix)] == "/":
                found.append((prefix, word[len(prefix):]))
    return found


def main():
    trees = presets()
    if not trees:
        print("FAIL  no build tree has been configured, so there are no flags to check; run charon build first")
        return 1
    failures, checked = [], 0
    for tree in trees:
        variables = cache_variables(tree)
        missing = [name for name in FLAGS if name not in variables]
        if missing:
            failures.append("{} carries no {}".format(tree, ", ".join(missing)))
        for name in FLAGS:
            for prefix, path in paths_in(str(variables.get(name, ""))):
                checked += 1
                if not Path(path).exists():
                    failures.append("{} in {} names {} which does not exist".format(prefix, name, path))
    for line in failures:
        print("FAIL  {}".format(line))
    if failures:
        print("{} flags name something that is not there".format(len(failures)))
        return 1
    print("ok    {} paths named by the flags of {} build tree(s) all exist".format(checked, len(trees)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

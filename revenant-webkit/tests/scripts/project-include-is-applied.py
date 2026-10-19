#!/usr/bin/env python3
"""Check that the engine resolved its packages from the graph and not from the SDK.

    tests/scripts/project-include-is-applied.py

The declaration points cmake at a file that forces the engine's find_package
calls into CONFIG mode, so they answer with the packages Conan built. cmake
applies that file as CMAKE_PROJECT_<the name the engine gives project()>_INCLUDE;
when the name is wrong the variable is accepted, cached, and never consumed, and
find_package quietly falls back to the iOS SDK. Nothing fails at configure time
on a tree that was already configured correctly once, because the cache keeps the
earlier answer - which is why this reads the result rather than the variable.
"""
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
MANIFEST = ROOT / "charon.toml"


def caches():
    return sorted(BUILD.glob("*/CMakeCache.txt"))


def entries(path):
    found = {}
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "//")) or ":" not in line or "=" not in line:
            continue
        name, _, rest = line.partition(":")
        kind, _, value = rest.partition("=")
        found[name] = (kind, value)
    return found


SUFFIXES = ("_INCLUDE_DIR", "_LIBRARY_DIR", "_ROOT_DIR", "_DIR", "_INCLUDE", "_LIBRARY", "_ROOT")


def manifest():
    with MANIFEST.open("rb") as handle:
        return tomllib.load(handle)


def declared():
    return manifest().get("engine", {})


def required():
    return {name.lower() for name in manifest().get("requires", {})}


def package_of(key):
    for suffix in SUFFIXES:
        if key.endswith(suffix):
            return key[: -len(suffix)].lower()
    return None


def main():
    engine = declared()
    include = engine.get("project-include") or (
        "the packages it declares under config-packages" if engine.get("config-packages") else None)
    if not include:
        print("ok    the declaration asks for no package to be found by config, so there is nothing to apply")
        return 0
    name = engine.get("project-name")
    if not name:
        print("FAIL  charon.toml names project-include but no project-name, so the file cannot be applied")
        return 1

    trees = caches()
    if not trees:
        print("FAIL  no build tree has been configured, so there is no result to read; run charon build first")
        return 1

    failures, checked = [], 0
    for cache in trees:
        values = entries(cache)
        variable = "CMAKE_PROJECT_{}_INCLUDE".format(name)
        if variable not in values:
            failures.append("{} carries no {}, so the engine's find_package calls were never forced "
                            "into CONFIG mode".format(cache, variable))
            continue
        applied = Path(values[variable][1])
        if not applied.is_file():
            failures.append("{} names {} which does not exist".format(variable, applied))

        for key, (_, named) in values.items():
            if not key.startswith("CMAKE_PROJECT_") or not key.endswith("_INCLUDE") or not named:
                continue
            if not Path(named).is_file():
                failures.append("{} in {} names {}, which is not there. An entry cmake never consumes is "
                                "what hid this defect the first time, so a stale one does not get to "
                                "stay".format(key, cache, named))

        sysroot = values.get("CMAKE_OSX_SYSROOT", ("", ""))[1]
        if not sysroot:
            failures.append("{} carries no CMAKE_OSX_SYSROOT, so nothing says which SDK a package would "
                            "have to escape to".format(cache))
            continue
        wanted = required()
        for key, (kind, value) in values.items():
            if kind != "PATH" or not value:
                continue
            if package_of(key) not in wanted:
                continue
            checked += 1
            if value.startswith(sysroot):
                failures.append("{} in {} resolved to {}, inside the SDK, instead of the {} this port "
                                "requires".format(key, cache, value, package_of(key)))

    for line in failures:
        print("FAIL  {}".format(line))
    if failures:
        print("{} checks failed".format(len(failures)))
        return 1
    print("ok    {} package directories across {} build tree(s) come from the graph, and every tree applies "
          "{} as CMAKE_PROJECT_{}_INCLUDE".format(checked, len(trees), include, name))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Check what dyld-imports-check refuses against a cache, slice by slice.

    tests/imports_check_test.py

A device's dyld loads the slice of a universal binary that matches its CPU, so an
arm64 slice built for a later release may import what an armv7 cache lacks. This
writes a small dyld_v1 armv7 cache whose one image exports _exported, links real
armv7 and arm64 dylibs that import it or ___divti3, and asks the checker about
each. It needs ld64 in the Conan cache for the armv7 slices.
"""
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import macho_test

HERE = Path(__file__).resolve().parent
CHECKER = HERE.parent / "recipes" / "dyld-imports-check" / "all" / "src" / "dyld-imports-check"


def cache(path, architecture, exported, installed="/usr/lib/libSystem.B.dylib"):
    strings = b"\0" + exported.encode() + b"\0"
    image, header = 0x100, 28
    symbols = image + header + 24
    table = symbols + 12
    name = table + len(strings)
    data = bytearray(name + len(installed) + 1)
    data[0:16] = "dyld_v1{:>8}".format(architecture).encode().ljust(16, b"\0")
    struct.pack_into("<IIII", data, 16, 0x40, 1, 0x60, 1)
    struct.pack_into("<QQQII", data, 0x40, 0, len(data), 0, 5, 5)
    struct.pack_into("<QQQI", data, 0x60, image, 0, 0, name)
    struct.pack_into("<IiiIIII", data, image, 0xFEEDFACE, 12, 9, 6, 1, 24, 0)
    struct.pack_into("<IIIIII", data, image + header, 0x2, 24, symbols, 1, table, len(strings))
    struct.pack_into("<IBBhI", data, symbols, 1, 0x0F, 1, 0, 0)
    data[table:name] = strings
    data[name:] = installed.encode() + b"\0"
    path.write_bytes(bytes(data))
    return path


def dylib(folder, ld64, name, target, imported):
    source = folder / "{}.c".format(name)
    source.write_text("extern int {0}(void);\nint use(void) {{ return {0}(); }}\n".format(imported[1:]))
    (folder / "libSystem.tbd").write_text(macho_test.SYSTEM_STUB.replace(
        "dyld_stub_binder", "dyld_stub_binder, _exported, ___divti3"))
    linker = ["-fuse-ld={}".format(ld64)] if target.startswith("armv7") else []
    macho_test.run("xcrun", "clang", "-target", target, "-Wno-incompatible-sysroot", *linker, "-nostdlib",
                   "-dynamiclib", "-L.", "-lSystem", "-o", "{}.dylib".format(name), source.name, cwd=folder)
    return folder / "{}.dylib".format(name)


def checked(cache_path, dist):
    return subprocess.run([sys.executable, str(CHECKER), "--cache", str(cache_path), "--dist", str(dist)],
                          capture_output=True, text=True)


def failures():
    found = []
    ld64 = macho_test.packaged("ld64/*@charon/stable", "ld")
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        armv7 = cache(folder / "dyld_shared_cache_armv7", "armv7", "_exported")
        clean = dylib(folder, ld64, "clean-armv7", "armv7-apple-ios6.0", "_exported")
        late = dylib(folder, ld64, "late-armv7", "armv7-apple-ios6.0", "___divti3")
        wide = dylib(folder, ld64, "wide-arm64", "arm64-apple-ios7.0", "___divti3")
        (folder / "libgone.tbd").write_text(macho_test.SYSTEM_STUB.replace(
            "/usr/lib/libSystem.B.dylib", "/usr/lib/libgone.dylib").replace("dyld_stub_binder", "_gone"))
        loads = dylib(folder, ld64, "loads-armv7", "armv7-apple-ios6.0", "_exported")
        loads.unlink()
        macho_test.run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot",
                       "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem", "-lgone",
                       "-o", loads.name, "loads-armv7.c", cwd=folder)
        cases = (
            ("an armv7 slice importing only what the cache exports, beside an arm64 slice importing what it does not",
             [clean, wide], None),
            ("an armv7 slice importing what the cache does not export", [late, wide], "___divti3"),
            ("a binary with no slice an armv7 device loads", [wide], "no slice a armv7 device loads"),
            ("a binary loading a library neither the device nor the build provides", [loads], "loads /usr/lib/libgone"),
        )
        for index, (description, slices, refusal) in enumerate(cases):
            dist = folder / "dist{}".format(index)
            dist.mkdir()
            macho_test.run("xcrun", "lipo", "-create", *slices, "-output", dist / "lib.dylib", cwd=folder)
            result = checked(armv7, dist)
            if refusal is None and result.returncode:
                found.append("{} must pass: {}".format(description, result.stdout + result.stderr))
            if refusal is not None and (result.returncode == 0 or refusal not in result.stdout):
                found.append("{} must be refused naming {}: {}".format(description, refusal,
                                                                       result.stdout + result.stderr))
    return found


def step_failures(ld64):
    import declaration_test
    module = declaration_test.loaded_base()
    module.ConanException = sys.modules["conan.errors"].ConanException
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        tool = folder / "tool" / "bin"
        tool.mkdir(parents=True)
        (tool / "dyld-imports-check").write_bytes(CHECKER.read_bytes())
        (tool / "dyld-imports-check").chmod(0o755)
        home = folder / "home"
        (home / "dyld").mkdir(parents=True)
        cache(home / "dyld" / "dyld_shared_cache_armv7", "armv7", "_exported")
        stage = folder / "build" / "stage" / "usr" / "lib"
        stage.mkdir(parents=True)
        dylib(folder, ld64, "clean", "armv7-apple-ios6.0", "_exported").rename(stage / "libclean.dylib")
        bundle = folder / "build" / "Host.app"
        bundle.mkdir()
        dylib(folder, ld64, "late", "armv7-apple-ios6.0", "___divti3").rename(bundle / "Host")
        instance = macho_test.running_port(module, folder, {"application": {"name": "Host"}}, "ldid")
        instance.dependencies.build = {"dyld-imports-check": type("Tool", (), {
            "package_folder": str(folder / "tool"), "ref": "dyld-imports-check/1.0"})()}
        instance.conf = declaration_test.Conf({"user.charon:home": str(home)})
        try:
            instance._check_imports()
            found.append("check:imports must refuse an application bundle importing what the held cache lacks")
        except Exception as refused:
            if "failed" not in str(refused):
                found.append("check:imports must run the checker on the bundle and fail with it: {}".format(refused))
        (bundle / "Host").unlink()
        dylib(folder, ld64, "fine", "armv7-apple-ios6.0", "_exported").rename(bundle / "Host")
        try:
            instance._check_imports()
        except Exception as refused:
            found.append("check:imports must pass a stage and bundle importing only what the held cache exports: "
                         "{}".format(refused))
        instance.conf = declaration_test.Conf({"user.charon:home": str(folder / "nowhere")})
        try:
            instance._check_imports()
            found.append("check:imports with no cache must be refused, not reported as passing")
        except module.ConanException as refused:
            if "no shared cache at" not in str(refused):
                found.append("check:imports must say where it looked for the cache: {}".format(refused))
    return found


def main():
    import declaration_test
    declaration_test.reexec_where_conan_lives(__file__)
    try:
        found = failures() + step_failures(macho_test.packaged("ld64/*@charon/stable", "ld"))
    except macho_test.Refused as missing:
        found = [str(missing)]
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    the imports checker reads the slice the cache's device loads and refuses a binary without one")
    return 0


if __name__ == "__main__":
    sys.exit(main())

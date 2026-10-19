#!/usr/bin/env python3
"""Check that an Objective-C source stays Objective-C when cmake configures again.

    tests/cmake_language_test.py

cmake decides which compiler owns .m from the order languages are enabled. With
OBJC before C, a fresh configure gives .m to the Objective-C compiler, and every
later configure - including the one ninja runs by itself after a CMakeLists
changes - hands it back to the C compiler, which drops every flag declared for
Objective-C alone. The build still succeeds. This generates a real project,
configures it fresh, configures it again, lets ninja reconfigure it, and requires
Objective-C and its flag each time. It needs cmake and ninja, and fails rather
than skipping without them.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "config" / "extensions" / "charon"))

import generate
import spec

DECLARATION = """
[platform]
use = "apple-ios"
arch = "armv7"
os-version = "6.0"

[[static-library]]
name = "objcfirst"
sources = ["src/*.m"]
[static-library.options-for]
objc = ["-fobjc-arc"]

[[static-library]]
name = "cside"
sources = ["src/*.c"]
"""


def owner(build):
    lines = (build / "build.ninja").read_text().splitlines()
    for index, line in enumerate(lines):
        if "a.m.o:" in line:
            text = line + " " + (lines[index + 1] if index + 1 < len(lines) else "")
            for language in ("OBJCXX", "OBJC", "CXX", "C"):
                if " {}_COMPILER__".format(language) in text:
                    return language
    return None


def carries_arc(build):
    commands = subprocess.run(["ninja", "-C", str(build), "-t", "commands"], capture_output=True, text=True).stdout
    return any("a.m" in line and "-fobjc-arc" in line for line in commands.splitlines())


def path_map_failures():
    found = []
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder).resolve()
        port = root / "port"
        (port / "src").mkdir(parents=True)
        (port / "src" / "a.m").write_text('const char *where_objc = __FILE__;\n')
        (port / "src" / "b.c").write_text('const char *where_c = __FILE__;\n')
        (port / spec.MANIFEST).write_text(DECLARATION)
        declared = spec.load(port)
        generated = root / "generated"
        generated.mkdir()
        (generated / "CMakeLists.txt").write_text(generate.cmake_project(declared, "static-library", "port-static"))
        (generated / "cross.cmake").write_text(generate.cross_toolchain(declared))
        sdk = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True, text=True).stdout.strip()
        build = root / "build"
        configured = subprocess.run(
            ["cmake", "-S", str(generated), "-B", str(build), "-G", "Ninja", "-DCHARON_PORT={}".format(port),
             "-DCMAKE_TOOLCHAIN_FILE={}".format(generated / "cross.cmake"), "-DCHARON_SDK={}".format(sdk),
             "-DCHARON_DEPLOYMENT_TARGET=11.0", "-DCHARON_ARCHITECTURE=arm64",
             "-DCHARON_TRIPLE=arm64-apple-macos11.0",
             "-DCHARON_PATH_MAPS=-ffile-prefix-map={}=/port".format(port)], capture_output=True, text=True)
        built = subprocess.run(["ninja", "-C", str(build)], capture_output=True, text=True)
        if configured.returncode or built.returncode:
            return ["the cross toolchain must configure and build with the platform's variables: {}".format(
                (configured.stdout + configured.stderr + built.stdout + built.stderr)[-600:])]
        texts = []
        for obj in sorted(build.rglob("*.o")):
            texts.append(subprocess.run(["strings", "-a", str(obj)], capture_output=True, text=True).stdout)
        joined = "\n".join(texts)
        for language, expected in (("Objective-C", "/port/src/a.m"), ("C", "/port/src/b.c")):
            if expected not in joined:
                found.append("a {} compile must name its source under /port: {}".format(language, expected))
        if str(port) in joined:
            found.append("no compiled object may carry the port's machine path")
    return found


def main():
    if sys.version_info < (3, 11):
        print("FAIL  this needs Python 3.11 or newer for tomllib")
        return 1
    missing = [tool for tool in ("cmake", "ninja") if shutil.which(tool) is None]
    if missing:
        print("FAIL  {} not found; skipping would report success having checked nothing".format(", ".join(missing)))
        return 1
    found = []
    with tempfile.TemporaryDirectory() as folder:
        port = Path(folder) / "port"
        (port / "src").mkdir(parents=True)
        (port / "src" / "a.m").write_text("int objc_side(void) { return 1; }\n")
        (port / "src" / "b.c").write_text("int c_side(void) { return 0; }\n")
        (port / spec.MANIFEST).write_text(DECLARATION)
        project = generate.cmake_project(spec.load(port), "static-library", "port-static")
        generated = Path(folder) / "generated"
        generated.mkdir()
        (generated / "CMakeLists.txt").write_text(project)
        build = Path(folder) / "build"
        configure = ["cmake", "-S", str(generated), "-B", str(build), "-G", "Ninja", "-DCHARON_PORT={}".format(port)]

        for stage, run in (("fresh", lambda: subprocess.run(configure, capture_output=True, text=True)),
                           ("configured again", lambda: subprocess.run(configure, capture_output=True, text=True)),
                           ("reconfigured by ninja", None)):
            if run is None:
                with open(generated / "CMakeLists.txt", "a") as handle:
                    handle.write("\n")
                done = subprocess.run(["ninja", "-C", str(build)], capture_output=True, text=True)
            else:
                done = run()
            if done.returncode:
                found.append("{}: cmake or ninja failed: {}".format(stage, (done.stdout + done.stderr)[-400:]))
                break
            language = owner(build)
            if language != "OBJC":
                found.append("{}: a.m is compiled as {}, not OBJC; project() reads {}".format(
                    stage, language, project.splitlines()[2]))
            elif not carries_arc(build):
                found.append("{}: a.m is compiled without its Objective-C flag".format(stage))

    found += path_map_failures()
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    an Objective-C source stays Objective-C, with its flags, however often cmake configures")
    return 0


if __name__ == "__main__":
    sys.exit(main())

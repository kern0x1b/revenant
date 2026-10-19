#!/usr/bin/env python3
"""Check that a port finding one package also gets the packages that one finds.

    tests/cmake_deps_test.py

A port names the packages its targets find. The config Conan writes for such a
package calls find_dependency for what its recipe requires, so a package the port
never named still needs its own config. This creates two real packages in a
scratch Conan home - middle, whose library requires a component of leaf - and a
consumer that finds middle alone through the base class's choice of packages,
then configures and links it with cmake. It needs conan, cmake and ninja, and
fails rather than skipping without them.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "recipes" / "charon-base" / "all"

LIBRARY = '''
import os
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout


class Library(ConanFile):
    name = "{name}"
    version = "1.0"
    settings = "os", "arch", "compiler", "build_type"
    exports_sources = "CMakeLists.txt", "*.c", "*.h"
    generators = "CMakeToolchain", "CMakeDeps"
    {requires}

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        CMake(self).install()

    def package_info(self):
        {info}
'''

LEAF_INFO = '''self.cpp_info.components["comp"].libs = ["leafcomp"]
        self.cpp_info.components["other"].libs = ["leafother"]'''

MIDDLE_INFO = '''self.cpp_info.libs = ["middle"]
        self.cpp_info.requires = ["leaf::comp"]'''

LEAF_CMAKE = """cmake_minimum_required(VERSION 3.20)
project(leaf C)
add_library(leafcomp STATIC comp.c)
add_library(leafother STATIC other.c)
install(TARGETS leafcomp leafother)
install(FILES leaf.h DESTINATION include)
"""

MIDDLE_CMAKE = """cmake_minimum_required(VERSION 3.20)
project(middle C)
find_package(leaf REQUIRED CONFIG)
add_library(middle STATIC middle.c)
target_link_libraries(middle PRIVATE leaf::comp)
install(TARGETS middle)
install(FILES middle.h DESTINATION include)
"""

CONSUMER = '''
from conan import ConanFile
from conan.tools.cmake import CMakeDeps, CMakeToolchain


class Consumer(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    requires = "middle/1.0"
    python_requires = "charon-base/1.0@charon/stable"

    def generate(self):
        CMakeToolchain(self).generate()
        port = self.python_requires["charon-base"].module.CharonPort
        wanted = port.configured_packages(self.dependencies.host, ["middle"])
        deps = CMakeDeps(self)
        for dependency in self.dependencies.host.values():
            if dependency.ref.name not in wanted:
                deps.set_property(dependency.ref.name, "cmake_find_mode", "none")
        deps.generate()
'''

CONSUMER_CMAKE = """cmake_minimum_required(VERSION 3.20)
project(consumer C)
find_package(middle REQUIRED CONFIG)
add_executable(consumer main.c)
target_link_libraries(consumer PRIVATE middle::middle)
"""


def write(folder, files):
    folder.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (folder / name).write_text(text)
    return folder


def run(arguments, environment, folder=None):
    return subprocess.run(arguments, capture_output=True, text=True, env=environment, cwd=folder)


def failures():
    missing = [tool for tool in ("conan", "cmake", "ninja") if not shutil.which(tool)]
    if missing:
        return ["this needs {} on PATH".format(", ".join(missing))]
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        environment = dict(os.environ, CONAN_HOME=str(root / "home"))
        environment.pop("CONAN_DEFAULT_PROFILE", None)
        steps = [
            ["conan", "profile", "detect"],
            ["conan", "export", str(BASE)],
        ]
        leaf = write(root / "leaf", {
            "conanfile.py": LIBRARY.format(name="leaf", requires="", info=LEAF_INFO),
            "CMakeLists.txt": LEAF_CMAKE,
            "leaf.h": "int leaf_comp(void);\n",
            "comp.c": "int leaf_comp(void) { return 7; }\n",
            "other.c": "int leaf_other(void) { return 8; }\n",
        })
        middle = write(root / "middle", {
            "conanfile.py": LIBRARY.format(name="middle", requires='requires = "leaf/1.0"', info=MIDDLE_INFO),
            "CMakeLists.txt": MIDDLE_CMAKE,
            "middle.h": "int middle(void);\n",
            "middle.c": "#include <leaf.h>\nint middle(void) { return leaf_comp() + 1; }\n",
        })
        consumer = write(root / "consumer", {
            "conanfile.py": CONSUMER,
            "CMakeLists.txt": CONSUMER_CMAKE,
            "main.c": "#include <middle.h>\nint main(void) { return middle() == 8 ? 0 : 1; }\n",
        })
        build = root / "consumer" / "build"
        steps += [
            ["conan", "create", str(leaf), "-c", "tools.cmake.cmaketoolchain:generator=Ninja"],
            ["conan", "create", str(middle), "-c", "tools.cmake.cmaketoolchain:generator=Ninja"],
            ["conan", "install", str(consumer), "--output-folder", str(build),
             "-c", "tools.cmake.cmaketoolchain:generator=Ninja"],
        ]
        for step in steps:
            result = run(step, environment)
            if result.returncode:
                return ["{} failed: {}".format(" ".join(step[:2]), (result.stdout + result.stderr)[-1500:])]
        if not (build / "leaf-config.cmake").is_file():
            return ["a package required by one the port finds must keep its CMake config, or the found package's "
                    "find_dependency fails: {}".format(sorted(path.name for path in build.iterdir()))]
        configured = run(["cmake", "-S", str(consumer), "-B", str(build / "tree"), "-G", "Ninja",
                          "-DCMAKE_TOOLCHAIN_FILE={}".format(build / "conan_toolchain.cmake"),
                          "-DCMAKE_BUILD_TYPE=Release"], environment)
        if configured.returncode:
            return ["a port finding only middle must configure although middle requires leaf::comp: {}".format(
                (configured.stdout + configured.stderr)[-1500:])]
        built = run(["ninja", "-C", str(build / "tree")], environment)
        if built.returncode:
            return ["a port finding only middle must link middle's own requirement: {}".format(
                (built.stdout + built.stderr)[-1500:])]
        if run([str(build / "tree" / "consumer")], environment).returncode:
            return ["the linked consumer must run and reach leaf through middle"]
    return []


def main():
    found = failures()
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    a port finding one package also gets the configs of the packages that one finds")
    return 0


if __name__ == "__main__":
    sys.exit(main())

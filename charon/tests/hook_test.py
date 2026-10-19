#!/usr/bin/env python3
"""Check what the Conan hook refuses and which machine paths it maps away.

    tests/hook_test.py

The hook reads the platform files Charon ships, so a platform that changes the
tools an architecture requires changes what the hook demands without the hook
being edited.
"""
import importlib.util
import sys
import tempfile
from pathlib import Path

import declaration_test

HERE = Path(__file__).resolve().parent
HOOK = HERE.parent / "config" / "extensions" / "hooks" / "hook_charon_target.py"


class Settings:
    def __init__(self, values):
        self._values = values

    def get_safe(self, name):
        return self._values.get(name)


class Conf:
    def __init__(self, values):
        self.values = dict(values)

    def get(self, name, default=None):
        return self.values.get(name, default)

    def append(self, name, value):
        self.values[name] = list(self.values.get(name, [])) + list(value)


class Reference:
    def __init__(self, name):
        self.name = name


class Dependency:
    def __init__(self, name, folder=None):
        self.ref = Reference(name)
        self.package_folder = folder


class Graph:
    def __init__(self, dependencies):
        self._dependencies = dependencies

    def values(self):
        return self._dependencies


class Dependencies:
    def __init__(self, host, build):
        self.host = Graph(host)
        self.build = Graph(build)


class Recipe:
    def __init__(self, name, settings, conf, host=(), build=()):
        self.name = name
        self.ref = name
        self.settings = Settings(settings)
        self.conf = Conf(conf)
        self.dependencies = Dependencies(list(host), list(build))
        self.source_folder = "/work/source"
        self.build_folder = "/work/build"


def loaded_hook():
    spec = importlib.util.spec_from_file_location("hook_under_test", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def failures(hook):
    found = []
    with tempfile.TemporaryDirectory() as folder:
        sdk = Path(folder) / "iPhoneOS16.4.sdk"
        sdk.mkdir()
        ios = {"os": "iOS", "arch": "armv7"}
        tools = [Dependency("iphoneos-sdk"), Dependency("ld64")]
        cases = (
            ("a build with the SDK and every tool its architecture needs", ios,
             {"tools.apple:sdk_path": str(sdk)}, tools, None),
            ("armv7 without ld64", ios, {"tools.apple:sdk_path": str(sdk)}, tools[:1], "ld64 is not in the build"),
            ("arm64 without ld64", {"os": "iOS", "arch": "armv8"}, {"tools.apple:sdk_path": str(sdk)}, tools[:1],
             None),
            ("no SDK", ios, {}, tools, "tools.apple:sdk_path is not set"),
            ("an SDK that is not there", ios, {"tools.apple:sdk_path": str(sdk) + "-gone"}, tools,
             "which does not exist"),
            ("a build for a system no platform describes", {"os": "Macos", "arch": "armv8"}, {}, [], None),
        )
        for description, settings, conf, build, reason in cases:
            recipe = Recipe("example", settings, conf, build=build)
            try:
                hook.pre_build(recipe)
                if reason:
                    found.append("{} must be refused".format(description))
            except Exception as refused:
                if not reason or reason not in str(refused):
                    found.append("{}: expected {}, got {}".format(description, reason or "success", refused))
        tool = Recipe("ld64", ios, {"tools.apple:sdk_path": str(sdk)}, build=[Dependency("iphoneos-sdk")])
        try:
            hook.pre_build(tool)
        except Exception as refused:
            found.append("a tool the platform requires must not need itself: {}".format(refused))

        recipe = Recipe("example", ios, {"tools.apple:sdk_path": str(sdk)},
                        host=[Dependency("openssl", "/cache/p/opens1234/p")])
        hook.pre_generate(recipe)
        flags = recipe.conf.get("tools.build:cxxflags", [])
        for expected in ("-ffile-prefix-map=/work/source=/source", "-ffile-prefix-map=/work/build=/build",
                         "-ffile-prefix-map={}=/sysroot".format(sdk),
                         "-ffile-prefix-map=/cache/p/opens1234/p=/package/openssl"):
            if expected not in flags:
                found.append("a compile must not embed this machine's paths: {} is missing from {}".format(
                    expected, flags))
        if recipe.conf.get("tools.build:cflags", []) != flags:
            found.append("C and C++ compiles must map the same paths")
    return found


def main():
    declaration_test.reexec_where_conan_lives(__file__)
    try:
        hook = loaded_hook()
    except ImportError as missing:
        print("FAIL  this needs an interpreter that can import conan: {}".format(missing))
        return 1
    found = failures(hook)
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    a build missing what its platform requires is refused, and machine paths are mapped away")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Check what the base class reads out of a baked declaration, and what it refuses.

    tests/declaration_test.py

Run it with an interpreter that can import conan, because the recipe it loads is
a Conan recipe. It fakes the parts of a conanfile the reading half touches - the
options, the settings, the configuration and the folders - so the substitution
logic is checked here rather than discovered in a multi-hour build.
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CHOSEN = "DECLARATION_TEST_INTERPRETER"

HERE = Path(__file__).resolve().parent
CORE = HERE.parent / "recipes" / "charon-base" / "all" / "conanfile.py"
APPLE = HERE.parent / "recipes" / "charon-apple" / "all" / "conanfile.py"

DECLARATION = {
    "engine": {
        "stubs": "compat/stubs",
        "prefix-header": "plain.h",
        "exports": "{source}/Source/exports.exp",
        "options": {
            "PORT": "Cocoa",
            "ENABLE_WEBGL": "ON",
            "COMPAT_LIB": "{target:compat}",
            "EXPORTS": "{exports}",
            "FLAGS": "{cxx}",
        },
    },
    "flags": {
        "common": "-target {triple} {tuning} -isysroot {sdk}",
        "defines": "-DONE -DTWO",
        "cxx": "{common} -include {stubs}/{prefix-header} {defines}",
    },
    "variants": {
        "system": {},
        "prefixed": {
            "options": ["prefixed=True"],
            "prefix-header": "prefixed.h",
            "exports": "{build}/renamed.exp",
            "engine-options": {"ENABLE_WEBGL": "OFF"},
        },
    },
    "static-library": [{"name": "compat", "cmake": "compat", "produces": "libcompat.a"}],
    "tasks": {
        "audit": {"script": "steps/audit.py", "args": "--build {build}"},
        "bare": "steps/audit.py --build {build}",
        "greet": {"shell": "echo {build}"},
        "census": {"python": "import sys\nprint(sys.argv[1:])\n", "args": "{build}"},
        "silent": {"note": "declares nothing to run"},
        "torn": {"shell": "echo one", "python": "print('two')"},
    },
    "pipeline": {"system": ["task:audit", "build:compat", "build:engine", "check:exports", "stage:frameworks"]},
}


class Options:
    def __init__(self, values):
        self._values = values

    def get_safe(self, name):
        return self._values.get(name)


class OperatingSystem:
    version = "6.0"

    def __str__(self):
        return "iOS"


class Settings:
    arch = "armv7"
    os = OperatingSystem()

    def get_safe(self, name):
        return getattr(self, name, None)


class Conf:
    def __init__(self, values):
        self._values = values

    def get(self, name, default=None, check_type=None):
        return self._values.get(name, default)


class Output:
    def title(self, line):
        pass

    def warning(self, line):
        pass


def loaded_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Recipe:
    def __init__(self, core, platform):
        object.__setattr__(self, "modules", (platform, core))
        object.__setattr__(self, "Port", type("Port", (platform.ApplePort, core.CharonPort), {}))

    def __getattr__(self, name):
        for module in self.modules:
            if hasattr(module, name):
                return getattr(module, name)
        raise AttributeError(name)

    def __setattr__(self, name, value):
        owners = [module for module in self.modules if hasattr(module, name)]
        if not owners:
            raise AttributeError(name)
        for module in owners:
            setattr(module, name, value)


def loaded_base():
    return Recipe(loaded_module("charon_base_under_test", CORE), loaded_module("charon_apple_under_test", APPLE))


def port(module, options):
    class Port(module.Port):
        declaration = DECLARATION
        port = "/port"
        name = "example"
        version = "1.0"

        def __init__(self):
            self.options = Options(options)
            self.settings = Settings()
            self.conf = Conf({"tools.apple:sdk_path": "/sdks/iPhoneOS16.4.sdk",
                              "tools.build:cxxflags": ["-mcpu=cortex-a9"]})
            self.source_folder = "/port/engine"
            self.build_folder = "/port/build/system"
            self.output = Output()
            self.ran = []
            self.commands = []
            self.folders_run_in = []
            self.dependencies = type("Dependencies", (), {"host": {}, "build": {}})()

        def run(self, command, cwd=None):
            self.commands.append(command)
            self.folders_run_in.append(cwd)

        def _run_task(self, name):
            self.ran.append("task:" + name)

        def _build_target(self, name):
            self.ran.append("build:" + name)

        def _run_check(self, name):
            self.ran.append("check:" + name)

        def _run_stage(self, name):
            self.ran.append("stage:" + name)

        def _sign_target(self, name):
            self.ran.append("sign:" + name)

    return Port()


def merge_failures(module):
    import plistlib
    found = []
    baked = port(module, {"prefixed": "True"})
    type(baked).declaration = dict(DECLARATION, **{"for-variant": "system"})
    if baked.declared_variant() != "system":
        found.append("a recipe written for a variant must be that variant, whatever its options say")

    def slice_bundle(root, name, arch_magic, plist, extra=None):
        bundle = root / name / "Host.app"
        (bundle / "Frameworks").mkdir(parents=True)
        (bundle / "Host").write_bytes(arch_magic + b"\0" * 60)
        (bundle / "Frameworks" / "libx.dylib").write_bytes(arch_magic + b"\0" * 60)
        (bundle / "start.html").write_text("same everywhere")
        with open(bundle / "Info.plist", "wb") as handle:
            plistlib.dump(plist, handle)
        for relative, content in (extra or {}).items():
            (bundle / relative).parent.mkdir(parents=True, exist_ok=True)
            (bundle / relative).write_bytes(content)
        return str(bundle)

    thin, wide = b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe"
    cases = (
        ("slices that agree", {}, {}, {}, ["Frameworks/libx.dylib", "Host"], []),
        ("a file only one slice has", {}, {}, {"extra.txt": b"x"}, None, ["present in only some slices"]),
        ("Info.plist keys that disagree", {"MinimumOSVersion": "6.0"}, {"MinimumOSVersion": "7.0"}, {}, None,
         ["Info.plist differs", "MinimumOSVersion (armv7: '6.0', arm64: '7.0')", "pin it in plist-file"]),
        ("a binary in one slice and data in the other", {}, {}, {"Frameworks/liby.dylib": wide + b"\0" * 8},
         None, None),
    )
    for description, first_plist, second_plist, second_extra, binaries, reasons in cases:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            extra_first = {"Frameworks/liby.dylib": b"plain data"} if description.startswith("a binary") else {}
            bundles = [slice_bundle(root, "armv7", thin, dict({"CFBundleExecutable": "Host"}, **first_plist),
                                    extra_first),
                       slice_bundle(root, "arm64", wide, dict({"CFBundleExecutable": "Host"}, **second_plist),
                                    second_extra)]
            planned, problems = module.MachO.merge_plan(bundles)
            if binaries is not None:
                if problems or planned != binaries:
                    found.append("{}: must merge {} with no problem, got {} and {}".format(
                        description, binaries, planned, problems))
                continue
            if not problems:
                found.append("{} must be refused".format(description))
            for reason in reasons or ["Mach-O in some slices and not in others"]:
                if not any(reason in problem for problem in problems):
                    found.append("{} must be refused because {}: got {}".format(description, reason, problems))
    return found


def architecture_failures(module):
    found = []
    instance = port(module, {"prefixed": "False"})
    instance.settings = type("Wide", (Settings,), {"arch": "armv8"})()
    instance.settings.os = type("Seven", (OperatingSystem,), {"version": "7.0"})()
    if instance.triple != "arm64-apple-ios7.0":
        found.append("an armv8 build must target arm64-apple-ios7.0, the name clang knows: got {}".format(
            instance.triple))
    instance.generators_folder = "/port/build/generators"
    instance._verify_inputs = lambda folder: None
    with tempfile.TemporaryDirectory() as recipe:
        (Path(recipe) / "cross-toolchain.cmake").write_text("set(CMAKE_SYSTEM_NAME iOS)\n")
        instance.recipe_folder = recipe
        instance._cmake_project("/port/app", "/port/build/app", {})
    configured = instance.commands[0]
    for expected in ('-DCHARON_ARCHITECTURE="arm64"', '-DCHARON_TRIPLE="arm64-apple-ios7.0"'):
        if expected not in configured:
            found.append("a generated project must be configured with {}: {}".format(expected, configured))
    sparc = port(module, {"prefixed": "False"})
    sparc.settings = type("Sparc", (Settings,), {"arch": "sparc"})()
    try:
        sparc.triple
        found.append("an architecture the Apple tools have no name for must be refused")
    except Exception as refused:
        if "have a name for" not in str(refused):
            found.append("an unknown architecture must be refused for that reason: {}".format(refused))
    return found


class Library:
    def __init__(self, name, libs, file_name=None):
        self.ref = type("Reference", (), {"name": name})()
        self.package_folder = "/cache/{}/p".format(name)
        self.cpp_info = self
        self._libs = libs
        self._file_name = file_name
        self.cflags = []
        self.cxxflags = []
        self.components = {}

    def get_property(self, name):
        return self._file_name if name == "cmake_file_name" else None

    def aggregated_components(self):
        return type("Components", (), {"libs": self._libs})()


class FlagOwner:
    def __init__(self, cflags=(), cxxflags=(), components=None, target=None):
        self.cflags = list(cflags)
        self.cxxflags = list(cxxflags)
        self.components = components or {}
        self._target = target

    def get_property(self, name):
        return self._target if name == "cmake_target_name" else None


def objective_c_failures(module):
    import subprocess
    found = []
    info = FlagOwner(cflags=["-DFROM_PACKAGE_C_FLAGS"], cxxflags=["-includealgorithm"],
                     components={"shim": FlagOwner(cflags=["-DFROM_COMPONENT"])})
    lines = module.Port._objective_c_options("pkg", info)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        (root / "options.cmake").write_text("\n".join(lines) + "\n")
        (root / "a.m").write_text("#ifndef FROM_PACKAGE_C_FLAGS\n#error package C flags missing\n#endif\n"
                                  "#ifndef FROM_COMPONENT\n#error component C flags missing\n#endif\nint a;\n")
        (root / "b.mm").write_text("void fill(int *p) { std::fill(p, p + 1, 0); }\n")
        (root / "CMakeLists.txt").write_text(
            "cmake_minimum_required(VERSION 3.24)\nproject(consumer C CXX OBJC OBJCXX)\n"
            "add_library(pkg::pkg INTERFACE IMPORTED)\nadd_library(pkg::shim INTERFACE IMPORTED)\n"
            "target_link_libraries(pkg::pkg INTERFACE pkg::shim)\n"
            "set_property(TARGET pkg::pkg PROPERTY INTERFACE_COMPILE_OPTIONS "
            "\"$<$<COMPILE_LANGUAGE:CXX>:-includealgorithm>\")\n"
            "include(options.cmake)\nadd_library(consumer STATIC a.m b.mm)\n"
            "target_link_libraries(consumer PRIVATE pkg::pkg)\n")
        configured = subprocess.run(["cmake", "-S", str(root), "-B", str(root / "build"), "-G", "Ninja"],
                                    capture_output=True, text=True)
        built = subprocess.run(["ninja", "-C", str(root / "build")], capture_output=True, text=True)
        if configured.returncode or built.returncode:
            found.append("a package's C and C++ flags must reach Objective-C and Objective-C++ consumers: {}".format(
                (configured.stderr + built.stdout + built.stderr)[-600:]))
    return found


def path_map_failures(module):
    instance = port(module, {"prefixed": "False"})
    instance.conf = Conf({"tools.build:cflags": ["-mcpu=cortex-a9", "-ffile-prefix-map=/port/build/system=/build",
                                                 "-ffile-prefix-map=/cache/p/opens1234/p=/package/openssl"]})
    maps = instance.path_maps()
    expected = ["-ffile-prefix-map=/cache/p/opens1234/p=/package/openssl", "-ffile-prefix-map=/port/build/system=/build",
                "-ffile-prefix-map=/port=/port"]
    if maps != expected:
        return ["path maps must carry the hook's maps and the port, longest folder first, because clang applies the "
                "first that matches: got {}".format(maps)]
    return []


def graph_failures(module):
    found = []
    host = [Library("openssl", ["ssl", "crypto"], "OpenSSL"), Library("ogg", ["ogg"])]
    dependencies = type("Dependencies", (), {"host": {library.ref.name: library for library in host}, "build": {}})()
    with tempfile.TemporaryDirectory() as folder:
        instance = port(module, {"prefixed": "False"})
        instance.dependencies = dependencies
        instance.generators_folder = folder
        type(instance).declaration = dict(DECLARATION, application={"name": "Host", "packages": ["openssl", "ogg"]})
        instance._write_found_packages()
        written = (Path(folder) / module.Port.FOUND_PACKAGES).read_text().splitlines()
        if written != ["find_package(OpenSSL REQUIRED CONFIG)", "find_package(ogg REQUIRED CONFIG)"]:
            found.append("a package must be found under the file name its recipe gives CMake, or its own name: "
                         "got {}".format(written))
        type(instance).declaration = dict(DECLARATION, application={"name": "Host", "packages": ["zlib"]})
        try:
            instance._write_found_packages()
            found.append("finding a package the port does not require must be refused")
        except Exception as refused:
            if "does not require" not in str(refused):
                found.append("a package the port does not require must be refused for that: {}".format(refused))
    for application, reason in (({"name": "Host", "libraries": ["crypto"]}, "links crypto by name"),
                                ({"name": "Host", "link-options": ["-L/cache/ogg/p/lib"]}, "searches ogg's package"),
                                ({"name": "Host", "libraries": ["z", "OpenSSL::Crypto"],
                                  "link-options": ["-L/usr/lib"]}, None)):
        instance = port(module, {"prefixed": "False"})
        instance.dependencies = dependencies
        type(instance).declaration = dict(DECLARATION, application=application)
        instance._declared_context = lambda: {}
        try:
            instance._refuse_graph_by_hand()
            if reason:
                found.append("{} must be refused".format(application))
        except Exception as refused:
            if not reason or reason not in str(refused):
                found.append("{}: expected {}, got {}".format(application, reason or "success", refused))
    return found


def exports_failures(module):
    instance = port(module, {"prefixed": "False"})
    type(instance).declaration = dict(DECLARATION, engine=dict(DECLARATION["engine"]))
    try:
        instance._check_exports()
        return ["check:exports with no exports-binary must be refused"]
    except Exception as refused:
        if "exports-binary" not in str(refused):
            return ["check:exports must be refused for naming no binary, not for something else: {}".format(refused)]
    return []


def find_package_failures(module):
    sys.path.insert(0, str(HERE.parent / "config" / "extensions" / "charon"))
    import generate
    import spec
    found = []
    declaration = {
        "platform": {"use": "apple-ios", "arch": "armv7", "os-version": "6.0"},
        "engine": {"find-packages": ["icu"]},
        "static-library": [{"name": "compat", "sources": ["a.c"], "packages": ["zlib"]}],
        "device-library": [{"name": "tweak", "sources": ["t.m"], "install": "/usr/lib", "packages": ["openssl", "zlib"]}],
        "application": {"name": "Host", "sources": ["main.m"], "packages": ["libcxx"]},
    }
    with tempfile.TemporaryDirectory() as folder:
        for name in ("a.c", "t.m", "main.m"):
            (Path(folder) / name).write_text("")
        declared = spec.Spec(Path(folder), declaration)
        written = generate.written(declared)
        generated = {line.split("(")[1].split()[0] for text in written.values()
                     for line in text.splitlines() if line.startswith("find_package(")}
    instance = port(module, {"prefixed": "False"})
    type(instance).declaration = declaration
    kept = set(instance.declared_find_packages())
    if generated - kept:
        found.append("every package a generated project finds must keep its CMake config, or configure fails "
                     "looking for it: {} are found and not kept".format(sorted(generated - kept)))
    if "icu" not in kept:
        found.append("[engine] find-packages must still keep its packages: kept {}".format(sorted(kept)))
    return found


def runtime_failures(module):
    from types import SimpleNamespace
    found = []
    looked_up = []

    def components(name):
        looked_up.append(name)
        return SimpleNamespace(libdirs=["/packages/{}/lib".format(name)])

    plain = port(module, {"prefixed": "False"})
    plain._components = components
    if plain.declared_runtime() != (None, {}) or looked_up:
        found.append("a port that ships no runtime must not look for a runtime package: looked up {}".format(
            looked_up))

    runtime = {"libc++.1.0.dylib": "librev-c++.1.dylib"}
    unnamed = port(module, {"prefixed": "False"})
    type(unnamed).declaration = dict(DECLARATION, stage={"runtime": runtime})
    unnamed._components = components
    try:
        unnamed.declared_runtime()
        found.append("a runtime that names no package to come from must be refused")
    except Exception as refused:
        if "runtime-from" not in str(refused):
            found.append("a runtime with no package must be refused for that reason: got {}".format(refused))

    named = port(module, {"prefixed": "False"})
    type(named).declaration = dict(DECLARATION, stage={"runtime": runtime, "runtime-from": "somecxx"})
    named._components = components
    if named.declared_runtime() != ("/packages/somecxx/lib", runtime):
        found.append("the runtime must come from the package runtime-from names: got {}".format(
            named.declared_runtime()))
    return found


def flag_failures(module):
    found = []
    engine = port(module, {"prefixed": "False"})
    variables = engine.declared_flag_variables()
    if set(variables) != {"CMAKE_CXX_FLAGS"}:
        found.append("only the flag sets a port declares may become cache variables: got {}".format(sorted(variables)))
    application = port(module, {"prefixed": "False"})
    type(application).declaration = dict(DECLARATION, flags={})
    try:
        if application.declared_flag_variables():
            found.append("a port that declares no flags must set no flag variable, not an empty one, which would "
                         "replace the cross toolchain's -target and -isysroot")
    except Exception as refused:
        found.append("a port that declares no flags must build without them: got {}".format(refused))
    return found


def plist_failures(module):
    import plistlib
    found = []
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        with open(root / "Info.plist", "wb") as handle:
            plistlib.dump({"CFBundleExecutable": "Host", "CFBundleVersion": "1.16.48", "MinimumOSVersion": "6.0",
                           "CFBundleIdentifier": "from.file", "UIRequiredDeviceCapabilities": ["armv7"]}, handle)
        with open(root / "Wrong.plist", "wb") as handle:
            plistlib.dump({"CFBundleExecutable": "Other"}, handle)
        instance = port(module, {"prefixed": "False"})
        type(instance).port = str(root)

        info = instance._application_plist("Host", {"plist-file": "Info.plist",
                                                    "plist": {"CFBundleIdentifier": "from.table"}})
        for key, expected, why in (
                ("CFBundleVersion", "1.16.48", "a key the file sets must win over the derived one"),
                ("CFBundleIdentifier", "from.table", "the declared table must win over the file"),
                ("UIRequiredDeviceCapabilities", ["armv7"], "a key only the file has must be kept"),
                ("CFBundleName", "Host", "a key neither sets must be derived")):
            if info.get(key) != expected:
                found.append("{}: {} is {!r}".format(why, key, info.get(key)))

        plain = instance._application_plist("Host", {"plist": {"CFBundleIdentifier": "x"}})
        if plain.get("CFBundleVersion") != "1.0" or plain.get("MinimumOSVersion") != "6.0":
            found.append("with no file, the version and minimum OS must still be derived: got {}".format(plain))

        for declared, why in (({"plist-file": "Wrong.plist"}, "a file naming another executable"),
                              ({"plist-file": "Absent.plist"}, "a plist-file that is not there")):
            try:
                instance._application_plist("Host", declared)
                found.append("{} must be refused".format(why))
            except Exception:
                pass
    return found


def bundle_failures(module):
    found = []
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        packages = root / "build" / "packages"
        packages.mkdir(parents=True)
        (packages / "libthin.dylib").write_bytes(b"\xce\xfa\xed\xfe" + b"\0" * 60)
        (packages / "libwide.dylib").write_bytes(b"\xcf\xfa\xed\xfe" + b"\0" * 60)
        (packages / "notes.txt").write_text("not a binary")
        bundle = root / "Host.app"
        bundle.mkdir()
        instance = port(module, {"prefixed": "False"})
        instance.build_folder = str(root / "build")

        carried = instance._declared_bundle(str(bundle), {"name": "Host", "bundle": [
            {"from": "{build}/packages/libthin.dylib"},
            {"from": "{build}/packages/libwide.dylib"},
            {"from": "{build}/packages/notes.txt", "into": "Resources"}]})
        expected = {str(bundle / "Frameworks" / "libthin.dylib"): "@executable_path/Frameworks/libthin.dylib",
                    str(bundle / "Frameworks" / "libwide.dylib"): "@executable_path/Frameworks/libwide.dylib"}
        if carried != expected:
            found.append("bundled binaries, 32-bit and 64-bit alike, must get an identity inside the bundle, and "
                         "nothing else must: got {}".format(carried))
        if not (bundle / "Resources" / "notes.txt").is_file():
            found.append("a bundled file must land where into says")

        for entries, why, reason in (
                ([{"from": "{build}/packages/absent.dylib"}], "bundling a file that is not there", "no such file"),
                ([{"into": "Frameworks"}], "a bundle entry with no from", "table with from")):
            try:
                instance._declared_bundle(str(bundle), {"name": "Host", "bundle": entries})
                found.append("{} must be refused".format(why))
            except Exception as refused:
                if reason not in str(refused):
                    found.append("{} must be refused for that reason, not another: got {}".format(why, refused))
    return found


def sign_failures(module):
    found = []
    merged = {"system": {}, "universal": {"merge": ["system"]}}
    cases = (
        ("an application built and never signed", {"system": {}}, ["build:application"], True),
        ("an application signed after a task that may change it", {"system": {}},
         ["build:application", "task:audit", "sign:application"], False),
        ("a bundle rebuilt after it was signed", {"system": {}},
         ["build:application", "sign:application", "build:application"], True),
        ("a slice another variant merges, left unsigned", merged, ["build:application", "task:audit"], False),
        ("a slice another variant merges, signed on its own", merged,
         ["build:application", "sign:application"], True),
    )
    for description, variants, steps, refuse in cases:
        instance = port(module, {"prefixed": "False"})
        type(instance).declaration = dict(DECLARATION, variants=variants, pipeline={"system": steps})
        try:
            instance.declared_pipeline()
            if refuse:
                found.append("{} must be refused".format(description))
        except Exception as refused:
            if not refuse:
                found.append("{} must be accepted: got {}".format(description, refused))
    return found


def dispatch_failures(module):
    found = []
    recorder = port(module, {"prefixed": "False"})
    with tempfile.TemporaryDirectory() as built:
        recorder.build_folder = built
        recorder.declared_build()
        if not (Path(built) / module.Port.BUILT).is_file():
            found.append("a whole pipeline that finishes must leave the mark charon package looks for")
    if recorder.ran != DECLARATION["pipeline"]["system"]:
        found.append("the steps must run in the order declared: got {}".format(recorder.ran))

    chosen = port(module, {"prefixed": "False"})
    chosen.conf = Conf(dict(chosen.conf._values,
                            **{"user.charon:steps": ["task:greet", "check:exports", "sign:application"]}))
    with tempfile.TemporaryDirectory() as built:
        chosen.build_folder = built
        (Path(built) / module.Port.BUILT).write_text("")
        chosen.declared_build()
        if not (Path(built) / module.Port.BUILT).is_file():
            found.append("steps run on their own must leave the last whole build's mark alone")
    if chosen.ran != ["task:greet", "check:exports", "sign:application"]:
        found.append("steps named on the command line must run instead of the pipeline, and only them: "
                     "got {}".format(chosen.ran))

    try:
        recorder._run_step("nonsense", "x")
        found.append("an unknown kind of step must be refused")
    except Exception:
        pass

    prefixed = port(module, {"prefixed": "True"})
    try:
        prefixed.declared_pipeline()
        found.append("a variant with no declared pipeline must be refused, not run as nothing")
    except Exception:
        pass

    real = port(module, {"prefixed": "False"})
    for method, argument, what in ((module.Port._run_task, "absent", "an undeclared task"),
                                   (module.Port._run_check, "absent", "an unknown check"),
                                   (module.Port._run_stage, "absent", "an unknown staging step")):
        try:
            method(real, argument)
            found.append("{} must be refused".format(what))
        except Exception:
            pass
    return found


def failures(module):
    found = []
    plain, prefixed = port(module, {"prefixed": "False"}), port(module, {"prefixed": "True"})

    if plain.declared_variant() != "system":
        found.append("a build with no options set must be the variant that declares none")
    if prefixed.declared_variant() != "prefixed":
        found.append("a build whose options match a variant must be that variant")

    if plain.declared_setting("engine", "prefix-header") != "plain.h":
        found.append("a setting not overridden must come from the section")
    if prefixed.declared_setting("engine", "prefix-header") != "prefixed.h":
        found.append("a variant must override the section")

    flags = plain.declared_flags("cxx")
    for expected in ("-target armv7-apple-ios6.0", "-mcpu=cortex-a9", "-isysroot /sdks/iPhoneOS16.4.sdk",
                     "-include /port/compat/stubs/plain.h", "-DONE -DTWO"):
        if expected not in flags:
            found.append("the flags must carry {}: got {}".format(expected, flags))
    if "{" in flags:
        found.append("no placeholder may survive in flags: {}".format(flags))

    options = plain.declared_options()
    if options.get("COMPAT_LIB") != "/port/build/system/compat/libcompat.a":
        found.append("a target reference must resolve to what that target produces: got {}".format(
            options.get("COMPAT_LIB")))
    if options.get("EXPORTS") != "/port/engine/Source/exports.exp":
        found.append("exports must resolve through the section: got {}".format(options.get("EXPORTS")))
    if options.get("ENABLE_WEBGL") != "ON":
        found.append("an option not overridden must keep the declared value")
    if prefixed.declared_options().get("ENABLE_WEBGL") != "OFF":
        found.append("a variant must override an engine option")
    if prefixed.declared_options().get("EXPORTS") != "/port/build/system/renamed.exp":
        found.append("a variant must override where the exports come from: got {}".format(
            prefixed.declared_options().get("EXPORTS")))

    try:
        plain._target_product("absent")
        found.append("an unknown target must be refused")
    except Exception:
        pass

    try:
        plain.declared_flags("nonexistent")
        found.append("flags that were never declared must be refused")
    except Exception:
        pass

    bare = port(module, {"prefixed": "False"})
    type(bare).declaration = {}
    try:
        bare.declared
        found.append("a recipe with no declaration must be refused")
    except Exception:
        pass
    type(bare).declaration = DECLARATION

    return found


def task_failures(module):
    found = []
    real = module.Port._run_task

    shell = port(module, {"prefixed": "False"})
    real(shell, "greet")
    if shell.folders_run_in != ["/port"]:
        found.append("a task must run from the port, whatever the build folder is: ran in {}".format(
            shell.folders_run_in))
    if shell._declared_context().get("port") != "/port":
        found.append("{port} must name the folder holding the declaration")
    if shell.commands != ["echo /port/build/system"]:
        found.append("a task declared as shell must run what it says, with the placeholders filled: "
                     "got {}".format(shell.commands))

    inline = port(module, {"prefixed": "False"})
    inline.build_folder = tempfile.mkdtemp()
    try:
        real(inline, "census")
        body = Path(inline.build_folder) / "charon-tasks" / "census.py"
        if not body.is_file():
            found.append("a task whose body is declared inline must be written down to be run: "
                         "{} is absent".format(body))
        elif "print(sys.argv[1:])" not in body.read_text():
            found.append("an inline body must be written as declared: got {}".format(body.read_text()))
        if not inline.commands or str(body) not in inline.commands[0]:
            found.append("an inline task must run the file it just wrote: got {}".format(inline.commands))
        elif inline.build_folder not in inline.commands[0].rsplit('"', 2)[-1]:
            found.append("an inline task must receive its declared arguments, expanded: "
                         "got {}".format(inline.commands[0]))
        if inline.folders_run_in != ["/port"]:
            found.append("an inline python task must run from the port: ran in {}".format(inline.folders_run_in))
    finally:
        shutil.rmtree(inline.build_folder, ignore_errors=True)

    with tempfile.TemporaryDirectory() as folder:
        scripted = port(module, {"prefixed": "False"})
        type(scripted).port = folder
        (Path(folder) / "steps").mkdir()
        (Path(folder) / "steps" / "audit.py").write_text("")
        real(scripted, "audit")
        if scripted.folders_run_in != [folder]:
            found.append("a script task must run from the port: ran in {}".format(scripted.folders_run_in))

    for name, why, reason in (("silent", "a task that names neither script, shell nor python", "exactly one"),
                              ("torn", "a task that says two things to run", "exactly one"),
                              ("bare", "a task written as a bare command line instead of a table", "is a table"),
                              ("audit", "a task naming a script that is not there", "does not exist")):
        instance = port(module, {"prefixed": "False"})
        try:
            real(instance, name)
            found.append("{} must be refused".format(why))
        except Exception as refused:
            if reason not in str(refused):
                found.append("{} must be refused for that reason, not for another: got {}".format(why, refused))
    return found


def conan_interpreter():
    launcher = shutil.which("conan")
    if not launcher:
        return None
    try:
        with open(launcher) as handle:
            first = handle.readline()
    except OSError:
        return None
    if not first.startswith("#!"):
        return None
    words = first[2:].strip().split()
    if not words:
        return None
    candidate = words[-1] if os.path.basename(words[0]) == "env" else words[0]
    return candidate if os.path.isabs(candidate) else shutil.which(candidate)


def reexec_where_conan_lives(script=None):
    if os.environ.get(CHOSEN):
        return
    try:
        import conan  # noqa: F401
        return
    except ImportError:
        pass
    interpreter = conan_interpreter()
    if interpreter and os.path.abspath(interpreter) != os.path.abspath(sys.executable):
        os.execve(interpreter, [interpreter, os.path.abspath(script or __file__)] + sys.argv[1:],
                  dict(os.environ, **{CHOSEN: interpreter}))


def fresh_failures(module):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        (root / "project").mkdir()
        (root / "project" / "CMakeLists.txt").write_text("cmake_minimum_required(VERSION 3.24)\nproject(p C)\n")
        (root / "recipe").mkdir()
        cross = root / "recipe" / "cross-toolchain.cmake"
        cross.write_text('set(CMAKE_C_FLAGS_INIT "${CHARON_PATH_MAPS}")\n')
        build = root / "build"
        instance = port(module, {"prefixed": "False"})
        instance.recipe_folder = str(root / "recipe")
        instance.platform_cache_variables = lambda: {}
        instance.info = []
        instance.output = type("Output", (), {"info": lambda self, text: instance.info.append(text)})()

        def maps(folder):
            instance.conf = Conf({"tools.build:cflags": ["-ffile-prefix-map={}=/package".format(folder)]})

        def configure(folder, *extra):
            inputs = ["-D{}={}".format(name, value) for name, value in instance.toolchain_inputs().items()]
            subprocess.run(["cmake", *extra, "-S", str(root / "project"), "-B", str(folder),
                            "-DCMAKE_TOOLCHAIN_FILE={}".format(cross), *inputs], capture_output=True, check=True)
            cached = (folder / "CMakeCache.txt").read_text()
            return next(line for line in cached.splitlines() if line.startswith("CMAKE_C_FLAGS:"))

        maps("/first")
        if instance.fresh_configure(str(build)):
            found.append("a folder never configured needs no --fresh")
        configure(build)
        configure(root / "kept")
        if instance.fresh_configure(str(build)):
            found.append("a folder configured with the same toolchain inputs must not be configured fresh")
        maps("/second")
        decided = instance.fresh_configure(str(build))
        if decided != ["--fresh"] or "CHARON_PATH_MAPS" not in " ".join(instance.info):
            found.append("changed path maps must configure fresh, naming what changed: {} {}".format(
                decided, instance.info))
        if "/first" not in configure(root / "kept"):
            found.append("cmake is expected to keep the flags it first derived; if it stopped, this check is moot")
        if "/second" not in configure(build, *decided):
            found.append("a fresh configure must derive the flags from the new inputs")
        if instance.fresh_configure(str(build)):
            found.append("after a fresh configure the same inputs must not configure fresh again")
        cross.write_text('set(CMAKE_C_FLAGS_INIT "-DCHANGED ${CHARON_PATH_MAPS}")\n')
        if instance.fresh_configure(str(build)) != ["--fresh"]:
            found.append("a changed cross toolchain must configure fresh")
    return found


def altered_package_failures(module):
    from conan.internal.model.manifest import FileTreeManifest
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        package = Path(scratch) / "p"
        (package / "include" / "unicode").mkdir(parents=True)
        (package / "include" / "unicode" / "uvernum.h").write_text("#define U_ICU_VERSION \"78.3\"\n")
        (package / "lib").mkdir()
        (package / "lib" / "libicuuc.a").write_bytes(b"!<arch>\n")
        (package / "lib" / "libicu.a").symlink_to("libicuuc.a")
        (package / "conaninfo.txt").write_text("[settings]\n")
        FileTreeManifest.create(str(package)).save(str(package))
        instance = port(module, {"prefixed": "False"})
        dependency = type("Dependency", (), {"package_folder": str(package), "ref": "icu/78.3"})()
        instance.dependencies = type("Dependencies", (), {"host": {"icu": dependency}, "build": {}})()
        if instance.altered_packages():
            found.append("an untouched package must pass: {}".format(instance.altered_packages()))
        (package / "include" / "unicode" / "uvernum.h").write_text("#define U_ICU_VERSION \"74.2\"\n")
        altered = instance.altered_packages()
        if len(altered) != 1 or "icu/78.3" not in altered[0] or "include/unicode/uvernum.h" not in altered[0]:
            found.append("a header a build rewrote in a package must be named: {}".format(altered))
        (package / "include" / "unicode" / "uvernum.h").write_text("#define U_ICU_VERSION \"78.3\"\n")
        (package / "include" / "unicode" / "extra.h").write_text("")
        altered = instance.altered_packages()
        if len(altered) != 1 or "include/unicode/extra.h" not in altered[0]:
            found.append("a file a build added to a package must be named: {}".format(altered))
    return found


def stage_reinstall_failures(module):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        stage = root / "build" / "stage" / "Library"
        stage.mkdir(parents=True)
        staged = stage / "tweak.dylib"
        staged.write_text("stripped and signed last time")
        outside = root / "elsewhere.dylib"
        outside.write_text("not ours")
        project = root / "build" / "device-library"
        project.mkdir(parents=True)
        (project / "install_manifest.txt").write_text("{}\n{}\n".format(staged, outside))
        instance = port(module, {"prefixed": "False"})
        instance.build_folder = str(root / "build")
        instance._install_into_stage(str(project))
        if staged.exists():
            found.append("a file the last install put in the stage must be removed before installing again, or "
                         "cmake keeps the stripped and signed copy as up to date")
        if not outside.exists():
            found.append("only files inside the stage may be removed before an install")
        if not instance.commands or "cmake --install" not in instance.commands[-1]:
            found.append("the install must still run: {}".format(instance.commands))
    return found


def main():
    reexec_where_conan_lives()
    try:
        module = loaded_base()
    except ImportError as missing:
        print("FAIL  this needs an interpreter that can import conan: {}".format(missing))
        return 1
    found = (failures(module) + dispatch_failures(module) + task_failures(module) + sign_failures(module) +
             plist_failures(module) + bundle_failures(module) + merge_failures(module) + flag_failures(module) + runtime_failures(module) +
             find_package_failures(module) + exports_failures(module) + architecture_failures(module) +
             graph_failures(module) + path_map_failures(module) +
             objective_c_failures(module) + fresh_failures(module) + altered_package_failures(module) + stage_reinstall_failures(module))
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    the base class reads a declaration, resolves what the build knows and refuses the rest")
    return 0


if __name__ == "__main__":
    sys.exit(main())

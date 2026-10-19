#!/usr/bin/env python3
"""Check the Mach-O invariants against binaries real linkers produce.

    tests/macho_test.py

Run it after the ld64 and ldid packages are in the Conan cache. The same object
is linked by ld64, which keeps each function pointer's Thumb bit, and then
edited the ways a linker or a post-link tool gets it wrong, so every refusal is
proven against the defect it names rather than against a hand-written file.
The steps that produce a binary are then run with those files, to show the
invariants are applied there and before anything strips or signs.
"""
import json
import os
import plistlib
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import declaration_test

MODES = """
__attribute__((target("arm"))) int in_arm(int x) { return x + 1; }
__attribute__((target("thumb"))) int in_thumb(int x) { return x + 2; }
int (*table[])(int) = { in_arm, in_thumb };
int start(void) { return table[0](1) + table[1](1); }
"""

SYSTEM_STUB = """--- !tapi-tbd
tbd-version: 4
targets: [ armv7-ios, arm64-ios ]
install-name: '/usr/lib/libSystem.B.dylib'
exports:
  - targets: [ armv7-ios, arm64-ios ]
    symbols: [ dyld_stub_binder ]
...
"""


class Refused(Exception):
    pass


def packaged(reference, tool):
    listed = subprocess.run(["conan", "list", reference + "#*:*", "--format=json"],
                            capture_output=True, text=True)
    cache = json.loads(listed.stdout or "{}").get("Local Cache") or {}
    for recipe, described in cache.items():
        for revision, packages in described.get("revisions", {}).items():
            for package in packages.get("packages", {}):
                folder = subprocess.run(["conan", "cache", "path", "{}#{}:{}".format(recipe, revision, package)],
                                        capture_output=True, text=True).stdout.strip()
                candidate = Path(folder) / "bin" / tool
                if candidate.is_file():
                    return candidate
    raise Refused("{} has no package with bin/{} in the Conan cache; build it before this test".format(reference, tool))


def run(*command, cwd):
    finished = subprocess.run([str(part) for part in command], cwd=cwd, capture_output=True, text=True)
    if finished.returncode != 0:
        raise Refused("{} failed: {}".format(" ".join(str(part) for part in command), finished.stderr.strip()))
    return finished.stdout


def link(folder, linker, output, target, *extra):
    run("xcrun", "clang", "-target", target, "-Wno-incompatible-sysroot", "-fuse-ld={}".format(linker),
        "-nostdlib", "-L.", "-lSystem", *extra, "-o", output, "modes.c" if "arm64" not in target else "entry.c",
        cwd=folder)
    return folder / output


def section_offset(folder, binary, segment, section):
    listing = run("xcrun", "otool", "-l", binary, cwd=folder).split("Section")
    for block in listing:
        words = block.split()
        if "sectname" in words and words[words.index("sectname") + 1] == section \
                and words[words.index("segname") + 1] == segment:
            return int(words[words.index("offset") + 1])
    raise Refused("{} has no {},{}".format(binary, segment, section))


def edited(source, destination, position, value):
    shutil.copy2(source, destination)
    with open(destination, "r+b") as handle:
        handle.seek(position)
        handle.write(struct.pack("<I", value))
    return destination


def slot(path, position):
    with open(path, "rb") as handle:
        handle.seek(position)
        return struct.unpack("<I", handle.read(4))[0]


def fixtures(folder, ld64):
    (folder / "modes.c").write_text(MODES)
    (folder / "entry.c").write_text("int start(void) { return 0; }\n")
    (folder / "libSystem.tbd").write_text(SYSTEM_STUB)
    made = {
        "library": link(folder, ld64, "libmodes.dylib", "armv7-apple-ios6.0", "-dynamiclib"),
        "classic": link(folder, ld64, "libclassic.dylib", "armv7-apple-ios3.0", "-dynamiclib"),
        "executable": link(folder, ld64, "modes", "armv7-apple-ios6.0", "-Wl,-e,_start"),
        "arm64": link(folder, "ld", "wide", "arm64-apple-ios7.0", "-Wl,-e,_start"),
        "arm64-small-pagezero": link(folder, "ld", "narrow", "arm64-apple-ios7.0", "-Wl,-e,_start",
                                     "-Wl,-pagezero_size,0x1000"),
    }
    table = section_offset(folder, "libmodes.dylib", "__DATA", "__data")
    arm, thumb = slot(made["library"], table), slot(made["library"], table + 4)
    made["arm-with-thumb-bit"] = edited(made["library"], folder / "libarmbit.dylib", table, arm | 1)
    made["thumb-without-bit"] = edited(made["library"], folder / "libnobit.dylib", table + 4, thumb & ~1)
    classic = section_offset(folder, "libclassic.dylib", "__DATA", "__data")
    made["classic-thumb-without-bit"] = edited(made["classic"], folder / "libclassicnobit.dylib", classic + 4,
                                               slot(made["classic"], classic + 4) & ~1)
    data = made["executable"].read_bytes()
    zero = data.index(b"__PAGEZERO\0")
    made["armv7-pagezero-gap"] = edited(made["executable"], folder / "gapped", zero + 20, 0x1000)
    made["fat-with-thumb-without-bit"] = folder / "fat.dylib"
    wide_library = link(folder, "ld", "libwide.dylib", "arm64-apple-ios7.0", "-dynamiclib")
    run("xcrun", "lipo", "-create", made["thumb-without-bit"], wide_library, "-output", "fat.dylib", cwd=folder)
    made["fat-arm64-small-pagezero"] = folder / "fat-narrow"
    run("xcrun", "lipo", "-create", made["executable"], made["arm64-small-pagezero"], "-output", "fat-narrow",
        cwd=folder)
    return made, (arm, thumb)


def invariant_failures(module, made, pointers):
    found = []
    arm, thumb = pointers
    if arm & 1 or not thumb & 1:
        return ["ld64 must link the ARM pointer without bit 0 and the Thumb pointer with it, or nothing below "
                "means anything: got {:#x} and {:#x}".format(arm, thumb)]
    expectations = (
        ("library", [], 2),
        ("classic", [], 2),
        ("executable", [], 2),
        ("arm-with-thumb-bit", ["ARM function _in_arm has bit 0 set"], 2),
        ("thumb-without-bit", ["Thumb function _in_thumb lacks bit 0"], 2),
        ("classic-thumb-without-bit", ["Thumb function _in_thumb lacks bit 0"], 2),
        ("fat-with-thumb-without-bit", ["Thumb function _in_thumb lacks bit 0"], 2),
    )
    for name, reasons, checked in expectations:
        problems, counted, into_code = module.MachO.interworking_problems(str(made[name]))
        if into_code != checked:
            found.append("{}: {} rebased pointers lead into code, counted {}".format(name, checked, into_code))
        if counted != checked:
            found.append("{}: {} pointers must be compared with their functions, got {}".format(name, checked, counted))
        if len(problems) != len(reasons) or any(reason not in problem for reason, problem in zip(reasons, problems)):
            found.append("{}: expected {}, got {}".format(name, reasons or "nothing", problems))
    for name, reason in (("executable", None), ("arm64", None), ("library", None),
                         ("arm64-small-pagezero", "arm64 __PAGEZERO is 0x4000"),
                         ("fat-arm64-small-pagezero", "arm64 __PAGEZERO is 0x4000"),
                         ("armv7-pagezero-gap", "__PAGEZERO ends at 0x1000 and __TEXT starts at 0x4000")):
        problems = module.MachO.pagezero_problems(str(made[name]))
        if (reason is None and problems) or (reason and (len(problems) != 1 or reason not in problems[0])):
            found.append("{}: pagezero expected {}, got {}".format(name, reason or "nothing", problems))
    return found


class Output:
    def __init__(self):
        self.lines = []

    def title(self, line):
        pass

    def info(self, line):
        self.lines.append(line)

    def warning(self, line):
        self.lines.append(line)


def running_port(module, folder, declaration, ldid):
    instance = declaration_test.port(module, {"prefixed": "False"})
    kind = type(instance)
    kind.declaration = declaration
    kind.port = str(folder)
    instance.build_folder = str(folder / "build")
    (folder / "recipe").mkdir(parents=True, exist_ok=True)
    (folder / "recipe" / "cross-toolchain.cmake").write_text("set(CMAKE_SYSTEM_NAME iOS)\n")
    instance.recipe_folder = str(folder / "recipe")
    instance.output = Output()
    instance.steps = []
    instance.dependencies = Dependencies([])
    instance.dependencies.build = {"ldid": type("Tool", (), {"package_folder": str(Path(ldid).parent.parent),
                                                             "ref": "ldid"})()}

    def execute(self, command, cwd=None, stdout=None, ignore_errors=False, quiet=False):
        finished = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True)
        if finished.returncode != 0 and not ignore_errors:
            raise RuntimeError("{} failed: {}".format(command, finished.stderr))
        if stdout is not None:
            stdout.write(finished.stdout)
        return finished.returncode

    kind.run = execute
    return instance


def recording_macho(module, instance):
    class Recording(module.MachO):
        def tool(self, name):
            return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

        def strip(self, binary, arguments="-x"):
            instance.steps.append(("strip", binary))

        def sign(self, binary, entitlements=None):
            instance.steps.append(("sign", binary))

        def retarget(self, identities):
            return {os.path.basename(identity): identity for identity in identities.values()}

        def repoint(self, binary, identities):
            pass

        def references(self, binary):
            return []

        def require_compatibility_version(self, binary, expected):
            instance.steps.append(("compatibility", expected))

    return Recording


def refused_before(instance, action, reason, step, folder, module):
    try:
        action()
    except module.ConanException as refused:
        if reason not in str(refused):
            return ["{} must be refused for {}: got {}".format(step, reason, refused)]
        touched = [done for done, _ in instance.steps]
        if touched:
            return ["{} must refuse before anything strips or signs: {} ran first".format(step, touched)]
        return []
    return ["{} must refuse a binary that breaks an invariant".format(step)]


def wiring_failures(module, made, ldid):
    found = []
    original = module.MachO
    try:
        with tempfile.TemporaryDirectory() as scratch:
            folder = Path(scratch)
            (folder / "build").mkdir()
            broken = made["thumb-without-bit"]

            instance = running_port(module, folder, {"stage": {}}, ldid)
            module.MachO = recording_macho(module, instance)
            installed = folder / "build" / "installed"
            installed.mkdir()
            shutil.copy2(broken, installed / "libbroken.dylib")
            (installed / "install_manifest.txt").write_text(str(installed / "libbroken.dylib") + "\n")
            found += refused_before(instance, lambda: instance._sign_installed(str(installed)),
                                    "_in_thumb lacks bit 0", "installing a target into the stage", folder, module)

            instance = running_port(module, folder, {"stage": {"frameworks": {
                "Broken": {"as": "Broken", "replaces": "/System/Library/Frameworks/Broken.framework/Broken"}}}},
                ldid)
            module.MachO = recording_macho(module, instance)
            framework = folder / "build" / "Broken.framework"
            framework.mkdir()
            shutil.copy2(broken, framework / "Broken")
            found += refused_before(instance, instance._stage_frameworks, "_in_thumb lacks bit 0",
                                    "staging a framework", folder, module)

            instance = running_port(module, folder, {"application": {"name": "Host", "strip": "-S -x"},
                                                     "variants": {"system": {}}}, ldid)
            module.MachO = recording_macho(module, instance)
            instance._cmake_project = lambda source, into, definitions: None
            instance._project_source = lambda kind, target: str(folder)
            instance._write_application_plist = lambda bundle, name, declared: None
            installing = type(instance).run

            def install(self, command, cwd=None, stdout=None, ignore_errors=False):
                if command.startswith("cmake --install"):
                    shutil.copy2(made["armv7-pagezero-gap"], folder / "build" / "Host.app" / "Host")
                    return 0
                return installing(self, command, cwd, stdout, ignore_errors)

            type(instance).run = install
            found += refused_before(instance, instance._build_application, "__PAGEZERO ends at 0x1000",
                                    "linking the application", folder, module)

            instance = running_port(module, folder, {"application": {"name": "Host"},
                                                     "variants": {"armv7": {}, "arm64": {},
                                                                  "universal": {"merge": ["armv7", "arm64"]}}},
                                    ldid)
            module.MachO = recording_macho(module, instance)
            instance.declared_variant = lambda: "universal"
            for slice_name, binary in (("armv7", broken), ("arm64", made["arm64"])):
                bundle = folder / "build" / slice_name / "Host.app"
                bundle.mkdir(parents=True)
                shutil.copy2(binary, bundle / "Host")
            found += refused_before(instance, lambda: instance._merge_target("application"),
                                    "_in_thumb lacks bit 0", "merging the application", folder, module)
    finally:
        module.MachO = original
    with tempfile.TemporaryDirectory() as scratch:
        try:
            found += entitlement_failures(module, Path(scratch), made, ldid)
        finally:
            module.MachO = original
    return found


def runtime_reference_failures(module, made, ld64, ldid):
    found = []
    original = module.MachO
    for spelled, reason in (("/usr/lib/libc++.1.dylib", None), ("/usr/lib/libc++.dylib", "/usr/lib/libc++.dylib"),
                            ("@executable_path/Frameworks/libc++.1.dylib", None)):
        with tempfile.TemporaryDirectory() as scratch:
            folder = Path(scratch)
            packages = folder / "build" / "packages"
            packages.mkdir(parents=True)
            (folder / "libSystem.tbd").write_text(SYSTEM_STUB)
            (folder / "libcpp.tbd").write_text(SYSTEM_STUB.replace("/usr/lib/libSystem.B.dylib", spelled)
                                               .replace("dyld_stub_binder", "_runtime_marker"))
            (folder / "user.c").write_text("extern int runtime_marker; int use(void) { return runtime_marker; }\n")
            run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot",
                "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem", "-lcpp",
                "-install_name", "@rpath/libuser.dylib", "-o", packages / "libuser.dylib", "user.c", cwd=folder)
            shutil.copy2(made["library"], packages / "libc++.1.dylib")
            instance = running_port(module, folder, {"variants": {"system": {}}, "application": {
                "name": "Host", "bundle": [{"from": "{build}/packages/libc++.1.dylib"},
                                           {"from": "{build}/packages/libuser.dylib"}]}}, ldid)

            class Linking(original):
                def tool(self, name):
                    return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

                def sign(self, binary, entitlements=None):
                    pass

            module.MachO = Linking
            instance._cmake_project = lambda source, into, definitions: None
            instance._project_source = lambda kind, target: str(folder)
            instance._write_application_plist = lambda bundle, name, declared: None
            installing = type(instance).run

            def install(self, command, cwd=None, stdout=None, ignore_errors=False):
                if command.startswith("cmake --install"):
                    shutil.copy2(made["executable"], folder / "build" / "Host.app" / "Host")
                    return 0
                return installing(self, command, cwd, stdout, ignore_errors)

            type(instance).run = install
            try:
                instance._build_application()
                if reason:
                    found.append("a bundled library loading {} while the bundle carries libc++ must be refused"
                                 .format(spelled))
            except module.ConanException as refused:
                if not reason or reason not in str(refused) or "libuser.dylib" not in str(refused):
                    found.append("a bundled library loading {}: expected {}, got {}".format(
                        spelled, "refusal naming it" if reason else "the reference moved into the bundle", refused))
            finally:
                module.MachO = original
    return found


def bundle_content_failures(module, made, ldid):
    found = []
    original = module.MachO
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        framework = folder / "build" / "Engine.framework"
        for relative in ("Headers/Engine.h", "PrivateHeaders/__pycache__/tool.cpython-314.pyc", "Modules/module.modulemap",
                         "_CodeSignature/CodeResources", "en.lproj/Localizable.strings", "Info.plist"):
            (framework / relative).parent.mkdir(parents=True, exist_ok=True)
            (framework / relative).write_text("x")
        shutil.copy2(made["library"], framework / "Engine")
        instance = running_port(module, folder, {
            "variants": {"system": {}}, "application": {"name": "Host", "strip": "-x"},
            "stage": {"frameworks": {"Engine": {"as": "Engine", "replaces": "/System/Engine"}}},
            "platform-facts": {"build-only": ["Headers", "PrivateHeaders", "Modules", "_CodeSignature"]}}, ldid)
        module.MachO = recording_macho(module, instance)
        instance._cmake_project = lambda source, into, definitions: None
        instance._project_source = lambda kind, target: str(folder)
        instance._write_application_plist = lambda bundle, name, declared: None
        installing = type(instance).run

        def install(self, command, cwd=None, stdout=None, ignore_errors=False):
            if command.startswith("cmake --install"):
                shutil.copy2(made["executable"], folder / "build" / "Host.app" / "Host")
                return 0
            return installing(self, command, cwd, stdout, ignore_errors)

        type(instance).run = install
        try:
            instance._build_application()
        except module.ConanException as refused:
            found.append("an application carrying a framework must build: {}".format(refused))
        finally:
            module.MachO = original
        stripped = [Path(binary).name for action, binary in instance.steps if action == "strip"]
        if sorted(stripped) != ["Engine", "Host"]:
            found.append("the application's strip policy must reach every binary the bundle carries, not only the "
                         "executable: stripped {}".format(stripped))
        carried = folder / "build" / "Host.app" / "Frameworks" / "Engine.framework"
        shipped = sorted(str(path.relative_to(carried)) for path in carried.rglob("*") if path.is_file())
        if shipped != ["Engine", "Info.plist", "en.lproj/Localizable.strings"]:
            found.append("a bundled framework must carry its binary and resources and none of what only a build "
                         "reads: got {}".format(shipped))
    return found


def naming_failures(module, made, ld64, ldid):
    found = []
    original = module.MachO
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        (folder / "libSystem.tbd").write_text(SYSTEM_STUB)
        (folder / "runtime.c").write_text("int runtime_marker(void) { return 1; }\n")
        (folder / "user.c").write_text("extern int runtime_marker(void); int use(void) { return runtime_marker(); }\n")
        common = ["xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot",
                  "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem"]
        run(*common, "-install_name", "@rpath/libc++.1.dylib", "-o", "libc++.1.0.dylib", "runtime.c", cwd=folder)
        run(*common, "libc++.1.0.dylib", "-install_name", "@rpath/libuser.dylib", "-o", "libuser.dylib", "user.c",
            cwd=folder)
        instance = running_port(module, folder, {"stage": {}}, ldid)

        class Linking(original):
            def tool(self, name):
                return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

        try:
            macho = Linking(instance)
            names = macho.retarget({str(folder / "libc++.1.0.dylib"): "/usr/lib/librev-c++.1.dylib",
                                    str(folder / "libuser.dylib"): "/usr/lib/libuser.dylib"})
            references = macho.references(str(folder / "libuser.dylib"))
            if "/usr/lib/librev-c++.1.dylib" not in references or any("libc++" in name for name in references
                                                                        if name != "/usr/lib/librev-c++.1.dylib"):
                found.append("a library renamed on the way into the stage must be found by the install name it was "
                             "linked with, so its clients load the new name: got {}".format(references))
            if names.get("libc++.1.dylib") != "/usr/lib/librev-c++.1.dylib":
                found.append("retarget must answer each linked name with its new identity: got {}".format(names))
        except module.ConanException as refused:
            found.append("renaming a runtime into the stage must succeed: {}".format(refused))

        framework = folder / "build" / "Engine.framework"
        framework.mkdir(parents=True)
        for declared, expected in (({"as": "Engine", "replaces": "/System/Engine"}, []),
                                   ({"as": "Engine", "replaces": "/System/Engine", "compatibility-version": "1.0.0"},
                                    [("compatibility", "1.0.0")])):
            shutil.copy2(made["library"], framework / "Engine")
            instance = running_port(module, folder, {"stage": {"frameworks": {"Engine": declared}}}, ldid)
            module.MachO = recording_macho(module, instance)
            try:
                instance._stage_frameworks()
            finally:
                module.MachO = original
            checked = [step for step in instance.steps if step[0] == "compatibility"]
            if checked != expected:
                found.append("a staged framework's compatibility version is checked only when declared, against the "
                             "declared value: declared {}, checked {}".format(declared, checked))
    return found


def installed_entitlement_failures(module, made, ldid):
    found = []
    original = module.MachO
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        with open(folder / "daemon.plist", "wb") as handle:
            plistlib.dump({"platform-application": True, "com.apple.private.security.no-container": True}, handle)
        installed = folder / "build" / "executable"
        installed.mkdir(parents=True)
        for signs, reason in ((True, None), (False, "platform-application is declared and the signature does not "
                                                     "carry it")):
            shutil.copy2(made["executable"], installed / "telegramd")
            (installed / "install_manifest.txt").write_text(str(installed / "telegramd") + "\n")
            instance = running_port(module, folder, {"executable": [
                {"name": "telegramd", "install": "/usr/libexec", "entitlements": "daemon.plist"}]}, ldid)

            class Staging(original):
                def tool(self, name):
                    return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

                def strip(self, binary, arguments="-x"):
                    pass

                def sign(self, binary, entitlements=None):
                    super().sign(binary, entitlements if signs else None)

            module.MachO = Staging
            try:
                instance._sign_installed(str(installed))
                if reason:
                    found.append("a staged executable signed without its entitlements must be refused")
            except module.ConanException as refused:
                if not reason or reason not in str(refused):
                    found.append("a staged executable signed {}: expected {}, got {}".format(
                        "with" if signs else "without", reason or "success", refused))
            finally:
                module.MachO = original
    return found


def entitlement_failures(module, folder, made, ldid):
    found = []
    declared = {"get-task-allow": True, "keychain-access-groups": ["example.shared"]}
    with open(folder / "declared.plist", "wb") as handle:
        plistlib.dump(declared, handle)
    with open(folder / "partial.plist", "wb") as handle:
        plistlib.dump({"keychain-access-groups": ["example.shared"]}, handle)

    def slices(first, second):
        for source, listed, name in ((made["executable"], first, "slice-armv7"), (made["arm64"], second, "slice-arm64")):
            shutil.copy2(source, folder / name)
            subprocess.run([str(ldid), "-S{}".format(folder / listed), str(folder / name)], check=True)
        subprocess.run(["xcrun", "lipo", "-create", str(folder / "slice-armv7"), str(folder / "slice-arm64"),
                        "-output", str(folder / "signed")], check=True)

    for description, waive, signs_with_them, reason, prepare in (
            ("signed with what it declares", {}, True, None, None),
            ("signed without them", {}, False, "get-task-allow is declared and the signature does not carry it", None),
            ("signed without them, waived", {"entitlements": "a reason"}, False, None, None),
            ("merged from slices both signed with them", {}, None, None, ("declared.plist", "declared.plist")),
            ("merged from an arm64 slice signed without one", {}, None,
             "arm64: get-task-allow is declared and the signature does not carry it",
             ("declared.plist", "partial.plist"))):
        instance = running_port(module, folder, {"application": {"name": "Host", "entitlements": "declared.plist"},
                                                 "waive": waive}, ldid)
        executable = folder / "signed"
        if prepare:
            slices(*prepare)
        else:
            shutil.copy2(made["executable"], executable)
        instance._declared_context = lambda: {"executable": str(executable)}

        class Signing(module.MachO):
            def tool(self, name):
                return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

            def sign(self, binary, entitlements=None):
                if signs_with_them is not None:
                    super().sign(binary, entitlements if signs_with_them else None)

        module.MachO = Signing
        try:
            module.Port._sign_target(instance, "application")
            if reason:
                found.append("an application {} must be refused".format(description))
        except module.ConanException as refused:
            if not reason or reason not in str(refused):
                found.append("an application {}: expected {}, got {}".format(description, reason or "success",
                                                                              refused))
    return found


class Named:
    def __init__(self, name):
        self.name = name


class Package:
    def __init__(self, name, libdir):
        self.ref = Named(name)
        self.cpp_info = self
        self._libdir = libdir
        self.package_folder = str(Path(libdir).parent)

    def aggregated_components(self):
        return type("Components", (), {"libdirs": [str(self._libdir)]})()


class Requirement:
    def __init__(self, name):
        self.ref = Named(name)


class Compat:
    ARRIVED = {"aligned_alloc": "13.0", "clock_gettime": "10.0", "fdopendir": "8.0", "__strlcpy_chk": "7.0"}

    def __init__(self):
        self.ref = Named("apple-compat")
        self.package_folder = None
        self.cpp_info = self

    def get_property(self, name):
        return dict(self.ARRIVED) if name == "charon_arrived" else None


class Dependencies:
    def __init__(self, packages):
        packages = list(packages) + [Compat()]
        self.host = {Requirement(package.ref.name): package for package in packages}
        self._named = {package.ref.name: package for package in packages}
        self.build = {}

    def __getitem__(self, name):
        return self._named[name]


def compiled(folder, name, version, *extra):
    (folder / "unit.c").write_text("int unit(void) { return 1; }\n")
    run("xcrun", "clang", "-target", "armv7-apple-ios{}".format(version), "-Wno-incompatible-sysroot", "-c",
        "unit.c", "-o", name, *extra, cwd=folder)
    return folder / name


def input_minimum_failures(module, ldid):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        at_target = compiled(folder, "a_member_built_for_the_target.o", "6.0")
        older = compiled(folder, "intrapred_neon_asm.asm.S.o", "5.0")
        newer = compiled(folder, "newer.o", "7.0")
        silent = folder / "silent.o"
        data = bytearray(at_target.read_bytes())
        command = data.find(struct.pack("<II", 0x25, 16))
        if command < 0:
            return ["the compiler must record LC_VERSION_MIN_IPHONEOS for an iOS 6 object for this test to strip it"]
        data[command:command + 4] = struct.pack("<I", 0x2A)
        silent.write_bytes(bytes(data))
        libdir = folder / "vpx" / "lib"
        libdir.mkdir(parents=True)
        run("xcrun", "libtool", "-static", "-o", libdir / "libvpx.a", at_target, older, cwd=folder)
        clean = folder / "clean" / "lib"
        clean.mkdir(parents=True)
        run("xcrun", "libtool", "-static", "-o", clean / "libogg.a", at_target, cwd=folder)
        for name, cputype, problems in (
                ("libvpx.a", 12, ["vpx/libvpx.a(intrapred_neon_asm.asm.S.o) was built for iOS 5.0 instead of 6.0"]),
                ("libogg.a", 12, []), ("libvpx.a", 0x0100000C, [])):
            path = (libdir if name == "libvpx.a" else clean) / name
            label = "vpx/libvpx.a" if name == "libvpx.a" else "ogg/libogg.a"
            got = module.MachO.minimum_problems(str(path), cputype, "6.0", label)
            if len(got) != len(problems) or any(want not in have for want, have in zip(problems, got)):
                found.append("{} for cpu {:#x}: expected {}, got {}".format(name, cputype, problems or "nothing", got))
        for path, reason in ((newer, "newer.o was built for iOS 7.0, newer than the 6.0"),
                             (silent, "silent.o records no minimum OS version")):
            got = module.MachO.minimum_problems(str(path), 12, "6.0", path.name)
            if len(got) != 1 or reason not in got[0]:
                found.append("{}: expected {}, got {}".format(path.name, reason, got))

        port_objects = folder / "build" / "application"
        port_objects.mkdir(parents=True)
        shutil.copy2(at_target, port_objects / "main.o")
        shutil.copy2(newer, port_objects / "stale.o")
        vendor = folder / "vendor"
        vendor.mkdir()
        run("xcrun", "libtool", "-static", "-o", vendor / "libolder.a", older, cwd=folder)
        run("xcrun", "libtool", "-static", "-o", vendor / "libnewer.a", newer, cwd=folder)
        packages = [Package("libvpx", libdir), Package("ogg", clean)]

        def ninja(where, inputs):
            (where / "build.ninja").write_text("rule link\n  command = true\nbuild linked: link {}\ndefault linked\n"
                                               .format(" ".join(str(path) for path in inputs)))

        def running_ninja(ran):
            def execute(self, command, cwd=None, stdout=None, ignore_errors=False, quiet=False):
                ran.append(command)
                if not command.startswith("ninja"):
                    return 0
                finished = subprocess.run(command, shell=True, capture_output=True, text=True)
                if stdout is not None:
                    stdout.write(finished.stdout)
                return finished.returncode
            return execute

        linked = [port_objects / "main.o", libdir / "libvpx.a", clean / "libogg.a"]
        cases = (
            ("an archive member built for another version", {}, [], "libvpx/lib/libvpx.a(intrapred_neon_asm.asm.S.o)"),
            ("an object of the port's own built for a newer version", {}, [newer], "newer.o was built for iOS 7.0"),
            ("an object of the port's own built for an older version", {"input-minimum": {"libvpx": "why"}}, [older],
             "intrapred_neon_asm.asm.S.o was built for iOS 5.0"),
            ("a waived package", {"input-minimum": {"libvpx": "its assembler is fixed upstream next week"}}, [], None),
            ("everything waived", {"input-minimum": "a reason"}, [newer], None),
            ("a waiver naming a package nothing depends on", {"input-minimum": {"tdlib": "why"}}, [],
             "does not depend on"),
            ("a package waiver without a reason", {"input-minimum": {"libvpx": ""}}, [], "gives no reason"),
            ("a vendored archive built for a newer version", {"input-minimum": {"libvpx": "why"}},
             [vendor / "libnewer.a"], "libnewer.a(newer.o) was built for iOS 7.0"),
            ("a vendored archive built for an older version", {"input-minimum": {"libvpx": "why"}},
             [vendor / "libolder.a"], None),
        )
        for description, waive, extra, reason in cases:
            instance = running_port(module, folder, {"waive": waive}, ldid)
            instance.dependencies = Dependencies(packages)
            instance.generators_folder = str(folder / "generators")
            for path in extra:
                if path.suffix == ".o":
                    shutil.copy2(path, port_objects / path.name)
            ninja(port_objects, linked + [port_objects / path.name if path.suffix == ".o" else path for path in extra])
            ran = []
            type(instance).run = running_ninja(ran)
            try:
                instance._cmake_project(str(folder), str(port_objects), {})
                if reason:
                    found.append("{} must be refused".format(description))
            except module.ConanException as refused:
                if not reason or reason not in str(refused):
                    found.append("{}: expected {}, got {}".format(description, reason or "success", refused))
            if not any(command.startswith("cmake --build") for command in ran):
                found.append("{}: the project must be built before its inputs are read".format(description))
            if description == "a vendored archive built for an older version" and not any(
                    "libolder.a(intrapred_neon_asm.asm.S.o) was built for iOS 5.0" in line and "reported" in line
                    for line in instance.output.lines):
                found.append("an older input from outside the graph must be reported by name: {}".format(
                    instance.output.lines))

        instance = running_port(module, folder, {"stage": {}}, ldid)
        instance.dependencies = Dependencies([Package("ogg", clean)])
        shutil.copy2(newer, Path(instance.build_folder) / "engine-unit.o")
        ninja(Path(instance.build_folder), [Path(instance.build_folder) / "engine-unit.o"])
        type(instance).run = running_ninja([])
        original = module.CMake
        module.CMake = type("CMake", (), {"__init__": lambda self, conanfile: None,
                                          "configure": lambda self, cli_args=None: None, "build": lambda self: None})
        try:
            module.Port._build_target(instance, "engine")
            found.append("an engine object built for a newer version must be refused after the engine builds")
        except module.ConanException as refused:
            if "engine-unit.o was built for iOS 7.0" not in str(refused):
                found.append("the engine build must be refused for its object: got {}".format(refused))
        finally:
            module.CMake = original

        instance = running_port(module, folder, {"stage": {}}, ldid)
        instance.dependencies = Dependencies(packages)
        (port_objects / "build.ninja").unlink()
        try:
            instance._verify_inputs(str(port_objects))
            found.append("a project without build.ninja must be refused rather than read by walking its folder")
        except module.ConanException as refused:
            if "build.ninja" not in str(refused):
                found.append("a project without build.ninja must be refused for that: {}".format(refused))
    return found


LOCAL_MODES = """
__attribute__((target("arm"))) static int in_arm(int x) { return x + 1; }
__attribute__((target("thumb"))) static int in_thumb(int x) { return x + 2; }
int (*table[])(int) = { in_arm, in_thumb };
"""


def weak_import_failures(module, ld64, ldid):
    found = []
    original = module.MachO
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        (folder / "libSystem.tbd").write_text(SYSTEM_STUB.replace(
            "dyld_stub_binder", "dyld_stub_binder, _clock_gettime, _openat, ___strlcpy_chk"))
        for name, source in (("late", "extern int clock_gettime(int, void *) __attribute__((weak_import));\n"
                                      "int use(void) { return clock_gettime(0, 0); }\n"),
                             ("guarded", "extern int openat(int, const char *, int) __attribute__((weak_import));\n"
                                         "int use(void) { return openat ? openat(0, \"x\", 0) : -1; }\n"),
                             ("strong", "extern unsigned long __strlcpy_chk(char *, const char *, unsigned long, "
                                        "unsigned long);\n"
                                        "unsigned long use(char *d) { return __strlcpy_chk(d, \"x\", 2, 2); }\n")):
            (folder / "{}.c".format(name)).write_text(source)
            run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot",
                "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem", "-o",
                "lib{}.dylib".format(name), "{}.c".format(name), cwd=folder)
        (folder / "wide.c").write_text("extern unsigned long __strlcpy_chk(char *, const char *, unsigned long, "
                                       "unsigned long);\n"
                                       "unsigned long use(char *d) { return __strlcpy_chk(d, \"x\", 2, 2); }\n")
        run("xcrun", "clang", "-target", "arm64-apple-ios7.0", "-Wno-incompatible-sysroot",
            "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem", "-o", "libwide-arm64.dylib",
            "wide.c", cwd=folder)
        run("xcrun", "lipo", "-create", "libguarded.dylib", "libwide-arm64.dylib", "-output", "libfat.dylib", cwd=folder)
        run("xcrun", "lipo", "-create", "libstrong.dylib", "libwide-arm64.dylib", "-output", "libfatlate.dylib",
            cwd=folder)
        instance = running_port(module, folder, {"stage": {}}, ldid)

        class Reading(original):
            def tool(self, name):
                return subprocess.run(["xcrun", "-f", name], capture_output=True, text=True).stdout.strip()

        module.MachO = Reading
        try:
            for name, waive, reason in (("late", {}, "clock_gettime arrived in 10.0"),
                                        ("guarded", {}, None),
                                        ("late", {"weak-imports": "a reason"}, None),
                                        ("strong", {}, "dyld refuses to load it there: armv7: __strlcpy_chk arrived in 7.0"),
                                        ("strong", {"weak-imports": "a reason"}, "__strlcpy_chk arrived in 7.0"),
                                        ("fat", {}, None),
                                        ("fatlate", {}, "armv7: __strlcpy_chk arrived in 7.0, after 6.0")):
                type(instance).declaration = {"stage": {}, "waive": waive}
                try:
                    instance.platform_verify(str(folder / "lib{}.dylib".format(name)), waive)
                    if reason:
                        found.append("a binary weakly importing a call iOS 6 lacks must be refused")
                except module.ConanException as refused:
                    if not reason or reason not in str(refused):
                        found.append("lib{}.dylib (waived={}): expected {}, got {}".format(
                            name, bool(waive), reason or "success", refused))
        finally:
            module.MachO = original
    return found


def stripped_failures(module, ld64):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        (folder / "libSystem.tbd").write_text(SYSTEM_STUB)
        (folder / "local.c").write_text(LOCAL_MODES)
        run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-fuse-ld={}".format(ld64),
            "-nostdlib", "-dynamiclib", "-L.", "-lSystem", "-o", "liblocal.dylib", "local.c", cwd=folder)
        shutil.copy2(folder / "liblocal.dylib", folder / "libstripped.dylib")
        run("xcrun", "strip", "-x", "libstripped.dylib", cwd=folder)
        (folder / "libimports.tbd").write_text(SYSTEM_STUB.replace("/usr/lib/libSystem.B.dylib", "/usr/lib/libimports.dylib")
                                               .replace("dyld_stub_binder", "_first, _second"))
        (folder / "daemon.c").write_text("extern int first(void); extern int second(void);\n"
                                         "int start(void) { return first() + second(); }\n")
        run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-fuse-ld={}".format(ld64),
            "-nostdlib", "-Wl,-e,_start", "-L.", "-lSystem", "-limports", "-o", "daemon", "daemon.c", cwd=folder)
        output = Output()
        conanfile = type("Recipe", (), {"output": output})()
        macho = module.MachO(conanfile)
        problems, checked, into_code = module.MachO.interworking_problems(str(folder / "daemon"))
        if into_code or problems:
            found.append("an executable whose only code pointers are dyld's lazy binding slots has no program pointer "
                         "to check: counted {} into code, {}".format(into_code, problems))
        for name, stripped, waived, reason in (
                ("liblocal.dylib", False, {}, None),
                ("libstripped.dylib", False, {}, "arrived stripped"),
                ("libstripped.dylib", True, {}, None),
                ("libstripped.dylib", False, {"thumb-interworking": "a reason"}, None)):
            try:
                macho.verify(str(folder / name), waived, stripped)
                if reason:
                    found.append("{} checked before strip with no symbols to check against must be refused".format(name))
            except module.ConanException as refused:
                if not reason or reason not in str(refused):
                    found.append("{} (stripped={}, waived={}): expected {}, got {}".format(
                        name, stripped, bool(waived), reason or "success", refused))
    return found


def waiver_failures(module, made):
    found = []
    instance = running_port(module, Path(made["armv7-pagezero-gap"]).parent / "waiver", {}, "ldid")
    for waive, reason in (({"pagezero": ""}, "gives no reason"), ({"thumb": "why"}, "not something this toolchain"),
                          ({"pagezero": True}, "gives no reason")):
        type(instance).declaration = {"waive": waive}
        try:
            instance.declared_waivers()
            found.append("[waive] {} must be refused".format(waive))
        except module.ConanException as refused:
            if reason not in str(refused):
                found.append("[waive] {} must be refused for {}: got {}".format(waive, reason, refused))
    type(instance).declaration = {"waive": {"pagezero": "the gap is the point of this binary",
                                            "weak-imports": "this binary imports nothing weakly"}}
    try:
        instance._verify(str(made["armv7-pagezero-gap"]))
    except module.ConanException as refused:
        found.append("a waived invariant must not refuse: {}".format(refused))
    if not any("pagezero not checked: the gap is the point" in line for line in instance.output.lines):
        found.append("a waived invariant must say it was not checked and why: {}".format(instance.output.lines))
    return found


def moved_framework_failures(module, ld64):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        public = folder / "sdk" / "System" / "Library" / "Frameworks" / "IOSurface.framework"
        (public / "Headers").mkdir(parents=True)
        (public / "Headers" / "IOSurface.h").write_text("int IOSurfaceGetID(void *);\n")
        (public / "IOSurface.tbd").write_text(
            "--- !tapi-tbd\ntbd-version: 4\ntargets: [ armv7-ios, arm64-ios ]\n"
            "install-name: '/System/Library/Frameworks/IOSurface.framework/IOSurface'\n"
            "exports:\n  - targets: [ armv7-ios, arm64-ios ]\n    symbols: [ _IOSurfaceGetID ]\n...\n")
        (folder / "libSystem.tbd").write_text(SYSTEM_STUB)
        instance = declaration_test.port(module, {"prefixed": "False"})
        instance.conf = declaration_test.Conf({"tools.apple:sdk_path": str(folder / "sdk")})
        instance.generators_folder = str(folder / "generators")
        type(instance).declaration = {"platform-facts": {"frameworks": {"IOSurface": {"public-since": "11.0"}}}}
        instance.platform_toolchain(type("Toolchain", (), {"blocks": type("Blocks", (), {"remove": lambda self, name: None})()})())
        root = instance.platform_cache_variables().get("CHARON_FRAMEWORK_ROOT")
        moved = Path(root or "") / "System" / "Library" / "Frameworks" / "IOSurface.framework"
        if not root or not (moved / "IOSurface.tbd").is_file():
            return ["a framework public only from 11.0 must be laid out for a 6.0 build: {}".format(root)]
        if not (moved / "Headers" / "IOSurface.h").is_file():
            found.append("the laid-out framework must still carry the SDK's headers")
        (folder / "user.c").write_text("int IOSurfaceGetID(void *);\nint use(void) { return IOSurfaceGetID(0); }\n")
        run("xcrun", "clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot",
            "-fuse-ld={}".format(ld64), "-nostdlib", "-dynamiclib", "-L.", "-lSystem",
            "-F{}".format(moved.parent), "-framework", "IOSurface", "-o", "libuser.dylib", "user.c", cwd=folder)
        linked = run("xcrun", "otool", "-L", "libuser.dylib", cwd=folder)
        if "/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface" not in linked:
            found.append("an image linked for 6.0 must load IOSurface from where iOS 6 keeps it: {}".format(linked))
        newer = declaration_test.port(module, {"prefixed": "False"})
        newer.settings = type("Eleven", (declaration_test.Settings,), {
            "os": type("OS", (declaration_test.OperatingSystem,), {"version": "11.0"})()})()
        newer.conf = instance.conf
        newer.generators_folder = str(folder / "generators-11")
        if newer.platform_cache_variables().get("CHARON_FRAMEWORK_ROOT"):
            found.append("a release where the framework is public must link the SDK's own")
    return found


def main():
    declaration_test.reexec_where_conan_lives(__file__)
    try:
        module = declaration_test.loaded_base()
        module.ConanException = sys.modules["conan.errors"].ConanException
    except ImportError as missing:
        print("FAIL  this needs an interpreter that can import conan: {}".format(missing))
        return 1
    found = []
    try:
        ld64 = packaged("ld64/*@charon/stable", "ld")
        ldid = packaged("ldid/*@charon/stable", "ldid")
        with tempfile.TemporaryDirectory() as scratch:
            made, pointers = fixtures(Path(scratch), ld64)
            found += invariant_failures(module, made, pointers)
            found += waiver_failures(module, made)
            found += stripped_failures(module, ld64)
            found += weak_import_failures(module, ld64, ldid)
            found += wiring_failures(module, made, ldid)
            found += runtime_reference_failures(module, made, ld64, ldid)
            found += input_minimum_failures(module, ldid)
            found += naming_failures(module, made, ld64, ldid)
            found += bundle_content_failures(module, made, ldid)
            found += installed_entitlement_failures(module, made, ldid)
            found += moved_framework_failures(module, ld64)
    except Refused as missing:
        found.append(str(missing))
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    a binary that breaks a platform invariant is refused where it is produced, before it is stripped")
    return 0


if __name__ == "__main__":
    sys.exit(main())

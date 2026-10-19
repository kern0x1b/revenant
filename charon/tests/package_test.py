#!/usr/bin/env python3
"""Check the .deb a port's package step writes, by reading it back.

    tests/package_test.py

A port packages the variant its [package] names: the staged tree, and for a
variant whose pipeline builds, merges or signs the application also the bundle,
laid out where the chosen distribution installs applications. A merged variant
has no stage of its own. This runs the package step of a port for
each case on real folders and opens the archive the way dpkg does - ar, then
control.tar.gz and data.tar.lzma - to check what it carries, who owns it and
the version in its control file.
"""
import io
import lzma
import os
import stat
import sys
import tarfile
import tempfile
from pathlib import Path

import declaration_test

CONTROL = "Package: org.example.demo\nName: Demo\nArchitecture: iphoneos-arm\nDescription: a demo\n"
JAILBREAK = {"name": "apple-ios", "distribution": "jailbreak", "distributed": {"applications": "/Applications"}}


def members(deb):
    content = deb.read_bytes()
    if not content.startswith(b"!<arch>\n"):
        raise ValueError("{} is not an ar archive".format(deb.name))
    found, offset = {}, 8
    while offset < len(content):
        header = content[offset:offset + 60]
        name = header[:16].decode().strip().rstrip("/")
        size = int(header[48:58].decode().strip())
        found[name] = content[offset + 60:offset + 60 + size]
        offset += 60 + size + (size % 2)
    return found


def opened(deb):
    parts = members(deb)
    control = tarfile.open(fileobj=io.BytesIO(parts["control.tar.gz"]), mode="r:gz")
    data = tarfile.open(fileobj=io.BytesIO(lzma.decompress(parts["data.tar.lzma"], format=lzma.FORMAT_ALONE)))
    return control, data


def packaging_port(module, folder, declaration):
    instance = declaration_test.port(module, {"prefixed": "False"})
    kind = type(instance)
    kind.declaration = declaration
    kind.port = str(folder)
    instance.build_folder = str(folder / "build")
    instance.package_folder = str(folder / "package")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "control").write_text(CONTROL)
    return instance


def application_failures(module):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        bundle = folder / "build" / "Demo.app"
        bundle.mkdir(parents=True)
        (bundle / "Demo").write_bytes(b"\xce\xfa\xed\xfe")
        os.chmod(bundle / "Demo", 0o755)
        (bundle / "Info.plist").write_text("<plist/>")
        instance = packaging_port(module, folder, {
            "variants": {"armv7": {}, "arm64": {}, "universal": {"merge": ["armv7", "arm64"]}},
            "application": {"name": "Demo"}, "package": {"control": "control", "variant": "universal"},
            "pipeline": {"universal": ["merge:application", "sign:application"]}, "platform-facts": JAILBREAK})
        instance.declared_variant = lambda: "universal"
        instance.platform_package()
        debs = sorted((folder / "package" / "deb").glob("*.deb"))
        if [deb.name for deb in debs] != ["org.example.demo_1.0_iphoneos-arm.deb"]:
            return ["an application port with a control file must write one .deb named by package, version and "
                    "architecture: got {}".format([deb.name for deb in debs])]
        control, data = opened(debs[0])
        written = control.extractfile("./control").read().decode()
        if "\nVersion: 1.0\n" not in written:
            found.append("the control file must carry the recipe's version: got {}".format(written))
        entries = {member.name: member for member in data.getmembers()}
        executable = entries.get("./Applications/Demo.app/Demo")
        if executable is None:
            found.append("the bundle must be laid out where the distribution installs applications: got {}".format(
                sorted(entries)))
        else:
            if stat.S_IMODE(executable.mode) != 0o755:
                found.append("the executable must stay 755: got {:o}".format(stat.S_IMODE(executable.mode)))
            if (executable.uid, executable.gid, executable.uname) != (0, 0, "root"):
                found.append("everything must be owned by root: got {} {} {}".format(
                    executable.uid, executable.gid, executable.uname))
        if "./Applications/Demo.app/Info.plist" not in entries:
            found.append("the whole bundle must be carried, not only its executable: got {}".format(sorted(entries)))
        if not (folder / "package" / "Demo.app" / "Demo").is_file():
            found.append("the bundle itself must still be packaged beside the .deb")
        first = debs[0].read_bytes()
        import time
        time.sleep(1.1)
        instance.platform_package()
        if debs[0].read_bytes() != first:
            found.append("packaging the same tree twice must write the same .deb byte for byte")
    return found


def stage_failures(module):
    found = []
    with tempfile.TemporaryDirectory() as scratch:
        folder = Path(scratch)
        library = folder / "build" / "stage" / "usr" / "lib" / "libdemo.dylib"
        library.parent.mkdir(parents=True)
        library.write_bytes(b"\xce\xfa\xed\xfe")
        (folder / "build" / "Host.app").mkdir()
        (folder / "build" / "Host.app" / "Host").write_bytes(b"\xce\xfa\xed\xfe")
        declaration = {"variants": {"system": {}, "prefixed": {}}, "application": {"name": "Host"},
                       "package": {"control": "control", "variant": "system"}, "platform-facts": JAILBREAK,
                       "pipeline": {"system": ["build:static-library", "stage:clear", "build:device-library"],
                                    "prefixed": ["build:static-library", "build:application", "sign:application"]}}
        instance = packaging_port(module, folder, declaration)
        instance.declared_variant = lambda: "system"
        instance.platform_package()
        debs = sorted((folder / "package" / "deb").glob("*.deb"))
        if len(debs) != 1:
            return ["the variant [package] names must write its .deb: got {}".format(debs)]
        names = sorted(member.name for member in opened(debs[0])[1].getmembers())
        if "./usr/lib/libdemo.dylib" not in names or any("Applications" in name for name in names):
            found.append("a variant that builds no application must package its stage alone: got {}".format(names))

        other = packaging_port(module, folder / "other", declaration)
        (folder / "other" / "build" / "Host.app").mkdir(parents=True)
        (folder / "other" / "build" / "Host.app" / "Host").write_bytes(b"\xce\xfa\xed\xfe")
        other.declared_variant = lambda: "prefixed"
        try:
            other.platform_package()
        except module.ConanException as refused:
            found.append("the application variant [package] does not name must package its bundle without a .deb: "
                         "{}".format(refused))
        if list((folder / "other" / "package").glob("deb/*")):
            found.append("a variant [package] does not name must write no .deb")

        nowhere = packaging_port(module, folder / "nowhere", dict(
            declaration, package={"control": "control"},
            **{"platform-facts": {"name": "apple-ios", "distribution": "sideload", "distributed": {}}}))
        (folder / "nowhere" / "build" / "Host.app").mkdir(parents=True)
        nowhere.declared_variant = lambda: "prefixed"
        try:
            nowhere.platform_package()
            found.append("an application must not be packaged for a distribution that says nowhere to install it")
        except module.ConanException as refused:
            if "nowhere for an application" not in str(refused):
                found.append("the refusal must name the missing install location: got {}".format(refused))
    return found


def main():
    declaration_test.reexec_where_conan_lives(__file__)
    try:
        module = declaration_test.loaded_base()
        module.ConanException = sys.modules["conan.errors"].ConanException
    except ImportError as missing:
        print("FAIL  this needs an interpreter that can import conan: {}".format(missing))
        return 1
    found = application_failures(module) + stage_failures(module)
    for line in found:
        print("FAIL  {}".format(line))
    if found:
        print("{} checks failed".format(len(found)))
        return 1
    print("ok    a port's .deb carries its stage, and its application where the distribution installs one")
    return 0


if __name__ == "__main__":
    sys.exit(main())

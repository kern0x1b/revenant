import os
import tomllib

from conan.errors import ConanException

PLATFORMS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "charon", "platforms")


def _platform(conanfile):
    settings = getattr(conanfile, "settings", None)
    target = settings.get_safe("os") if settings is not None else None
    if not target or not os.path.isdir(PLATFORMS):
        return None
    for name in sorted(os.listdir(PLATFORMS)):
        if name.endswith(".toml"):
            with open(os.path.join(PLATFORMS, name), "rb") as handle:
                facts = tomllib.load(handle)
            if facts.get("os") == target:
                return dict(facts, name=name[:-len(".toml")])
    return None


def pre_generate(conanfile):
    facts = _platform(conanfile)
    if facts is None:
        return
    folders = [(conanfile.source_folder, "/source"), (conanfile.build_folder, "/build")]
    sysroot = facts.get("sysroot-conf")
    if sysroot and conanfile.conf.get(sysroot):
        folders.append((conanfile.conf.get(sysroot), "/sysroot"))
    for dependency in conanfile.dependencies.host.values():
        if dependency.package_folder:
            folders.append((dependency.package_folder, f"/package/{dependency.ref.name}"))
    maps = [f"-ffile-prefix-map={folder}={name}" for folder, name in folders if folder]
    if maps:
        conanfile.conf.append("tools.build:cflags", maps)
        conanfile.conf.append("tools.build:cxxflags", maps)


def pre_build(conanfile):
    facts = _platform(conanfile)
    if facts is None:
        return
    sysroot = facts.get("sysroot-conf")
    if sysroot:
        path = conanfile.conf.get(sysroot)
        if not path:
            raise ConanException(
                f"{conanfile.ref}: {sysroot} is not set. The {facts['name']} platform's profiles require the "
                "package that sets it; build with a profile Charon wrote.")
        if not os.path.isdir(path):
            raise ConanException(
                f"{conanfile.ref}: {sysroot} names {path}, which does not exist. Leave it unset so the package "
                "the platform requires answers it; the build would otherwise fail much later, inside the "
                "system headers.")
    arch = conanfile.settings.get_safe("arch")
    required = list(facts.get("tool-requires") or []) + list(
        ((facts.get("architectures") or {}).get(arch) or {}).get("tool-requires") or [])
    names = {reference.split("/")[0] for reference in required}
    if conanfile.name in names:
        return
    present = {str(dependency.ref.name) for dependency in conanfile.dependencies.build.values()}
    missing = sorted(names - present)
    if missing:
        raise ConanException(
            f"{conanfile.ref}: {', '.join(missing)} is not in the build context, and the {facts['name']} platform "
            f"requires it for {arch}; build with a profile Charon wrote for that platform.")

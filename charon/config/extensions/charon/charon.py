#!/usr/bin/env python3
"""Charon builds a port from its charon.toml, for the platform it declares: build, package, install, test.

    charon VERB [options]            inside a port, or with --root PORT

The verbs are the same for every port. Nothing here decides what to compile or
whether a file is stale: Conan resolves the dependencies, CMake owns the graph,
and this only sequences the calls and reports where they went.
"""
import argparse
import importlib.util
import inspect
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

RECIPE = "conanfile.py"
MANIFEST = "charon.toml"
GENERATED = "charon"
PROFILES = "profiles"
LOCK = "conan.lock"
BUILT = "charon-built"
BUILD = "build"
STAGE = "stage"
FRAMEWORK = ".framework"
APPLICATION = ".app"
CMAKE_STAMP = "CMakeCache.txt"
APPLICATIONS = "/Applications"
TESTS = "tests"
DEPENDENCY_ENV = "charon-deps.env"
HOST_PREFIX = "CHARON_HOST_"
MINIMUM_PYTHON = (3, 11)
CHOSEN_INTERPRETER = "CHARON_INTERPRETER"


class Failure(Exception):
    pass


class NoEngineBuild(Failure, LookupError):
    pass


def say(message):
    print(message, flush=True)


def warn(message):
    print(message, file=sys.stderr, flush=True)


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


def newest_interpreter():
    found = {}
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        try:
            names = os.listdir(folder)
        except OSError:
            continue
        for name in names:
            prefix = "python3."
            if not name.startswith(prefix) or not name[len(prefix):].isdigit():
                continue
            minor = int(name[len(prefix):])
            if minor >= MINIMUM_PYTHON[1]:
                found.setdefault(minor, os.path.join(folder, name))
    return found[max(found)] if found else conan_interpreter()


def ensure_interpreter(argv):
    if sys.version_info >= MINIMUM_PYTHON or os.environ.get(CHOSEN_INTERPRETER):
        return
    interpreter = newest_interpreter()
    wanted = ".".join(str(part) for part in MINIMUM_PYTHON)
    running = ".".join(str(part) for part in sys.version_info[:3])
    if not interpreter:
        raise Failure("Charon reads a port's manifest with tomllib, which arrived in Python {}, and it is "
                      "running under {}. Install a newer Python, or run the driver with one: "
                      "python3.14 {} ...".format(wanted, running, os.path.abspath(__file__)))
    os.execve(interpreter, [interpreter, os.path.abspath(__file__)] + list(argv),
              dict(os.environ, **{CHOSEN_INTERPRETER: interpreter}))


def manifest(root):
    import tomllib
    path = root / MANIFEST
    if not path.is_file():
        return {}
    with path.open("rb") as handle:
        try:
            content = tomllib.load(handle)
        except tomllib.TOMLDecodeError as broken:
            raise Failure("{} is not readable: {}".format(path, broken))
    import spec
    return spec.with_implicit_variants(content)


def declared(root, section, key, fallback=None):
    return manifest(root).get(section, {}).get(key, fallback)


def variant_options(root, variant):
    if not variant:
        return []
    variants = manifest(root).get("variants", {})
    if variant not in variants:
        known = ", ".join(sorted(variants)) or "none declared"
        raise Failure("{} declares no variant {} ({})".format(root / MANIFEST, variant, known))
    options = variants[variant].get("options", [])
    return [argument for option in options for argument in ("-o", option)]


def is_port(folder):
    return (folder / MANIFEST).is_file() or (folder / RECIPE).is_file()


def find_port(argument):
    if argument:
        root = Path(argument).expanduser().resolve()
        if not is_port(root):
            raise Failure("{} holds neither {} nor {}, so it is not a port".format(root, MANIFEST, RECIPE))
        return root
    here = Path.cwd().resolve()
    for folder in (here,) + tuple(here.parents):
        if is_port(folder):
            return folder
    raise Failure("{} is not inside a port; run from one or pass --root".format(here))


def import_file(path, name):
    path = Path(path)
    if not path.is_file():
        raise Failure("{} does not exist".format(path))
    loaded = sys.modules.get(name)
    if loaded is not None and Path(getattr(loaded, "__file__", "") or "").resolve() == path.resolve():
        return loaded
    folder = str(path.parent)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module


def transport(root):
    device = import_file(Path(__file__).resolve().parent / "device.py", "charon_device")
    try:
        device.bind(root)
    except RuntimeError as absent:
        raise Failure(str(absent))
    return device


def written_profile(root, variant):
    declared = declaration_for(root, variant)
    if declared is None:
        return None
    named = declared.using("profile")
    if named:
        return named
    try:
        import generate
    except ImportError as missing:
        raise Failure("generate.py is not beside the driver: {}".format(missing))
    folder = root / BUILD / variant / GENERATED
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "profile"
    try:
        text = generate.profile(declared)
    except (generate.GenerationError, generate.spec.SpecError) as refused:
        raise Failure(str(refused))
    path.write_text(text)
    return path


def profile(root, parsed):
    if parsed.profile:
        return Path(parsed.profile).expanduser().resolve()
    written = written_profile(root, parsed.variant or default_variant(root))
    if written is not None:
        return written
    folder = root / PROFILES
    found = sorted(path for path in folder.iterdir() if path.is_file()) if folder.is_dir() else []
    if not found:
        raise Failure("{} holds no profile and {} declares no target to write one from, so nothing says "
                      "what this port builds for".format(folder, root / MANIFEST))
    if len(found) > 1:
        names = ", ".join(path.name for path in found)
        raise Failure("{} holds more than one profile ({}); pass --profile to say which".format(folder, names))
    return found[0]


def conan_flags(root, chosen_profile):
    flags = ["-pr:h", str(chosen_profile), "-pr:b", "default"]
    if (root / LOCK).is_file():
        flags += ["--lockfile", str(root / LOCK)]
    return flags


def conan(*arguments, **options):
    argv = ["conan"] + [str(part) for part in arguments]
    result = subprocess.run(argv, **options)
    if result.returncode and options.get("check") is not False:
        raise Failure("conan {} failed (exit {})".format(" ".join(str(a) for a in arguments), result.returncode))
    return result


def build_trees(root):
    folder = root / BUILD
    if not folder.is_dir():
        return []
    return sorted(path for path in folder.iterdir() if path.is_dir() and (path / CMAKE_STAMP).is_file())


def sole_tree(root, trees, wanted, variant):
    if variant:
        chosen = root / BUILD / variant
        if not chosen.is_dir():
            raise Failure("{} does not exist".format(chosen))
        return chosen
    if not trees:
        raise Failure("no build tree under {} {} - run charon build first".format(root / BUILD, wanted))
    if len(trees) > 1:
        names = ", ".join(path.name for path in trees)
        raise Failure("more than one build tree {} ({}); pass --variant to say which".format(wanted, names))
    return trees[0]


def staged_frameworks(tree):
    stage = tree / STAGE
    laid_out = [path for path in stage.glob("**/*" + FRAMEWORK)
                if (path / path.stem).is_file()] if stage.is_dir() else []
    if not laid_out:
        return None
    return min(laid_out, key=lambda path: len(path.parts)).parent


def engine_build(root, variant=None):
    root = Path(root)
    if variant:
        chosen = root / BUILD / variant
        if not (chosen / CMAKE_STAMP).is_file() or staged_frameworks(chosen) is None:
            raise NoEngineBuild("{} is not a built engine: that needs a configured tree with frameworks laid out "
                                "under {} - run charon build --variant {} first".format(chosen, STAGE, variant))
        return chosen
    trees = [tree for tree in build_trees(root) if staged_frameworks(tree) is not None]
    try:
        return sole_tree(root, trees, "with staged frameworks", None)
    except Failure as refused:
        raise NoEngineBuild(str(refused)) from None


def device_location(staged):
    for parent in staged.parents:
        if parent.name == STAGE:
            return "/" + str(staged.relative_to(parent))
    raise Failure("{} is not inside a {} tree, so where it belongs on the phone is unknown".format(staged, STAGE))


def standalone_app(tree):
    bundles = sorted(path for path in tree.glob("*" + APPLICATION) if (path / path.stem).is_file())
    if len(bundles) > 1:
        names = ", ".join(path.name for path in bundles)
        raise Failure("{} holds more than one application ({})".format(tree, names))
    return bundles[0] if bundles else None


def tree_size(path):
    total = 0
    for folder, directories, names in os.walk(path):
        directories[:] = [name for name in directories if name != ".git"]
        for name in names:
            candidate = os.path.join(folder, name)
            if not os.path.islink(candidate):
                total += os.lstat(candidate).st_size
    return total


def megabytes(size):
    return "{:.0f} MB".format(size / (1024 * 1024))


def users_of(folder):
    listing = subprocess.run(["ps", "-Ao", "pid=,pgid=,args="], capture_output=True, text=True,
                             errors="replace").stdout
    mine = (os.getpid(), os.getpgrp())
    found = []
    for line in listing.splitlines():
        fields = line.split(None, 2)
        if len(fields) < 3 or str(folder) not in fields[2]:
            continue
        if int(fields[0]) in mine or int(fields[1]) in mine:
            continue
        found.append(fields[2].strip())
    return found


def provenance(root, chosen_profile):
    driver = Path(__file__).resolve()
    say("driver       {}".format(driver))
    say("interpreter  {} ({})".format(sys.executable, ".".join(str(p) for p in sys.version_info[:3])))
    say("port         {}".format(root))
    declaration = manifest(root)
    if declaration:
        described = declaration.get("port", {})
        say("manifest     {} ({} {})".format(root / MANIFEST, described.get("name", "unnamed"),
                                             described.get("version", "unversioned")))
        say("variants     {}".format(", ".join(sorted(declaration.get("variants", {}))) or "none declared"))
    else:
        say("manifest     none - {} would declare the checks, variants and paths".format(root / MANIFEST))
    say("profile      {}".format(chosen_profile))
    check_declared_conf(root, chosen_profile)
    trees = build_trees(root)
    say("build trees  {}".format(", ".join(path.name for path in trees) if trees else "none yet"))
    try:
        say("phone        {}".format(transport(root).where()))
    except Failure as unknown:
        say("phone        none named; install, deploy and device read {}".format(root / "device.env"))


def declaration(root):
    try:
        import spec
    except ImportError as missing:
        raise Failure("spec.py is not beside the driver: {}".format(missing))
    try:
        return spec.load(root)
    except spec.SpecError as refused:
        raise Failure(str(refused))


def declaration_for(root, variant):
    declared = declaration(root)
    if declared is None:
        return None
    import spec
    try:
        return declared.for_variant(variant)
    except spec.SpecError as refused:
        raise Failure(str(refused))


def merged_slices(root, variant):
    variants = manifest(root).get("variants", {})
    slices = list((variants.get(variant) or {}).get("merge") or [])
    if not slices:
        return []
    unknown = [name for name in slices if name not in variants]
    if unknown:
        raise Failure("{} variant {} merges {}, which it does not declare".format(
            root / MANIFEST, variant, ", ".join(unknown)))
    if variant in slices or any((variants[name] or {}).get("merge") for name in slices):
        raise Failure("{} variant {} merges a variant that merges; a slice is built, not merged".format(
            root / MANIFEST, variant))
    if len(slices) < 2:
        raise Failure("{} variant {} merges one slice, and a merge needs at least two".format(
            root / MANIFEST, variant))
    return slices


def variant_profile(root, parsed, variant):
    if parsed.profile:
        return Path(parsed.profile).expanduser().resolve()
    return written_profile(root, variant) or parsed.chosen_profile


def declared_variants(root):
    return list(manifest(root).get("variants", {}))


def verb_lock(root, parsed):
    import tempfile
    variants = [parsed.variant] if parsed.variant else declared_variants(root)
    if not variants:
        raise Failure("{} declares no variant, so there is no graph to lock".format(root / MANIFEST))
    with tempfile.TemporaryDirectory() as folder:
        written = []
        for variant in variants:
            where = generated(root, variant)
            if where is None:
                raise Failure("the {} variant uses a recipe of its own; lock it with conan lock create".format(variant))
            out = Path(folder) / "{}.lock".format(variant)
            conan("lock", "create", where, "-pr:h", variant_profile(root, parsed, variant), "-pr:b", "default",
                  "--lockfile=", "--update", *variant_options(root, variant), "--lockfile-out", out)
            written.append(out)
        if len(written) == 1:
            shutil.copy2(written[0], root / LOCK)
        else:
            conan("lock", "merge", *[argument for path in written for argument in ("--lockfile", path)],
                  "--lockfile-out", root / LOCK)
    say("lock         {} ({})".format(root / LOCK, ", ".join(variants)))


def build_variant(root, parsed, variant, extra):
    where = generated(root, variant) or root
    conan("build", where, *conan_flags(root, variant_profile(root, parsed, variant)), "--build=missing",
          *index_updates(), *variant_options(root, variant), *extra)


def index_updates():
    names = sorted({recipe.name for remote in local_index_remotes()
                    for recipe in (Path(remote["url"]) / "recipes").iterdir() if recipe.is_dir()})
    return [flag for name in names for flag in ("--update", name)]


def default_variant(root):
    declared = manifest(root).get("variants", {})
    merging = [name for name, variant in declared.items() if variant.get("merge")]
    if len(merging) == 1:
        return merging[0]
    if len(merging) > 1:
        raise Failure("{} declares more than one variant that merges ({}); pass --variant to say which to "
                      "build".format(root / MANIFEST, ", ".join(merging)))
    plain = [name for name, variant in declared.items() if not variant.get("options")]
    if len(plain) != 1:
        raise Failure("{} declares {} variants with no options ({}); pass --variant to say which to build".format(
            root / MANIFEST, len(plain), ", ".join(plain) or "none"))
    return plain[0]


def generated(root, variant, report=say):
    declared = declaration_for(root, variant)
    if declared is None:
        return None
    if declared.using("recipe"):
        report("recipe       {} (declared under use.recipe)".format(declared.using("recipe")))
        return None
    try:
        import generate
    except ImportError as missing:
        raise Failure("generate.py is not beside the driver: {}".format(missing))
    folder = root / BUILD / variant / GENERATED
    folder.mkdir(parents=True, exist_ok=True)
    try:
        recipe = generate.recipe(declared)
        produced = generate.written(declared, required=False)
    except generate.GenerationError as refused:
        raise Failure(str(refused))
    written = folder / RECIPE
    written.write_text(recipe)
    report("recipe       {} (written from {})".format(written, root / MANIFEST))
    for name, text in produced.items():
        if name == "profile":
            continue
        path = folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        report("project      {} (written from {})".format(path, root / MANIFEST))
    return folder


def verb_generate(root, parsed):
    provenance(root, parsed.chosen_profile)
    variant = parsed.variant or default_variant(root)
    folder = generated(root, variant)
    if folder is None:
        raise Failure("{} declares no manifest to generate from, or names a recipe of its own".format(root))
    written = written_profile(root, variant)
    if written is not None:
        say("profile      {}".format(written))




def local_index_remotes():
    return [remote for remote in remotes()
            if remote.get("enabled", True) and Path(str(remote.get("url", ""))).is_dir()
            and (Path(remote["url"]) / "recipes").is_dir()]


def local_indexes():
    return [Path(remote["url"]) for remote in local_index_remotes()]


def served_revisions():
    served = {}
    for remote in local_index_remotes():
        listed = conan("list", "*#latest", "-r", remote["name"], "--format=json", stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, text=True, check=False)
        try:
            answered = json.loads(listed.stdout or "{}").get(remote["name"]) or {}
        except json.JSONDecodeError:
            continue
        for reference, recipe in answered.items():
            revisions = list((recipe or {}).get("revisions") or {})
            if revisions:
                served.setdefault(reference, (remote["name"], revisions[0]))
    return served


LOCK_UPGRADES = {"requires": "--update-requires", "build_requires": "--update-build-requires",
                 "python_requires": "--update-python-requires"}


def recipe_family(reference):
    name, _, rest = reference.partition("/")
    return name, rest.partition("@")[2]


def stale_pins(lock, served):
    with open(lock) as handle:
        content = json.load(handle)
    families = {}
    for reference, (remote, _) in served.items():
        version = reference.partition("/")[2].partition("@")[0]
        families.setdefault(recipe_family(reference), []).append((remote, version))
    stale = []
    for section, flag in LOCK_UPGRADES.items():
        for entry in content.get(section) or []:
            reference, _, revision = entry.partition("#")
            revision = revision.split("%")[0]
            if reference in served:
                remote, current = served[reference]
                if current != revision:
                    stale.append("{} pins {}#{}, and {} serves #{}; charon lock brings it forward"
                                 .format(lock.name, reference, revision, remote, current))
            elif recipe_family(reference) in families:
                offered = ", ".join("{} {}".format(remote, version)
                                    for remote, version in sorted(families[recipe_family(reference)]))
                stale.append("{} pins {}, a version no local index serves ({}); it builds from a recipe only this "
                             "cache still holds, until what requires it names a version that is served"
                             .format(lock.name, reference, offered))
    return stale


def warn_stale_lock(root):
    lock = root / LOCK
    if not lock.is_file():
        return
    served = served_revisions()
    for line in stale_pins(lock, served):
        warn("lock         " + line)


def check_indexes(canonical=False):
    indexes = local_indexes()
    if not indexes:
        return
    checker = Path(__file__).resolve().parent / "indexes.py"
    interpreter = conan_interpreter()
    if not interpreter:
        raise Failure("cannot tell which interpreter conan runs under, and the recipe index check needs Conan's "
                      "own trim")
    result = subprocess.run([interpreter, str(checker)] + (["--canonical"] if canonical else []) +
                            [str(index) for index in indexes], stdout=subprocess.PIPE, text=True)
    for line in (result.stdout or "").splitlines():
        (warn if line.startswith("rewritten") else say)("index        " + line)
    if result.returncode:
        raise Failure("a recipe index would hand consumers a recipe missing what its folder declares; key each "
                      "table in conandata.yml by version")


def verb_build(root, parsed):
    check_indexes()
    warn_stale_lock(root)
    provenance(root, parsed.chosen_profile)
    variant = parsed.variant or default_variant(root)
    slices = merged_slices(root, variant)
    if slices and parsed.profile:
        raise Failure("--profile names one profile, and {} merges {}, each built for its own target".format(
            variant, ", ".join(slices)))
    for name in slices:
        say("\n=== slice {} of {}".format(name, variant))
        build_variant(root, parsed, name, parsed.extra)
    if slices:
        say("\n=== {}, merging {}".format(variant, ", ".join(slices)))
    build_variant(root, parsed, variant, parsed.extra)


WHERE_CONTEXTS = {"pkg": "host", "tool": "build"}


def package_folder(root, parsed, wanted):
    kind, _, name = wanted.partition(":")
    if kind not in WHERE_CONTEXTS or not name:
        raise Failure("charon where answers pkg:NAME for a package the build links and tool:NAME for one it runs; "
                      "got {}".format(wanted or "nothing"))
    variant = parsed.variant or default_variant(root)
    where = generated(root, variant, report=warn) or root
    flags = conan_flags(root, variant_profile(root, parsed, variant))
    answered = conan("graph", "info", where, *flags, *variant_options(root, variant), "--format=json",
                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    nodes = [node for node in json.loads(answered.stdout)["graph"]["nodes"].values()
             if node.get("name") == name and node.get("context") == WHERE_CONTEXTS[kind]
             and node.get("binary") not in ("Skip", None)]
    found = {(node["ref"], node.get("package_id")) for node in nodes}
    if not found:
        raise Failure("the {} build of {} has no {} {}".format(variant, root.name,
                                                               "package" if kind == "pkg" else "tool", name))
    if len(found) > 1:
        raise Failure("{} is in the {} build more than once: {}".format(name, variant, ", ".join(
            sorted("{}:{}".format(*entry) for entry in found))))
    reference, package_id = found.pop()
    located = conan("cache", "path", "{}:{}".format(reference, package_id), stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, text=True, check=False)
    if located.returncode or not located.stdout.strip():
        raise Failure("{}:{} is not in the cache yet; charon build puts it there".format(reference, package_id))
    return located.stdout.strip()


def verb_where(root, parsed):
    say(package_folder(root, parsed, parsed.extra[0] if parsed.extra else ""))


def verb_package(root, parsed):
    variant = parsed.variant or default_variant(root)
    if not (root / BUILD / variant / BUILT).is_file():
        raise Failure("the {} variant has no finished build to package; run charon build first".format(variant))
    where = generated(root, variant) or root
    exported = conan("export-pkg", where, *conan_flags(root, variant_profile(root, parsed, variant)),
                     *variant_options(root, variant), "--format=json", *parsed.extra, stdout=subprocess.PIPE,
                     text=True)
    artifacts = packaged_artifacts(exported.stdout, root / BUILD / variant)
    for artifact in artifacts:
        say("package      {}".format(artifact))
    return artifacts


def deb_members(deb):
    import io
    import lzma
    import tarfile
    content = Path(deb).read_bytes()
    if not content.startswith(b"!<arch>\n"):
        raise Failure("{} is not a Debian package".format(deb))
    offset, parts = 8, {}
    while offset < len(content):
        header = content[offset:offset + 60]
        size = int(header[48:58].decode().strip())
        parts[header[:16].decode().strip().rstrip("/")] = content[offset + 60:offset + 60 + size]
        offset += 60 + size + (size % 2)
    data = next((value for name, value in parts.items() if name.startswith("data.tar")), None)
    if data is None:
        raise Failure("{} has no data archive".format(deb))
    if data[:2] != b"\x1f\x8b" and not data.startswith(b"BZh"):
        data = lzma.decompress(data)
    return tarfile.open(fileobj=io.BytesIO(data))


def installed_identity_conflicts(deb, fetch):
    conflicts = []
    with deb_members(deb) as archive:
        for member in archive.getmembers():
            parts = member.name.lstrip("./").split("/")
            if len(parts) != 3 or parts[0] != "Applications" or not parts[1].endswith(".app") or parts[2] != "Info.plist":
                continue
            packaged = plistlib.loads(archive.extractfile(member).read()).get("CFBundleIdentifier")
            installed_plist = fetch("/" + "/".join(parts))
            if installed_plist is None:
                continue
            installed = plistlib.loads(installed_plist).get("CFBundleIdentifier")
            if installed != packaged:
                conflicts.append("/{} on the phone is {}, and {} installs {} over it; SpringBoard would lose the "
                                 "app until a reboot, so remove the installed one first".format(
                                     "/".join(parts[:2]), installed, Path(deb).name, packaged))
    return conflicts


def verb_install(root, parsed):
    import tempfile
    device = transport(root)
    debs = verb_package(root, parsed)
    if not debs:
        raise Failure("charon package wrote no .deb, so there is nothing to install")

    def fetch(remote):
        with tempfile.TemporaryDirectory() as folder:
            local = Path(folder) / "Info.plist"
            return local.read_bytes() if device.fetch(remote, local) and local.is_file() else None

    for deb in debs:
        conflicts = installed_identity_conflicts(deb, fetch)
        if conflicts:
            raise Failure("; ".join(conflicts))
    for deb in debs:
        remote = "/tmp/{}".format(deb.name)
        if not device.copy(deb, remote):
            raise Failure("could not copy {} to {} on {}".format(deb, remote, device.where()))
        installed = device.run(300, "dpkg -i {0} && rm -f {0}".format(remote), capture=False)
        if installed.returncode:
            raise Failure("dpkg -i {} failed on {} (exit {})".format(remote, device.where(), installed.returncode))
        say("installed    {} on {}".format(deb.name, device.where()))
    with deb_members(debs[0]) as archive:
        if any(member.name.lstrip("./").startswith("Applications/") for member in archive.getmembers()):
            device.run(120, "su mobile -c uicache")


def packaged_artifacts(graph_json, destination):
    nodes = (json.loads(graph_json or "{}").get("graph") or {}).get("nodes") or {}
    folder = (nodes.get("0") or {}).get("package_folder")
    if not folder:
        raise Failure("conan export-pkg reported no package folder, so there is nothing to hand out")
    destination.mkdir(parents=True, exist_ok=True)
    found = []
    for built in sorted((Path(folder) / "deb").glob("*.deb")):
        copied = destination / built.name
        shutil.copy2(built, copied)
        found.append(copied)
    return found


def frameworks_of(staged):
    return sorted(path.stem for path in staged.glob("*" + FRAMEWORK))


def back_up_engine(device, remote, frameworks):
    names = " ".join(frameworks)
    device.run(30, "mkdir -p {remote}.bak; for fw in {names}; do "
                   "cp -f {remote}/$fw{suffix}/$fw {remote}.bak/$fw 2>/dev/null || true; done".format(
                       remote=remote, names=names, suffix=FRAMEWORK), capture=False, check=True)
    held = sorted(device.output(20, "ls {}.bak 2>/dev/null".format(remote)).split())
    if held:
        say("{}.bak holds what is being replaced ({}) - the only way back".format(remote, ", ".join(held)))
    else:
        warn("{}.bak is empty - this deploy has nothing to roll back to".format(remote))


def install_frameworks(device, staged, remote, frameworks):
    for framework in frameworks:
        say("installing {}".format(framework))
        bundle = framework + FRAMEWORK
        if not device.copy(staged / bundle / framework, "{}/{}/{}".format(remote, bundle, framework), capture=False):
            raise Failure("copying {} to the phone failed".format(framework))
        directory = staged / bundle
        entries = sorted(entry.name for entry in directory.iterdir()
                         if not entry.name.startswith(".") and entry.name != framework)
        if not entries:
            continue
        say("installing {} resources ({} entries)".format(framework, len(entries)))
        status = device.pipe_into(["tar", "--no-xattrs", "-czf", "-"] + entries,
                                  "cd {}/{} && tar xzf - && chmod -R 755 . 2>/dev/null".format(remote, bundle),
                                  cwd=directory)
        if status:
            raise Failure("streaming {} resources to the phone failed (exit {})".format(framework, status))


def deploy_frameworks(root, tree, device):
    staged = staged_frameworks(tree)
    if staged is None:
        raise Failure("{} holds no laid-out frameworks - run charon build first".format(tree / STAGE))
    remote = device_location(staged)
    frameworks = frameworks_of(staged)
    say("deploying {} to {} {}".format(staged, device.where(), remote))
    if not device.reachable(12):
        raise Failure("the phone at {} is unreachable".format(device.where()))
    back_up_engine(device, remote, frameworks)
    install_frameworks(device, staged, remote, frameworks)
    device.run(20, "chmod 755 {}/*/* 2>/dev/null; echo installed".format(remote), capture=False, check=True)

    sidecars = [line for line in device.output(30, "find {} -name '._*'".format(remote)).split() if line]
    if sidecars:
        raise Failure("{} now holds {} AppleDouble files, the first being {}. The producer lost "
                      "COPYFILE_DISABLE: tar --no-xattrs removes the extended-attribute headers and none of "
                      "these.".format(remote, len(sidecars), sidecars[0]))

    say("restarting Mobile Safari (no respring)")
    device.run(15, "killall MobileSafari")
    say("deployed {}".format(", ".join(frameworks)))


def verb_deploy(root, parsed):
    provenance(root, parsed.chosen_profile)
    deploy_frameworks(root, engine_build(root, parsed.variant), transport(root))


def bundle_facts(app):
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    executable = info.get("CFBundleExecutable")
    schemes = [scheme for entry in info.get("CFBundleURLTypes", []) for scheme in entry.get("CFBundleURLSchemes", [])]
    if not executable or not schemes:
        raise Failure("{}/Info.plist names no executable or no URL scheme to launch it with".format(app))
    return executable, schemes[0]


def launch_script(wait, url, scheme, log, url_file):
    lines = ["rm -f {} {}".format(log, url_file)]
    if url:
        lines.append("echo '{}' > {}".format(url, url_file))
    lines += [
        "su mobile -c uicache >/dev/null 2>&1",
        "sleep 4",
        "uiopen {}://".format(scheme),
        "sleep {}".format(wait),
        "echo '--- {} ---'".format(os.path.basename(log)),
        "cat {} 2>&1".format(log),
    ]
    return "\n".join(lines)


def verb_run(root, parsed):
    trees = [tree for tree in build_trees(root) if standalone_app(tree) is not None]
    tree = sole_tree(root, trees, "holding an application", parsed.variant)
    app = standalone_app(tree)
    log = parsed.log or declared(root, "application", "log")
    url_file = parsed.url_file or declared(root, "application", "first-page")
    if not log or not url_file:
        raise Failure("{} declares no [application] log and first-page, and nothing was passed".format(
            root / MANIFEST))
    executable, scheme = bundle_facts(app)
    remote = "{}/{}".format(APPLICATIONS, app.name)
    device = transport(root)
    say("installing {} ({}) on {}".format(app.name, megabytes(tree_size(app)), device.where()))
    if not device.reachable(20):
        raise Failure("the phone at {} is unreachable".format(device.where()))
    device.run(40, "killall -9 {} 2>/dev/null; rm -rf {}".format(executable, remote))
    status = device.pipe_into(["tar", "--no-xattrs", "-czf", "-", app.name],
                             "cd {} && tar xzf - && chmod +x {}/{}".format(APPLICATIONS, remote, executable),
                             cwd=app.parent)
    if status:
        raise Failure("copying {} to the phone failed (exit {})".format(app.name, status))
    result = device.run(parsed.wait + 60,
                        launch_script(parsed.wait, parsed.url, scheme, log, url_file),
                        capture=False)
    if result.returncode:
        raise Failure("launching {} failed (exit {})".format(app.name, result.returncode))


def exit_status(call, **arguments):
    try:
        return call(**arguments)
    except SystemExit as stop:
        return stop.code if isinstance(stop.code, int) else 1


def declared_entry(root, reference):
    path, _, function = reference.partition(":")
    script = root / path
    if not script.is_file():
        raise Failure("{} does not exist, and the declaration names it".format(script))
    return script, function


def loaded_entry(root, reference):
    script, function = declared_entry(root, reference)
    module = import_file(script, "charon_" + script.stem.replace("-", "_"))
    target = getattr(module, function, None)
    if target is None:
        raise Failure("{} has no {}".format(script, function))
    return target


def call_declared(root, reference, available):
    script, function = declared_entry(root, reference)
    if not function:
        return subprocess.run([sys.executable, str(script)], cwd=str(root)).returncode
    target = loaded_entry(root, reference)
    wanted = inspect.signature(target).parameters
    missing = [name for name, parameter in wanted.items()
               if parameter.default is inspect.Parameter.empty and name not in available]
    if missing:
        raise Failure("{}:{} asks for {}, which this tier does not provide; declare it under needs".format(
            script, function, ", ".join(missing)))
    return exit_status(target, **{name: available[name] for name in wanted if name in available})


def tier_packages(root, parsed, name, wanted):
    folder = generated(root, parsed.variant or default_variant(root))
    if folder is None:
        raise Failure("the {} tier names packages, which only a declaration can ask for".format(name))
    recipe = folder / TESTS / name
    if not (recipe / RECIPE).is_file():
        raise Failure("{} was not written, and it is what asks for the packages the {} tier needs".format(
            recipe / RECIPE, name))
    output = root / BUILD / "tier-packages" / name
    output.mkdir(parents=True, exist_ok=True)
    locked = ["--lockfile", str(root / LOCK), "--lockfile-partial"] if (root / LOCK).is_file() else []
    conan("install", recipe, "-pr:h", "default", "-pr:b", "default", "--build=missing",
          *locked, "--output-folder", output)
    written = output / DEPENDENCY_ENV
    if not written.is_file():
        raise Failure("conan install left no {}, so nothing says where the {} tier's packages are".format(
            written, name))
    found = {}
    for line in written.read_text().splitlines():
        key, _, value = line.partition("=")
        if key.startswith(HOST_PREFIX):
            found[key[len(HOST_PREFIX):].lower()] = Path(value)
    absent = [package for package in wanted if package.lower() not in found]
    if absent:
        raise Failure("{} installed the {} tier's packages and {} is not among what it wrote to {}".format(
            recipe / RECIPE, name, ", ".join(absent), written))
    return found


def tier_inputs(root, parsed, name, tier, device):
    needs = tier.get("needs", [])
    available = {"root": root, "host": parsed.host, "port": parsed.test_port}
    if "device" in needs:
        available["device"] = device
    if "build" in needs:
        available["build"] = engine_build(root, parsed.variant)
    wanted = tier.get("packages")
    if wanted:
        available["packages"] = tier_packages(root, parsed, name, wanted)
    return available


def bind_transport(root, declared, device):
    reference = declared.get("transport")
    if not reference:
        return
    binder = loaded_entry(root, reference)
    binder(device)


def declared_tiers(root):
    declared = manifest(root).get(TESTS, {})
    tiers = {name: value for name, value in declared.items() if isinstance(value, dict)}
    if not tiers:
        raise Failure("{} declares no tiers under [tests], so there is nothing to run and reporting success "
                      "would say a port is tested when nothing ran".format(root / MANIFEST))
    return declared, tiers


def tiers_by_phone(tiers, wants_phone):
    return [name for name, tier in tiers.items() if ("device" in tier.get("needs", [])) == wants_phone]


def verb_test(root, parsed):
    provenance(root, parsed.chosen_profile)
    declared, tiers = declared_tiers(root)
    if parsed.tier == "all":
        chosen = list(tiers)
    elif parsed.tier in tiers:
        chosen = [parsed.tier]
    else:
        raise Failure("{} declares no tier {} ({})".format(root / MANIFEST, parsed.tier, ", ".join(tiers)))

    say("tiers        declared: {}".format(", ".join(tiers)))
    if chosen != list(tiers):
        say("tiers        running: {}".format(", ".join(chosen)))
    run_tiers(root, parsed, declared, tiers, chosen)


def run_tiers(root, parsed, declared, tiers, chosen):
    if not chosen:
        say("tiers        none of this kind declared")
        return
    bound = {}

    def device_for(needs):
        if "device" not in needs:
            return None
        if "device" not in bound:
            bound["device"] = transport(root)
            bind_transport(root, declared, bound["device"])
        return bound["device"]

    results = {}
    for name in chosen:
        tier = tiers[name]
        runs = tier.get("runs") or []
        if not runs:
            raise Failure("tier {} declares nothing to run".format(name))
        say("\n=== tier: {} ({})".format(name, ", ".join(tier.get("needs", [])) or "nothing needed"))
        available = tier_inputs(root, parsed, name, tier, device_for(tier.get("needs", [])))
        status = 0
        for reference in runs:
            status = call_declared(root, reference, available) or status
        results[name] = status
    say("")
    for name, status in results.items():
        say("{}: {}".format(name, "FAILED ({})".format(status) if status else "PASSED"))
    failed = [name for name, status in results.items() if status]
    if failed:
        raise Failure("tiers failed: {}".format(", ".join(failed)))


def submodule(root):
    modules = root / ".gitmodules"
    if not modules.is_file():
        raise Failure("{} has no submodule, so there is no upstream tree to merge into".format(root))
    paths = [line.split("=", 1)[1].strip() for line in modules.read_text().splitlines()
             if line.strip().startswith("path")]
    if len(paths) != 1:
        raise Failure("{} names {} submodules; integrate expects exactly one upstream tree".format(
            modules, len(paths)))
    return root / paths[0]


def git(*arguments, **options):
    argv = ["git"] + [str(part) for part in arguments]
    return subprocess.run(argv, **options)


def head_of(tree):
    return git("-C", tree, "rev-parse", "HEAD", stdout=subprocess.PIPE, text=True, check=True).stdout.strip()


def merge_upstream(root, reference):
    tree = submodule(root)
    remote, _, branch = reference.partition("/")
    if git("-C", tree, "fetch", "--filter=blob:none", remote,
           "refs/heads/{}:refs/remotes/{}".format(branch or reference, reference)).returncode:
        raise Failure("fetching {} failed".format(reference))
    before = head_of(tree)
    if git("-C", tree, "merge", "--no-edit", reference).returncode:
        raise Failure("merge conflicts left in {}: resolve them, commit, then run again with --no-merge".format(tree))
    if head_of(tree) == before:
        say("already up to date")


def task_steps(root, names):
    declared = manifest(root).get("tasks", {})
    known = ", ".join(sorted(declared)) or "none declared"
    if not names:
        raise Failure("charon task needs the names of the tasks to run ({})".format(known))
    unknown = [name for name in names if name not in declared]
    if unknown:
        raise Failure("{} declares no task {} ({})".format(root / MANIFEST, ", ".join(unknown), known))
    return ["task:{}".format(name) for name in names]


def run_steps(root, parsed, steps):
    build_variant(root, parsed, parsed.variant or default_variant(root),
                  ["-c", "user.charon:steps={!r}".format(list(steps))])


def verb_task(root, parsed):
    provenance(root, parsed.chosen_profile)
    run_steps(root, parsed, task_steps(root, parsed.extra))


def verb_integrate(root, parsed):
    if not parsed.step and not manifest(root):
        raise Failure("{} does not exist, and integrate runs the gates a port declares there. Without it this "
                      "would quietly run none and report the integration green.".format(root / MANIFEST))
    tree = submodule(root)
    git("-C", tree, "config", "rerere.enabled", "true")
    steps = []
    if parsed.ref:
        steps.append(("merging {}".format(parsed.ref), lambda: merge_upstream(root, parsed.ref)))
    before = parsed.step or declared(root, "integrate", "before-build", [])
    if before:
        steps.append(("before the build: {}".format(", ".join(before)),
                      lambda: run_steps(root, parsed, before)))
    tests, tiers = declared_tiers(root)
    steps += [
        ("build", lambda: verb_build(root, parsed)),
        ("tiers that need no phone",
         lambda: run_tiers(root, parsed, tests, tiers, tiers_by_phone(tiers, False))),
        ("deploy", lambda: verb_deploy(root, parsed)),
        ("tiers that need the phone",
         lambda: run_tiers(root, parsed, tests, tiers, tiers_by_phone(tiers, True))),
    ]
    for title, step in steps:
        say("\n=== {}".format(title))
        step()
    say("\nintegration green")


def locked_references(path):
    with open(path) as lock:
        content = json.load(lock)
    references = set()
    for section in ("requires", "build_requires", "python_requires"):
        for entry in content.get(section) or []:
            references.add(entry.split("#")[0])
    return references


def verb_clean(root, parsed):
    folder = root / BUILD
    removed = 0
    if folder.is_dir():
        busy = users_of(folder)
        if busy:
            raise Failure("{} is in use by:\n  {}\nWait for that build: removing its tree leaves a corrupt "
                          "one behind.".format(folder, "\n  ".join(busy)))
        for tree in sorted(path for path in folder.iterdir() if path.is_dir()):
            size = tree_size(tree)
            removed += size
            say("build tree {}: {}".format(tree, megabytes(size)))
            if parsed.force:
                shutil.rmtree(tree)
    else:
        say("no build trees under {}".format(folder))

    if parsed.cache and parsed.force:
        conan("cache", "clean", "*", "-s", "-b", "-d")
    elif parsed.cache:
        say("cache: the source, build and download folders of every package in this home would be dropped")

    if parsed.unused:
        lock = root / LOCK
        if not lock.is_file():
            raise Failure("{} is missing, and it is what says which references belong to this port; without it "
                          "an unused sweep would reach into every other port sharing this cache".format(lock))
        for reference in sorted(locked_references(lock)):
            arguments = ["remove", reference, "--lru", parsed.unused]
            arguments += ["-c"] if parsed.force else ["--dry-run"]
            conan(*arguments, check=False)

    say("build trees: {} {}".format(megabytes(removed), "removed" if parsed.force else "would be removed"))
    if not parsed.force:
        say("nothing was deleted; add --force")


def remotes():
    result = conan("remote", "list", "--format=json", stdout=subprocess.PIPE, text=True)
    return json.loads(result.stdout or "[]")


def resolved_conf(chosen_profile):
    result = conan("profile", "show", "-pr:h", chosen_profile, "-pr:b", "default", "--format=json",
                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
    try:
        answered = json.loads(result.stdout or "{}") or {}
    except json.JSONDecodeError:
        return {}
    return (answered.get("host") or {}).get("conf") or {}


def check_declared_conf(root, chosen_profile):
    declared = manifest(root).get("conf", {})
    if not declared:
        return
    resolved = resolved_conf(chosen_profile)
    for key in sorted(declared):
        if isinstance(declared[key], dict):
            say("conf         {} is set by the declaration: {}".format(key, declared[key].get("why")))
        elif resolved.get(key):
            say("conf         {} is set".format(key))
        else:
            warn("conf         {} is empty, and this port needs it: {}".format(key, declared[key]))


def shared_profiles():
    try:
        import generate
        import spec
        import tomllib
    except ImportError as missing:
        raise Failure("generate.py and spec.py are not beside the driver: {}".format(missing))
    written = {}
    for path in sorted(spec.PLATFORMS.glob("*.toml")):
        with path.open("rb") as handle:
            facts = tomllib.load(handle)
        for arch, described in sorted((facts.get("architectures") or {}).items()):
            bounds = dict(facts.get("os-version") or {}, **(described.get("os-version") or {}))
            if "min" not in bounds:
                raise Failure("{} gives {} no oldest release, and a shared profile targets the oldest".format(
                    path, arch))
            declared = spec.Spec(Path("/"), {"platform": {"use": path.stem, "arch": arch,
                                                          "os-version": bounds["min"]}})
            try:
                written["{}-{}".format(path.stem, arch)] = generate.platform_profile({}, {}, declared.platform())
            except (generate.GenerationError, spec.SpecError) as refused:
                raise Failure(str(refused))
    return written


def verb_profiles(root, parsed):
    home = conan("config", "home", stdout=subprocess.PIPE, text=True).stdout.strip()
    folder = Path(home) / "profiles"
    folder.mkdir(parents=True, exist_ok=True)
    for name, text in shared_profiles().items():
        (folder / name).write_text(text)
        say("profile      {} (written from its platform)".format(folder / name))


TEMPLATES = Path(__file__).resolve().parent / "templates"
PORT_NAME = re.compile(r"^[a-z][a-z0-9-]*$")


def template_values(name, identifier=None, maintainer=None):
    if not PORT_NAME.match(name):
        raise Failure("{} is not a port name Charon can use everywhere a port's name goes: lower-case letters, "
                      "digits and dashes, starting with a letter".format(name))
    camel = "".join(part.capitalize() for part in name.split("-"))
    return {"name": name, "Name": camel, "symbol": name.replace("-", "_"),
            "identifier": identifier or "com.example.{}".format(name.replace("-", "")),
            "maintainer": maintainer or "unknown"}


def write_template(kind, destination, values, templates=TEMPLATES):
    import string
    source = templates / kind
    if not source.is_dir():
        known = sorted(folder.name for folder in templates.iterdir() if folder.is_dir())
        raise Failure("there is no {} template; Charon has {}".format(kind, ", ".join(known)))
    if destination.exists() and any(destination.iterdir()):
        raise Failure("{} already holds files, and a new port is written only into an empty folder".format(
            destination))
    written = []
    for path in sorted(source.rglob("*")):
        if path.is_dir():
            continue
        relative = string.Template(str(path.relative_to(source))).substitute(values)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(string.Template(path.read_text()).substitute(values))
        written.append(target)
    ignore = destination / ".gitignore"
    ignore.write_text((templates / "gitignore").read_text())
    return written + [ignore]


def verb_new(root, parsed):
    if len(parsed.extra) != 2:
        known = sorted(folder.name for folder in TEMPLATES.iterdir() if folder.is_dir())
        raise Failure("charon new KIND NAME [--identifier ID]: KIND is one of {}".format(", ".join(known)))
    kind, name = parsed.extra
    values = template_values(name, parsed.identifier or None, os.environ.get("CHARON_MAINTAINER"))
    destination = Path.cwd() / name
    for path in write_template(kind, destination, values):
        say("wrote        {}".format(path))
    say("next         cd {} && charon build && charon package".format(name))


def install_launcher(launcher, path=None):
    launcher = Path(launcher)
    folders = [Path(folder) for folder in (path if path is not None else os.environ.get("PATH", "")).split(os.pathsep)
               if folder]
    for folder in folders:
        existing = folder / "charon"
        if existing.exists() or existing.is_symlink():
            if existing.resolve() == launcher.resolve():
                return existing, False
            raise Failure("{} is on PATH and is not {}; remove it or put Charon's launcher there yourself".format(
                existing, launcher))
    for folder in folders:
        if folder.is_dir() and os.access(folder, os.W_OK):
            linked = folder / "charon"
            linked.symlink_to(launcher)
            return linked, True
    raise Failure("no folder on PATH is writable, so `charon` cannot be put there; link {} into one".format(launcher))


def verb_setup(root, parsed):
    shared = [Path(folder).expanduser().resolve() for folder in parsed.extra]
    for folder in shared:
        if not (folder / "config" / "extensions" / "charon").is_dir():
            raise Failure("setup takes the path of the Charon checkout - the folder holding config/ - and {} is not "
                          "one{}".format(folder, "; it is a port" if (folder / MANIFEST).is_file() else ""))
    for folder in shared:
        register(folder.name, folder)
    if (root / "recipes").is_dir():
        register(declared(root, "port", "index") or port_name(root), root)
    for folder in shared:
        conan("config", "install", folder / "config")
    say("remotes now: {}".format(", ".join(remote["name"] for remote in remotes())))
    home = conan("config", "home", stdout=subprocess.PIPE, text=True).stdout.strip()
    linked, created = install_launcher(Path(home) / "extensions" / "charon" / "charon")
    say("launcher     {} ({})".format(linked, "linked" if created else "already there"))
    verb_profiles(root, parsed)
    check_indexes(canonical=True)
    check_declared_conf(root, parsed.chosen_profile)


def publish_plan(recipes, packages):
    archived, withheld, refused = [], [], []
    for reference, described in sorted(recipes.items()):
        if described.get("upload_policy") == "skip":
            withheld.append((reference, described))
            continue
        for package, folder in packages.get(reference, []):
            licenses = Path(folder) / "licenses"
            if not licenses.is_dir() or not any(licenses.iterdir()):
                refused.append("{}:{} carries no licenses folder, and a package is only handed on with the terms "
                               "it came under".format(reference, package))
        archived.append((reference, described))
    return archived, withheld, refused


def recipe_references(index):
    serving = [remote["name"] for remote in local_index_remotes() if Path(remote["url"]).resolve() == Path(index)]
    if not serving:
        raise Failure("{} is not registered as a recipe index, so nothing says which of its versions it serves; "
                      "register it with charon setup first".format(index))
    found = {}
    for recipe in sorted(Path(index).glob("recipes/*")):
        folders = sorted(folder for folder in recipe.iterdir() if (folder / RECIPE).is_file())
        if not folders:
            continue
        described = json.loads(conan("inspect", folders[0], "--format=json", stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True).stdout)
        suffix = "@{}/{}".format(described["user"], described["channel"]) if described.get("user") else ""
        served = conan("list", "{}/*{}".format(described["name"], suffix), "-r", serving[0], "--format=json",
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
        for reference in json.loads(served.stdout or "{}").get(serving[0]) or {}:
            found[reference] = described
    return found


def cached_packages(reference):
    listed = conan("list", "{}#latest:*".format(reference), "--format=json", stdout=subprocess.PIPE,
                   stderr=subprocess.DEVNULL, text=True, check=False)
    cache = (json.loads(listed.stdout or "{}").get("Local Cache") or {}).get(reference) or {}
    found = []
    for revision, described in (cache.get("revisions") or {}).items():
        for package, info in (described.get("packages") or {}).items():
            folder = conan("cache", "path", "{}#{}:{}".format(reference, revision, package), stdout=subprocess.PIPE,
                           text=True).stdout.strip()
            settings = (info.get("info") or {}).get("settings") or {}
            found.append((package, folder, settings))
    return found


def verb_publish(root, parsed):
    if len(parsed.extra) != 2:
        raise Failure("charon publish INDEX OUT: the recipe index whose packages to archive, and the folder to "
                      "write the archive and its licenses to")
    index, out = (Path(argument).expanduser().resolve() for argument in parsed.extra)
    recipes = recipe_references(index)
    found = {reference: cached_packages(reference) for reference in recipes}
    archived, withheld, refused = publish_plan(recipes, {reference: [(package, folder) for package, folder, _ in
                                                                     listed] for reference, listed in found.items()})
    if refused:
        raise Failure("; ".join(refused))
    out.mkdir(parents=True, exist_ok=True)
    selection = [reference for reference, _ in archived if found[reference] or recipes[reference].get(
        "package_type") == "python-require"]
    listing = {"Local Cache": {}}
    for reference in selection:
        listed = conan("list", "{}#latest:*#latest".format(reference), "--format=json", stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, text=True)
        listing["Local Cache"].update(json.loads(listed.stdout)["Local Cache"])
    origin = subprocess.run(["git", "-C", str(index), "remote", "get-url", "origin"], stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True).stdout.strip()
    name = Path(origin).name[:-len(".git")] if origin.endswith(".git") else (Path(origin).name or index.name)
    selected = out / "{}-packages.json".format(name)
    selected.write_text(json.dumps(listing, indent=2))
    archive = out / "{}-packages.tgz".format(name)
    conan("cache", "save", "--list", selected, "--no-source", "--file", archive)
    lines = ["# Packages in {}".format(archive.name), "",
             "Restore with `conan cache restore {}`. Each package carries its licenses under `licenses/`; "
             "sources are where each recipe fetches them.".format(archive.name), "",
             "| Package | License | Source | Binaries |", "| --- | --- | --- | --- |"]
    for reference, described in archived:
        if reference not in selection:
            continue
        binaries = ", ".join(sorted("{} {} {}".format(settings.get("os", "any"), settings.get("arch", "any"),
                                                       settings.get("os.version", "")).strip()
                                    for _, _, settings in found[reference])) or "recipe only"
        license = described.get("license")
        license = " AND ".join(license) if isinstance(license, (list, tuple)) else license
        lines.append("| `{}` | {} | {} | {} |".format(reference, license, described.get("homepage") or origin,
                                                      binaries))
    if withheld:
        lines += ["", "Not included, because their terms do not allow handing them on; each is fetched on the "
                  "machine that uses it:", ""]
        lines += ["- `{}` ({})".format(reference, described.get("license")) for reference, described in withheld]
    (out / "{}-packages.md".format(name)).write_text("\n".join(lines) + "\n")
    say("archive      {} ({} references)".format(archive, len(selection)))
    say("licenses     {}".format(out / "{}-packages.md".format(name)))


def port_name(root):
    declared = manifest(root).get("port", {}).get("name")
    if declared:
        return declared
    if not (root / RECIPE).is_file():
        return root.name
    result = conan("inspect", root, "--format=json", stdout=subprocess.PIPE, text=True)
    return json.loads(result.stdout or "{}").get("name") or root.name


def serving(folder):
    for remote in remotes():
        url = remote.get("url") or ""
        if url.startswith("/") and Path(url).expanduser().resolve() == folder:
            return remote["name"]
    return None


def register(name, folder):
    if not (folder / "recipes").is_dir():
        raise Failure("{} holds no recipes to serve".format(folder))
    known = [remote["name"] for remote in remotes()]
    held = serving(folder)
    if name in known:
        conan("remote", "update", name, "--url", folder, "--index", "0")
        say("{} serves {} ahead of the general remotes".format(name, folder))
    elif held:
        conan("remote", "update", held, "--index", "0")
        say("{} already serves {}; it now answers before the general remotes".format(held, folder))
    else:
        conan("remote", "add", name, folder, "-t", "local-recipes-index", "--index", "0")
        say("{} serves {} ahead of the general remotes".format(name, folder))


def verb_device(root, parsed):
    device = import_file(Path(__file__).resolve().parent / "device.py", "charon_device")
    raise SystemExit(device.main(["--root", str(root)] + parsed.extra))


def verb_help(root, parsed):
    say(__doc__.strip())
    say("")
    for name, description in VERBS:
        say("  {:<11} {}".format(name, description))


VERBS = (
    ("build", "compile everything this port produces"),
    ("generate", "write the recipe and the CMake a declaration asks for, without building"),
    ("task", "run declared tasks by name, the way the pipeline runs them: charon task NAME [NAME...]"),
    ("package", "the installable package, from what was built"),
    ("install", "package and install the .deb on the phone, refusing to replace another app's identity"),
    ("deploy", "install the staged frameworks on the phone"),
    ("run", "install and launch the standalone application"),
    ("test", "the tiers: gate, batteries, host"),
    ("integrate", "one upstream update through every gate, cheapest first"),
    ("clean", "what builds leave behind, reported unless --force"),
    ("lock", "pin every variant's graph to what the indexes serve now, in conan.lock"),
    ("setup", "register this port's recipes, and the toolchain's, ahead of the general remotes"),
    ("device", "reach the phone directly: run, copy, fetch, where, log [SECONDS] [TEXT]"),
    ("profiles", "write a shared host profile for every architecture of every platform Charon knows"),
    ("where", "the folder of a package the build uses: charon where pkg:NAME or tool:NAME"),
    ("publish", "archive an index's built packages with their licenses: charon publish INDEX OUT"),
    ("new", "start a port from a template: charon new tweak|daemon|app NAME [--identifier ID]"),
    ("provenance", "which driver, interpreter, port, profile and phone are in use"),
    ("help", "this list"),
)

HANDLERS = {
    "build": verb_build,
    "generate": verb_generate,
    "task": verb_task,
    "package": verb_package,
    "install": verb_install,
    "where": verb_where,
    "profiles": verb_profiles,
    "publish": verb_publish,
    "new": verb_new,
    "deploy": verb_deploy,
    "run": verb_run,
    "test": verb_test,
    "integrate": verb_integrate,
    "clean": verb_clean,
    "lock": verb_lock,
    "setup": verb_setup,
    "device": verb_device,
    "provenance": lambda root, parsed: provenance(root, parsed.chosen_profile),
    "help": verb_help,
}


def parse(argv):
    parser = argparse.ArgumentParser(prog="charon", add_help=False)
    parser.add_argument("--root", help="the port's folder; default: the one holding the current directory")
    parser.add_argument("--profile", help="host profile; default: the only one under the port's profiles/")
    parser.add_argument("verb", nargs="?", default="help", choices=[name for name, _ in VERBS])
    parser.add_argument("--variant", default="", help="build tree under build/ to act on, when there is more than one")
    parser.add_argument("--device", default="", help="which phone: device.NAME.env beside device.env")
    parser.add_argument("--identifier", default="", help="new: the package and bundle identifier")
    parser.add_argument("--wait", type=int, default=20, help="seconds to let a launched application run")
    parser.add_argument("--url", default="", help="page the application opens first")
    parser.add_argument("--log", default="", help="log the application writes on the phone")
    parser.add_argument("--url-file", default="", help="file the application reads its first page from")
    parser.add_argument("--host", help="address the phone reaches this machine on, for the gate's page server")
    parser.add_argument("--test-port", type=int, help="port the gate serves its pages on")
    parser.add_argument("--tier", default="all", help="which declared test tier to run (default: every one)")
    parser.add_argument("--ref", help="upstream ref to merge before integrating")
    parser.add_argument("--step", action="append", default=[],
                        help="a declared step integrate runs before building, e.g. task:carry-check")
    parser.add_argument("--force", action="store_true", help="clean: delete instead of reporting")
    parser.add_argument("--cache", action="store_true", help="clean: also the cache's source and build folders")
    parser.add_argument("--unused", help="clean: also this port's cached packages unused for this long, e.g. 30d")
    parser.add_argument("extra", nargs="*", default=[])
    parsed, unknown = parser.parse_known_args(argv)
    parsed.extra = list(parsed.extra) + unknown
    return parsed


def main(argv):
    ensure_interpreter(argv)
    parsed = parse(argv)
    if parsed.device:
        os.environ["CHARON_DEVICE"] = parsed.device
    if parsed.verb == "help":
        verb_help(None, parsed)
        return 0
    if parsed.verb in ("profiles", "publish", "new"):
        HANDLERS[parsed.verb](None, parsed)
        return 0
    root = find_port(parsed.root)
    parsed.chosen_profile = profile(root, parsed)
    HANDLERS[parsed.verb](root, parsed)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Failure as failure:
        warn("charon: {}".format(failure))
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)

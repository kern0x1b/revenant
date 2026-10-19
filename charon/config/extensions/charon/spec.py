"""Read a port's charon.toml and answer questions about it.

Substitution is deliberately split. Names this module can resolve are the ones
Charon knows without a dependency graph - paths, the target, what the build
produced. Names it cannot are left in place for the generated recipe to resolve
where the graph exists. An unknown name is an error rather than an empty string:
a flag that silently loses its value builds something that fails elsewhere.
"""
import copy
import re
from pathlib import Path

MANIFEST = "charon.toml"
PLATFORMS = Path(__file__).resolve().parent / "platforms"
PLATFORM_SAYS = ("os", "os-version", "arch", "sdk", "include-profiles", "system-name")
TARGET_KINDS = ("static-library", "device-library", "executable", "application")
BUILDING_VARIANT = "for-variant"
PLACEHOLDER = re.compile(r"\{([a-z][a-z0-9_.-]*(?::[^{}]*)?)\}")
GRAPH_PREFIXES = ("pkg", "include", "lib", "libdirs", "bin")

PATHS = {
    "sources": ".",
    "engine": "",
    "build": "build",
    "tasks": "tasks",
    "package": "packaging",
    "profiles": "",
    "recipe": "",
    "tests": "tests",
}


class SpecError(Exception):
    pass


def _release(text):
    return tuple(int(part) for part in str(text).split("."))


def with_implicit_variants(content):
    pipelines = content.get("pipeline")
    if "variants" not in content and isinstance(pipelines, dict) and pipelines:
        content = dict(content, variants={name: {} for name in pipelines})
    return content


def load(root):
    import tomllib
    path = Path(root) / MANIFEST
    if not path.is_file():
        return None
    with path.open("rb") as handle:
        try:
            return Spec(Path(root), with_implicit_variants(tomllib.load(handle)))
        except tomllib.TOMLDecodeError as broken:
            raise SpecError("{} is not readable: {}".format(path, broken))


def placeholders(text):
    return [match.group(1) for match in PLACEHOLDER.finditer(text)]


def is_graph_name(name):
    return name.split(":", 1)[0] in GRAPH_PREFIXES


def substitute(text, known, keep_graph_names=True):
    def replace(match):
        name = match.group(1)
        if name in known:
            return str(known[name])
        if keep_graph_names and is_graph_name(name):
            return match.group(0)
        raise SpecError("{{{}}} in {!r} resolves to nothing; every name must have a value".format(name, text))
    return PLACEHOLDER.sub(replace, text)


class Spec:
    def __init__(self, root, content):
        self.root = Path(root)
        self.content = content

    def section(self, name, default=None):
        value = self.content.get(name)
        return value if value is not None else ({} if default is None else default)

    def get(self, section, key, default=None):
        return self.section(section).get(key, default)

    def require(self, section, key):
        value = self.get(section, key)
        if value in (None, ""):
            raise SpecError("{} declares no {}.{}".format(self.root / MANIFEST, section, key))
        return value

    def path(self, name):
        if name not in PATHS:
            raise SpecError("{} is not a path Charon knows; known: {}".format(name, ", ".join(sorted(PATHS))))
        declared = self.get("paths", name, PATHS[name])
        return self.root / declared if declared else None

    def using(self, name):
        declared = self.get("use", name, "")
        return self.root / declared if declared else None

    def variants(self):
        return self.section("variants")

    def variant(self, name):
        variants = self.variants()
        if name not in variants:
            known = ", ".join(sorted(variants)) or "none declared"
            raise SpecError("{} declares no variant {} ({})".format(self.root / MANIFEST, name, known))
        return variants[name]

    def for_variant(self, name):
        variant = self.variant(name)
        content = copy.deepcopy(self.content)
        if variant.get("target"):
            content["target"] = dict(content.get("target") or {}, **variant["target"])
        if variant.get("platform"):
            content["platform"] = dict(content.get("platform") or {}, **variant["platform"])
        if variant.get("conf"):
            content["conf"] = dict(content.get("conf") or {}, **variant["conf"])
        if variant.get("package"):
            content["package"] = dict(variant["package"])
        for target_name, override in (variant.get("targets") or {}).items():
            matched = False
            for kind in TARGET_KINDS:
                declared = content.get(kind)
                entries = [declared] if isinstance(declared, dict) else (declared or [])
                for entry in entries:
                    if entry.get("name") == target_name:
                        entry.update(copy.deepcopy(override))
                        matched = True
            if not matched:
                raise SpecError("{} variant {} overrides a target {} that nothing declares".format(
                    self.root / MANIFEST, name, target_name))
        content[BUILDING_VARIANT] = name
        return Spec(self.root, content)

    def platform(self):
        declared = self.section("platform")
        if not declared:
            return None
        import tomllib
        name = declared.get("use")
        if not name:
            raise SpecError("{} has a [platform] that names none with use".format(self.root / MANIFEST))
        candidates = [self.root / "platforms" / "{}.toml".format(name), PLATFORMS / "{}.toml".format(name)]
        found = next((candidate for candidate in candidates if candidate.is_file()), None)
        if found is None:
            known = sorted({path.stem for folder in (self.root / "platforms", PLATFORMS) if folder.is_dir()
                            for path in folder.glob("*.toml")})
            raise SpecError("{} uses the platform {}, which neither the port nor Charon defines ({})".format(
                self.root / MANIFEST, name, ", ".join(known) or "none"))
        with found.open("rb") as handle:
            facts = tomllib.load(handle)
        repeated = [key for key in PLATFORM_SAYS if key in self.section("target")]
        if repeated:
            raise SpecError("{} names {} under [target] and uses the {} platform, which says it; [platform] is the "
                            "one place for what the port builds for".format(self.root / MANIFEST,
                                                                            ", ".join(repeated), name))
        architectures = facts.get("architectures") or {}
        arch = declared.get("arch")
        if arch not in architectures:
            raise SpecError("{} builds for {} on {}, which builds for {}".format(
                self.root / MANIFEST, arch, name, ", ".join(sorted(architectures)) or "nothing"))
        version = declared.get("os-version")
        if not version:
            raise SpecError("{} names no os-version under [platform]; it is the oldest release the port runs on"
                            .format(self.root / MANIFEST))
        bounds = dict(facts.get("os-version") or {}, **(architectures[arch].get("os-version") or {}))
        if "min" in bounds and _release(version) < _release(bounds["min"]):
            raise SpecError("{} targets {} {} on {}, and {} starts at {}".format(
                self.root / MANIFEST, facts.get("os"), version, arch, name, bounds["min"]))
        if "max" in bounds and _release(version) > _release(bounds["max"]):
            raise SpecError("{} targets {} {} on {}, and {} ends at {}".format(
                self.root / MANIFEST, facts.get("os"), version, arch, name, bounds["max"]))
        distribution = declared.get("distribution")
        distributions = facts.get("distributions") or {}
        if distribution is not None and distribution not in distributions:
            raise SpecError("{} distributes as {}, which {} does not know ({})".format(
                self.root / MANIFEST, distribution, name, ", ".join(distributions) or "none"))
        unknown = sorted(set(declared) - {"use", "arch", "os-version", "distribution"})
        if unknown:
            raise SpecError("{} says {} under [platform], which Charon does not read".format(
                self.root / MANIFEST, ", ".join(unknown)))
        template = facts.get("cross-toolchain")
        return {
            "name": name,
            "python-requires": list(facts.get("python-requires") or []),
            "requires": list(facts.get("requires") or []),
            "extends": list(facts.get("extends") or []),
            "cross-toolchain": found.parent / template if template else None,
            "build-only": list(facts.get("build-only") or []),
            "frameworks": dict(facts.get("frameworks") or {}),
            "os": facts["os"],
            "sdk": facts.get("sdk"),
            "arch": arch,
            "os-version": str(version),
            "distribution": distribution,
            "distributed": dict(distributions.get(distribution) or {}),
            "deployment-environment": facts.get("deployment-environment"),
            "compiler": dict(facts.get("compiler") or {}),
            "conf": dict(facts.get("conf") or {}),
            "port-tool-requires": list(facts.get("port-tool-requires") or []),
            "tool-requires": list(facts.get("tool-requires") or []) + list(architectures[arch].get("tool-requires")
                                                                            or []),
        }

    def targets(self, kind):
        declared = self.content.get(kind) or []
        if isinstance(declared, dict):
            declared = [declared]
        for target in declared:
            if "name" not in target:
                raise SpecError("a {} in {} has no name".format(kind, self.root / MANIFEST))
        return declared

    def target(self, kind, name):
        for target in self.targets(kind):
            if target["name"] == name:
                return target
        raise SpecError("{} declares no {} called {}".format(self.root / MANIFEST, kind, name))

    def generates(self, target):
        return not target.get("cmake")

    def conf_required(self):
        return self.section("conf")

    def tiers(self):
        return {name: value for name, value in self.section("tests").items() if isinstance(value, dict)}

    def tier(self, name):
        declared = self.tiers()
        if name not in declared:
            known = ", ".join(sorted(declared)) or "none declared"
            raise SpecError("{} declares no test tier {} ({})".format(self.root / MANIFEST, name, known))
        return declared[name]

    def transport_binder(self):
        return self.get("tests", "transport")

    def tasks(self):
        return self.section("tasks")

    def task(self, name):
        declared = self.tasks()
        if name not in declared:
            known = ", ".join(sorted(declared)) or "none declared"
            raise SpecError("{} declares no task {} ({})".format(self.root / MANIFEST, name, known))
        return declared[name]

    def pipeline(self, variant):
        steps = self.get("pipeline", variant)
        if not steps:
            raise SpecError("{} declares no pipeline for the {} variant".format(self.root / MANIFEST, variant))
        return steps

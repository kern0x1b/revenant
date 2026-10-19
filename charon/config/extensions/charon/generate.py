"""Write what a port declared as the files the tools underneath expect.

Every function here returns text and touches no disk, so what it produces can be
read and compared in a test rather than inspected after a build. What it writes
goes into the build tree, never into the port: a file that can be generated is
not kept, and the one place to look for what built something is the tree it was
built in.

A generated project is configured from the build tree and not from the port, so
CMAKE_CURRENT_SOURCE_DIR is the folder Charon wrote into. Every path a
declaration names is therefore written against CHARON_PORT, which the build
passes; a value that already starts at the root, at a cmake variable or at a
flag is left exactly as declared.
"""
from pathlib import Path

import spec

LANGUAGES = {".c": "C", ".m": "OBJC", ".mm": "OBJCXX", ".cpp": "CXX", ".cc": "CXX", ".swift": "Swift"}
CMAKE_MINIMUM = "3.24"
GENERATED = "# Written by Charon from charon.toml. Edits here are lost on the next build."
PORT = "${CHARON_PORT}"
REQUIRES_PORT = ('if (NOT CHARON_PORT)\n'
                 '    message(FATAL_ERROR\n'
                 '        "CHARON_PORT names the folder charon.toml lives in, and every path below is written '
                 'against it; the build passes it")\n'
                 'endif ()')


class GenerationError(Exception):
    pass


def _quoted(value):
    return '"{}"'.format(value)


def _path(value):
    text = str(value)
    if text[:1] in ("/", "$", "-"):
        return text
    return "{}/{}".format(PORT, text)


def platform_profile(target, declared_conf, platform):
    lines = ["{% set detected = detect_api.detect_default_compiler() %}", "", "[settings]",
             "os={}".format(platform["os"]), "os.version={}".format(platform["os-version"])]
    if platform["sdk"]:
        lines.append("os.sdk={}".format(platform["sdk"]))
    lines += ["arch={}".format(platform["arch"]), "build_type={}".format(target.get("build-type", "Release")),
              "compiler={{ detected[0] }}",
              "compiler.version={{ detect_api.default_compiler_version(detected[0], detected[1]) }}"]
    for key, value in platform["compiler"].items():
        lines.append("compiler.{}={}".format(key, value))
    if "cppstd" in target:
        lines.append("compiler.cppstd={}".format(target["cppstd"]))
    if platform["tool-requires"]:
        lines += ["", "[tool_requires]"] + platform["tool-requires"]
    conf = {key: _conf_value(key, value) for key, value in platform["conf"].items()}
    for key, value in list(_tuning_conf(target).items()) + list(declared_conf.items()):
        if key in conf:
            raise GenerationError("{} is set twice, by the {} platform or [target] tuning and by the declaration; "
                                  "a second value would silently drop the first".format(key, platform["name"]))
        conf[key] = value
    if conf:
        lines += ["", "[conf]"] + ["{}={}".format(key, value) for key, value in conf.items()]
    if platform["deployment-environment"]:
        lines += ["", "[buildenv]", "{}={}".format(platform["deployment-environment"], platform["os-version"])]
    return "\n".join(lines) + "\n"


def _tuning_conf(target):
    tuning = []
    if "cpu" in target:
        tuning += ["-mcpu={}".format(target["cpu"]), "-mtune={}".format(target["cpu"])]
    if "fpu" in target:
        tuning.append("-mfpu={}".format(target["fpu"]))
    if not tuning:
        return {}
    rendered = "[{}]".format(", ".join(_quoted(flag) for flag in tuning))
    return {"tools.build:cflags": rendered, "tools.build:cxxflags": rendered}


def profile(declared):
    platform = declared.platform()
    if platform is None:
        raise GenerationError("{} declares no [platform], and it is what says what this port builds for".format(
            declared.root / spec.MANIFEST))
    return platform_profile(declared.section("target"), declared_conf_values(declared), platform)


PORT_FROM_PROFILE = "{{ os.path.normpath(os.path.join(profile_dir, os.pardir, os.pardir, os.pardir)) }}"
CONF_ENTRY = ("a [conf] entry is either a sentence saying why the port needs a value it does not set, "
              "or a table { value = ..., why = \"...\" } that sets it")


def _conf_value(key, value):
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[{}]".format(", ".join(_quoted(_conf_value(key, item)) for item in value))
    if not isinstance(value, str):
        raise GenerationError("[conf] {} has a value Charon cannot write into a profile: {!r}".format(key, value))
    rest = value.replace("{port}", "")
    if "{" in rest or "}" in rest:
        raise GenerationError("[conf] {} names a placeholder other than {{port}}, and a profile is read before "
                              "the graph that could answer it is resolved: {}".format(key, value))
    return value.replace("{port}", PORT_FROM_PROFILE)


def declared_conf_values(declared):
    values = {}
    for key, entry in declared.section("conf").items():
        if isinstance(entry, str):
            if not entry.strip():
                raise GenerationError("[conf] {} gives no reason; {}".format(key, CONF_ENTRY))
            continue
        if not isinstance(entry, dict) or set(entry) != {"value", "why"}:
            raise GenerationError("[conf] {}: {}".format(key, CONF_ENTRY))
        if not isinstance(entry["why"], str) or not entry["why"].strip():
            raise GenerationError("[conf] {} sets a value without saying why".format(key))
        values[key] = _conf_value(key, entry["value"])
    return values


PROJECT_LANGUAGE_ORDER = ("C", "CXX", "OBJC", "OBJCXX", "Swift")


def _languages(sources):
    found = set()
    for pattern in sources:
        suffix = pattern[pattern.rfind("."):] if "." in pattern else ""
        language = LANGUAGES.get(suffix)
        if language is None:
            raise GenerationError("{} is a source Charon cannot name a language for".format(pattern))
        found.add(language)
    return [language for language in PROJECT_LANGUAGE_ORDER if language in found]


def _is_pattern(text):
    return any(character in text for character in "*?[")


def _matches(root, pattern, name):
    if root is None:
        raise GenerationError("{} names {} as a pattern, which needs the port folder to expand".format(name, pattern))
    return sorted(path.relative_to(root).as_posix() for path in Path(root).glob(pattern) if path.is_file())


def _sources(target, root=None):
    name = target["name"]
    sources = target.get("sources")
    if not sources:
        raise GenerationError("{} declares no sources and no cmake= to use instead".format(name))
    excluded = set()
    for pattern in target.get("exclude", []):
        excluded.update(_matches(root, pattern, name))
    expanded = []
    for entry in sources:
        if _is_pattern(entry):
            found = _matches(root, entry, name)
            if not found:
                raise GenerationError("{}: {} matches no file under {}".format(name, entry, root))
        else:
            found = [entry]
        expanded += [path for path in found if path not in excluded and path not in expanded]
    if not expanded:
        raise GenerationError("{} declares sources and exclude takes every one of them".format(name))
    return expanded


LANGUAGE_KEYS = {"c": "C", "cxx": "CXX", "objc": "OBJC", "objcxx": "OBJCXX"}


def _directories(root, pattern, name):
    if root is None:
        raise GenerationError("{} names {} as a pattern, which needs the port folder to expand".format(name, pattern))
    return sorted(path.relative_to(root).as_posix() for path in Path(root).glob(pattern.rstrip("/"))
                  if path.is_dir())


def _folders(target, key, root):
    name = target["name"]
    excluded = set()
    for pattern in target.get("{}-exclude".format(key), []):
        excluded.update(_directories(root, pattern, name))
    expanded = []
    for entry in target.get(key) or []:
        text = str(entry)
        if text[:1] in ("/", "$", "-"):
            found = [text]
        elif _is_pattern(text):
            found = _directories(root, text, name)
            if not found:
                raise GenerationError("{}: {} matches no folder under {}".format(name, text, root))
        else:
            if root is not None and not (Path(root) / text).is_dir():
                raise GenerationError("{} names {} under {}, and there is no such folder; the compiler would drop "
                                      "it without a word".format(name, text, key))
            found = [text.rstrip("/")]
        expanded += [folder for folder in found if folder not in excluded and folder not in expanded]
    return expanded


def _per_language(target, key, compiled):
    table = target.get(key) or {}
    if not isinstance(table, dict):
        raise GenerationError("{} declares {} as {!r}; it is a table keyed by {}".format(
            target["name"], key, table, ", ".join(LANGUAGE_KEYS)))
    entries = []
    for language, values in table.items():
        if language not in LANGUAGE_KEYS:
            raise GenerationError("{} declares {} for {}, which is not one of {}".format(
                target["name"], key, language, ", ".join(LANGUAGE_KEYS)))
        cmake = LANGUAGE_KEYS[language]
        if values and cmake not in compiled:
            raise GenerationError("{} declares {} for {}, and none of its sources is {}; the values would apply "
                                  "to nothing".format(target["name"], key, language, language))
        entries += [(cmake, str(value)) for value in values]
    return entries


def _for_language(language, value, shell=False):
    body = "SHELL:{}".format(value) if shell and " " in value else value
    return '"$<$<COMPILE_LANGUAGE:{}>:{}>"'.format(language, body)


def _options(target, key, prefix=""):
    values = target.get(key, [])
    return ["{}{}".format(prefix, value) for value in values]


def _source_properties(target):
    declared = target.get("source-include") or {}
    lines = []
    for source, folders in declared.items():
        wanted = folders if isinstance(folders, list) else [folders]
        lines.append('set_source_files_properties({} PROPERTIES INCLUDE_DIRECTORIES "{}")'.format(
            _path(source), ";".join(_path(folder) for folder in wanted)))
    return lines


def _library_block(target, kind, root=None):
    name = target["name"]
    declared_sources = _sources(target, root)
    sources = [_path(source) for source in declared_sources]
    compiled = _languages(declared_sources)
    if kind in ("application", "executable"):
        lines = ["add_executable({}".format(name), "    {})".format("\n    ".join(sources))]
    else:
        lines = ["add_library({} {}".format(name, "STATIC" if kind == "static-library" else "SHARED"),
                 "    {})".format("\n    ".join(sources))]

    properties = ["PREFIX \"\""] if kind == "device-library" else []
    if kind in ("device-library", "executable") and not target.get("install"):
        raise GenerationError("{} declares no install path, and a {} has to say where it belongs on the "
                              "device".format(name, kind))
    if kind == "device-library":
        properties += ["INSTALL_NAME_DIR {}".format(target["install"]), "BUILD_WITH_INSTALL_NAME_DIR ON"]
    if "suffix" in target:
        properties.append("SUFFIX {}".format(_quoted(target["suffix"])))
    if "standard" in target:
        properties += ["CXX_STANDARD {}".format(target["standard"]), "CXX_STANDARD_REQUIRED ON", "CXX_EXTENSIONS OFF"]
    if properties:
        lines.append("set_target_properties({} PROPERTIES {})".format(name, " ".join(properties)))

    for key, command in (("include", "target_include_directories({} PRIVATE"),
                         ("include-system", "target_include_directories({} SYSTEM PRIVATE")):
        folders = _folders(target, key, root)
        if folders:
            lines.append(command.format(name) + "\n    {})".format(
                "\n    ".join(_path(folder) for folder in folders)))
    system_for = _per_language(target, "include-system-for", compiled)
    if system_for:
        lines.append("target_include_directories({} SYSTEM PRIVATE\n    {})".format(name, "\n    ".join(
            _for_language(language, _path(value)) for language, value in system_for)))

    lines += _source_properties(target)

    options = _options(target, "options")
    if options:
        lines.append("target_compile_options({} PRIVATE\n    {})".format(name, "\n    ".join(options)))
    options_for = _per_language(target, "options-for", compiled)
    if options_for:
        lines.append("target_compile_options({} PRIVATE\n    {})".format(name, "\n    ".join(
            _for_language(language, value, shell=True) for language, value in options_for)))
    definitions = _options(target, "definitions")
    if definitions:
        lines.append("target_compile_definitions({} PRIVATE\n    {})".format(name, "\n    ".join(definitions)))
    definitions_for = _per_language(target, "definitions-for", compiled)
    if definitions_for:
        lines.append("target_compile_definitions({} PRIVATE\n    {})".format(name, "\n    ".join(
            _for_language(language, value) for language, value in definitions_for)))
    link_options = _options(target, "link-options")
    if link_options:
        lines.append("target_link_options({} PRIVATE\n    {})".format(name, "\n    ".join(link_options)))

    linked = [_quoted("-framework {}".format(framework)) for framework in target.get("frameworks", [])]
    linked += list(target.get("libraries", []))
    if linked:
        lines.append("target_link_libraries({} PRIVATE\n    {})".format(name, "\n    ".join(linked)))
    return lines


def _install_block(target, kind):
    name = target["name"]
    if kind == "static-library":
        return []
    if kind == "application":
        return (["install(TARGETS {} RUNTIME DESTINATION .)".format(name)] +
                _resource_lines(target, "."))
    install = target["install"].lstrip("/")
    destination = "RUNTIME" if kind == "executable" else "LIBRARY"
    return (["install(TARGETS {} {} DESTINATION {})".format(name, destination, install)] +
            _resource_lines(target, install))


def _resource_lines(target, destination):
    lines = []
    files = [resource for resource in target.get("resources", []) if isinstance(resource, str)]
    if files:
        lines.append("install(FILES {} DESTINATION {})".format(" ".join(_path(file) for file in files), destination))
    for resource in target.get("resources", []):
        if isinstance(resource, str):
            continue
        if not isinstance(resource, dict) or not resource.get("from") or not resource.get("as"):
            raise GenerationError("{} declares the resource {!r}. A resource is a path, or a table with from and "
                                  "as; anything else would be left out of the build without a word".format(
                                      target["name"], resource))
        source, renamed = _path(resource["from"]), resource["as"]
        if resource["from"].endswith("/"):
            lines.append("install(DIRECTORY {} DESTINATION {})".format(
                source, destination if renamed == "." else renamed.lstrip("/")))
        elif renamed.startswith("/"):
            folder, _, file = renamed.rpartition("/")
            lines.append("install(FILES {} DESTINATION {} RENAME {})".format(
                source, folder.lstrip("/") or ".", file))
        else:
            lines.append("install(FILES {} DESTINATION {} RENAME {})".format(source, destination, renamed))
    return lines


def cmake_project(declared, kind, project):
    targets = [target for target in declared.targets(kind) if declared.generates(target)]
    if not targets:
        return None
    used = set()
    for target in targets:
        used.update(_languages(_sources(target, declared.root)))
    languages = [language for language in PROJECT_LANGUAGE_ORDER if language in used]

    lines = [GENERATED,
             "cmake_minimum_required(VERSION {})".format(CMAKE_MINIMUM),
             "project({} {})".format(project, " ".join(languages)),
             "",
             REQUIRES_PORT,
             ""]
    wanted = []
    for target in targets:
        for name in (target.get("cache") or {}):
            if name not in wanted:
                wanted.append(name)
    if wanted:
        lines += ["foreach (variable {})".format(" ".join(wanted)),
                  "    if (NOT ${variable})",
                  '        message(FATAL_ERROR "${variable} is named by the declaration and answered from the '
                  'dependency graph; configure through charon build")',
                  "    endif ()",
                  "endforeach ()",
                  ""]

    packages = []
    for target in targets:
        for package in target.get("packages", []):
            if package not in packages:
                packages.append(package)
    if packages:
        lines += ['if (NOT CHARON_PACKAGES)',
                  '    message(FATAL_ERROR "CHARON_PACKAGES names the file that finds {} under the names the '
                  'dependency graph gives them; configure through charon build")'.format(", ".join(packages)),
                  'endif ()',
                  'include("${CHARON_PACKAGES}")']
    if lines[-1] != "":
        lines.append("")
    for target in targets:
        lines += _library_block(target, kind, declared.root) + [""]
    for target in targets:
        lines += _install_block(target, kind)
    return "\n".join(lines).rstrip("\n") + "\n"


BASE = "charon-base/1.0@charon/stable"
CORE_CLASS = "charon-base.CharonPort"
RECIPE_TEMPLATE = '''{generated}
from conan import ConanFile


class Port(ConanFile):
    name = {name}
    version = {version}
    description = {description}
    package_type = "application"
    generators = "VirtualBuildEnv"
    python_requires = {python_requires}
    python_requires_extend = {extends}
    options = {options}
    default_options = {defaults}

    declaration = {declaration}

    def requirements(self):
        for reference in {requires}:
            self.requires(reference)

    def build_requirements(self):
        for reference in {tools}:
            self.tool_requires(reference)

    def layout(self):
        self.declared_layout()

    def generate(self):
        super().generate()
        self.declared_toolchain()

    def build(self):
        self.declared_build()

    def package(self):
        self.declared_package()
'''


def _option_domains(declared):
    named = {}
    for variant in declared.section("variants").values():
        for entry in variant.get("options", []):
            option, _, value = entry.partition("=")
            named.setdefault(option, set()).add(value)
    domains, defaults = {}, {}
    for option, values in named.items():
        if not values <= {"True", "False"}:
            raise GenerationError("{} is declared with {}, and Charon only derives a domain for True and "
                                 "False; declare it in the recipe instead".format(option, ", ".join(sorted(values))))
        domains[option] = [True, False]
        defaults[option] = False
    return domains, defaults


def _references(section):
    return ["{}/{}".format(name, version) for name, version in section.items()]


def _port_tools(platform, declared_tools):
    named = {reference.split("/")[0]: reference for reference in platform["port-tool-requires"]}
    named.update({name: "{}/{}".format(name, version) for name, version in declared_tools.items()})
    return list(named.values())


def recipe(declared):
    import pprint
    described = declared.section("port")
    for required in ("name", "version"):
        if required not in described:
            raise GenerationError("[port] declares no {}, and a recipe cannot be written without it".format(required))
    domains, defaults = _option_domains(declared)
    platform = declared.platform()
    if platform is None:
        raise GenerationError("{} declares no [platform], and a recipe is written for one".format(
            declared.root / spec.MANIFEST))
    content = dict(declared.content)
    content["platform-facts"] = {key: platform[key] for key in ("name", "os", "arch", "os-version", "distribution",
                                                                "distributed", "build-only", "frameworks")}
    return RECIPE_TEMPLATE.format(
        generated=GENERATED,
        name=repr(described["name"]),
        version=repr(str(described["version"])),
        description=repr(described.get("description", "")),
        python_requires=repr(tuple([str(declared.get("use", "base", BASE))] + platform["python-requires"])),
        extends=repr(tuple([CORE_CLASS] + platform["extends"])),
        options=repr(domains),
        defaults=repr(defaults),
        declaration=pprint.pformat(content, width=110, sort_dicts=False, indent=4),
        requires=repr(platform["requires"] + _references(declared.section("requires"))),
        tools=repr(_port_tools(platform, declared.section("tools"))),
    )


PROJECT_INCLUDE = "project-include.cmake"
CROSS_TOOLCHAIN = "cross-toolchain.cmake"



def cross_toolchain(declared):
    target = declared.section("target")
    platform = declared.platform()
    if platform is None or not platform.get("cross-toolchain"):
        raise GenerationError("{} declares no [platform] with a cross toolchain, and the compiler cannot be "
                              "pointed at a target without one".format(declared.root / spec.MANIFEST))
    defines = target.get("defines", [])
    return platform["cross-toolchain"].read_text().format(
        generated=GENERATED,
        system=target.get("system-name", "Darwin"),
        processor=target.get("system-processor", "${CHARON_ARCHITECTURE}"),
        defines="".join(" {}".format(define) for define in defines),
    )


def project_include(declared):
    packages = declared.get("engine", "config-packages", [])
    if not packages:
        return None
    lines = [GENERATED]
    lines += ["find_package({} REQUIRED CONFIG)".format(name) for name in packages]
    return "\n".join(lines) + "\n"


TIER_RECIPE = '''{generated}
from conan import ConanFile


class TierPackages(ConanFile):
    name = {name}
    version = "1.0"
    settings = "os", "arch", "compiler", "build_type"
    python_requires = {base}

    def requirements(self):
        for reference in {requires}:
            self.requires(reference)

    def generate(self):
        self.python_requires["charon-base"].module.DependencyEnv(self).generate()
'''


def tier_recipe(declared, tier, packages):
    described = declared.section("port")
    if "name" not in described:
        raise GenerationError("[port] declares no name, and a tier's packages cannot be named without it")
    return TIER_RECIPE.format(
        generated=GENERATED,
        name=repr("{}-{}-packages".format(described["name"], tier)),
        base=repr(str(declared.get("use", "base", BASE))),
        requires=repr(_references(packages)),
    )


def written(declared, required=True):
    produced = {}
    applied = project_include(declared)
    if applied is not None:
        produced[PROJECT_INCLUDE] = applied
    if declared.using("toolchain") is None and declared.get("engine", "user-toolchain", None) is None:
        produced[CROSS_TOOLCHAIN] = cross_toolchain(declared)
    for tier, described in declared.tiers().items():
        packages = described.get("packages")
        if packages:
            produced["tests/{}/conanfile.py".format(tier)] = tier_recipe(declared, tier, packages)
    profiles = declared.using("profile")
    if profiles is None:
        produced["profile"] = profile(declared)
    for kind, project in (("static-library", "port-static"), ("device-library", "port-device"),
                          ("executable", "port-executable"), ("application", "port-application")):
        text = cmake_project(declared, kind, project)
        if text is not None:
            produced["{}/CMakeLists.txt".format(kind)] = text
    if required and not produced:
        raise GenerationError("{} declares nothing Charon can generate".format(declared.root / spec.MANIFEST))
    return produced

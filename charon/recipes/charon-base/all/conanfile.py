import hashlib
import os
import re
import sys
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException, ConanInvalidConfiguration
from conan.tools.build import can_run
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout
from conan.tools.env import Environment
from conan.tools.files import copy, mkdir, rmdir

PLACEHOLDER = re.compile(r"\{([a-z][a-z0-9_.-]*(?::[^{}]*)?)\}")


class CharonBaseConan(ConanFile):
    name = "charon-base"
    user = "charon"
    channel = "stable"
    version = "1.0"
    package_type = "python-require"
    description = "What every port Charon builds shares, whatever platform it builds for"
    license = "MIT"


class DependencyEnv:

    filename = "charon-deps.env"

    def __init__(self, conanfile):
        self._conanfile = conanfile

    def generate(self):
        dependencies = self._conanfile.dependencies
        lines = []
        for context, graph in (("HOST", dependencies.host), ("BUILD", dependencies.build)):
            for dependency in graph.values():
                folder = dependency.package_folder
                if folder is None:
                    continue
                if re.search(r"[\s'\"$\\#]", folder):
                    raise ConanException(
                        f"{dependency.ref}: {folder} cannot be written as a shell and make assignment")
                name = re.sub(r"[^A-Z0-9]", "_", dependency.ref.name.upper())
                lines.append(f"CHARON_{context}_{name}={folder}")
        path = os.path.join(self._conanfile.generators_folder, self.filename)
        with open(path, "w") as out:
            out.write("\n".join(sorted(lines)) + "\n")


class CharonPort:
    """Base class for the recipe Charon writes for a port.

    Inherited with python_requires_extend together with the port's platform,
    whose class answers the hooks this one leaves open: what a binary is, how it
    is verified, signed, bundled and packaged.
    """

    settings = "os", "arch", "compiler", "build_type"

    generators = "CMakeDeps", "CMakeToolchain", "VirtualBuildEnv"

    def validate(self):
        facts = self.declared_platform() if getattr(type(self), "declaration", None) else None
        if not facts:
            return
        wanted = {"os": facts["os"], "arch": facts["arch"], "os.version": facts["os-version"]}
        found = {key: str(self.settings.get_safe(key)) for key in wanted}
        if found != wanted:
            raise ConanInvalidConfiguration(
                f"{self.name} was declared for {facts['name']} {facts['arch']} {facts['os-version']}, and this build "
                f"was given {found['os']} {found['arch']} {found['os.version']}; build it through charon build")

    def layout(self):
        self.folders.generators = os.path.join("build", "conan", str(self.settings.arch))

    def declared_platform(self):
        return self.declared.get("platform-facts")

    def generate(self):
        DependencyEnv(self).generate()

    def _components(self, name):
        try:
            return self.dependencies[name].cpp_info.aggregated_components()
        except KeyError:
            available = ", ".join(sorted(dependency.ref.name for dependency in self.dependencies.host.values()))
            raise ConanException(f"{name} is not a dependency of {self.name}; it requires {available}")

    def _static_library(self, name, library):
        info = self._components(name)
        if library not in info.libs:
            raise ConanException(f"{name} does not provide {library}; it provides {', '.join(info.libs)}")
        for folder in info.libdirs:
            path = os.path.join(folder, f"lib{library}.a")
            if os.path.isfile(path):
                return path
        raise ConanException(f"{name} declares {library} but no lib{library}.a is in {', '.join(info.libdirs)}")

    def _build_tool(self, name):
        try:
            return os.path.join(self.dependencies.build[name].package_folder, "bin")
        except KeyError:
            available = ", ".join(sorted(dependency.ref.name for dependency in self.dependencies.build.values()))
            raise ConanException(f"{name} is not a build tool of {self.name}; it has {available}")

    def _resolve(self, name):
        kind, _, rest = name.partition(":")
        parts = [part for part in rest.split(":") if part] if rest else []
        if kind == "pkg" and len(parts) == 1:
            return self.dependencies[parts[0]].package_folder
        if kind == "include" and len(parts) == 1:
            return self._components(parts[0]).includedirs[0]
        if kind == "lib" and len(parts) == 2:
            return self._static_library(parts[0], parts[1])
        if kind == "libdirs" and len(parts) == 1:
            return " ".join(f"-L{folder}" for package in parts[0].split(",")
                            for folder in self._components(package).libdirs)
        if kind == "bin" and len(parts) == 1:
            return self._build_tool(parts[0])
        raise ConanException(f"{{{name}}} is not something this toolchain can resolve; it answers pkg:NAME, "
                             "include:NAME, lib:NAME:LIBRARY, libdirs:NAME[,NAME] and bin:TOOL")

    def resolved(self, text):
        return PLACEHOLDER.sub(lambda match: str(self._resolve(match.group(1))), str(text))

    @property
    def declared(self):
        declaration = getattr(type(self), "declaration", None)
        if not declaration:
            raise ConanException(f"{self.name} carries no declaration; a generated recipe bakes one in")
        return declaration

    @property
    def port_root(self):
        chosen = self.conf.get("user.charon:port", check_type=str)
        if chosen:
            return chosen
        root = getattr(type(self), "port", None)
        if root:
            return root
        folder = getattr(self, "recipe_folder", None)
        if folder and os.path.basename(os.path.normpath(folder)) == "charon":
            candidate = os.path.normpath(os.path.join(folder, os.pardir, os.pardir, os.pardir))
            if os.path.isfile(os.path.join(candidate, "charon.toml")):
                return candidate
        raise ConanException(f"{self.name} cannot tell which port it was written for: it is not in a port's "
                             "build/<variant>/charon folder, and user.charon:port is not set")

    def declared_variant(self):
        building = self.declared.get("for-variant")
        if building:
            return building
        chosen, matched = None, -1
        for name, declared in self.declared.get("variants", {}).items():
            wanted = [entry.split("=", 1) for entry in declared.get("options", [])]
            if all(str(self.options.get_safe(option)) == value for option, value in wanted) and len(wanted) > matched:
                chosen, matched = name, len(wanted)
        if chosen is None:
            raise ConanException(f"{self.name}: no declared variant matches the options this build was given")
        return chosen

    def declared_setting(self, section, key, default=None):
        variant = self.declared.get("variants", {}).get(self.declared_variant(), {})
        if key in variant:
            return variant[key]
        return self.declared.get(section, {}).get(key, default)

    def _target_product(self, name):
        kind, target = self._declared_kind(name)
        produced = target.get("produces")
        if not produced:
            raise ConanException(f"{name} does not say what it produces, so nothing can point at it")
        project = target.get("cmake")
        return os.path.join(self.build_folder, os.path.basename(project) if project else kind, produced)

    @property
    def stage_folder(self):
        return os.path.join(self.build_folder, "stage")

    def _declared_context(self):
        engine = self.declared.get("engine", {})
        tuning = " ".join(self.conf.get("tools.build:cxxflags", default=[], check_type=list))
        context = {
            "tuning": tuning,
            "version": str(self.version),
            "source": self.source_folder,
            "build": self.build_folder,
            "stage": self.stage_folder,
            "port": self.port_root,
            "stubs": os.path.join(self.port_root, engine.get("stubs", "")),
            "prefix-header": self.declared_setting("engine", "prefix-header", ""),
        }
        context.update(self.platform_context())
        flags = self.declared.get("flags", {})
        for name in ("common", "defines", "c", "cxx", "objc", "objcxx"):
            if name in flags:
                context[name] = flags[name]
        return context

    def platform_context(self):
        return {}

    def platform_cache_variables(self):
        return {}

    def platform_toolchain(self, toolchain):
        pass

    def platform_steps(self):
        return {}

    def platform_checks(self):
        return {}

    def platform_stages(self):
        return {}

    def platform_waivable(self):
        return ()

    def platform_pipeline_problems(self, variant, steps, merged):
        return []

    def platform_verify(self, binary, waived, stripped=False):
        pass

    def link_input_findings(self, path, label):
        raise ConanException(f"{self.name} is built for a platform that cannot read what {path} was built for")

    def installed(self, folder):
        pass

    def build_application(self):
        raise ConanException(f"{self.name} is built for a platform that builds no application")

    def platform_package(self):
        raise ConanException(f"{self.name} is built for a platform that writes no installable package")

    def _resolve_declared(self, name, context, seen):
        if name in seen:
            raise ConanException(f"{{{name}}} refers to itself")
        if name in context:
            return self._expand(context[name], context, seen | {name})
        if name == "engine-exports":
            return self._expand(self.declared.get("engine", {}).get("exports", ""), context, seen)
        if name == "exports":
            return self._expand(self.declared_setting("engine", "exports", ""), context, seen)
        kind, _, rest = name.partition(":")
        if kind == "target" and rest:
            return self._target_product(rest)
        return None

    def _expand(self, text, context, seen=frozenset()):
        def replace(match):
            name = match.group(1)
            answered = self._resolve_declared(name, context, seen)
            return str(answered) if answered is not None else str(self._resolve(name))
        return PLACEHOLDER.sub(replace, str(text))

    def declared_flags(self, name):
        flags = self.declared.get("flags", {})
        if name not in flags:
            raise ConanException(f"{self.name} declares no {name} flags")
        return self._expand(flags[name], self._declared_context())

    FLAG_VARIABLES = (("CMAKE_C_FLAGS", "c"), ("CMAKE_CXX_FLAGS", "cxx"), ("CMAKE_OBJC_FLAGS", "objc"),
                      ("CMAKE_OBJCXX_FLAGS", "objcxx"), ("CMAKE_SHARED_LINKER_FLAGS", "shared-link"),
                      ("CMAKE_EXE_LINKER_FLAGS", "exe-link"), ("CMAKE_MODULE_LINKER_FLAGS", "module-link"))

    def declared_flag_variables(self):
        declared = self.declared.get("flags", {})
        maps = " ".join(self.path_maps())
        return {variable: f"{self.declared_flags(name)} {maps}".strip()
                for variable, name in self.FLAG_VARIABLES if name in declared}

    PATH_MAP = "-ffile-prefix-map="

    def path_maps(self):
        maps = {}
        for flag in self.conf.get("tools.build:cflags", default=[], check_type=list):
            if flag.startswith(self.PATH_MAP):
                folder, _, name = flag[len(self.PATH_MAP):].rpartition("=")
                maps[os.path.normpath(folder)] = name
        maps.setdefault(os.path.normpath(self.port_root), "/port")
        return [f"{self.PATH_MAP}{folder}={maps[folder]}" for folder in sorted(maps, key=len, reverse=True)]

    def declared_options(self):
        context = self._declared_context()
        options = dict(self.declared.get("engine", {}).get("options", {}))
        variant = self.declared.get("variants", {}).get(self.declared_variant(), {})
        options.update(variant.get("engine-options", {}) or {})
        return {name: self._expand(value, context) for name, value in options.items()}

    def declared_layout(self):
        self.folders.root = os.path.relpath(self.port_root, self.recipe_folder)
        engine = self.declared.get("engine", {})
        if engine.get("cmake"):
            self.folders.source = engine["cmake"]
        self.folders.build = os.path.join("build", self.declared_variant())
        self.folders.generators = os.path.join(self.folders.build, "conan")

    def cross_toolchain(self):
        user_toolchain = self.declared.get("engine", {}).get("user-toolchain")
        if user_toolchain:
            return os.path.join(self.port_root, user_toolchain)
        cross = os.path.join(self.recipe_folder, "cross-toolchain.cmake")
        if not os.path.isfile(cross):
            raise ConanException(
                f"{self.name} names no user-toolchain of its own and nothing was written to {cross}. "
                "It is what points the compiler at the SDK this port targets; without it cmake falls "
                "back to the newest installed one and compiles against a system years newer")
        return cross

    def toolchain_inputs(self):
        with open(self.cross_toolchain(), "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()
        inputs = dict(self.platform_cache_variables())
        inputs["CHARON_PATH_MAPS"] = " ".join(self.path_maps())
        inputs["CHARON_TOOLCHAIN_DIGEST"] = digest
        return inputs

    def fresh_configure(self, folder):
        cache = os.path.join(folder, "CMakeCache.txt")
        if not os.path.isfile(cache):
            return []
        with open(cache) as handle:
            cached = dict(re.findall(r"^([A-Za-z0-9_]+):[A-Z]+=(.*)$", handle.read(), re.M))
        changed = sorted(name for name, value in self.toolchain_inputs().items() if cached.get(name) != str(value))
        if not changed:
            return []
        self.output.info(f"{folder} was configured with another {', '.join(changed)}, and CMake keeps the flags "
                         "it first derived from them; configuring it fresh")
        return ["--fresh"]

    def declared_toolchain(self):
        engine = self.declared.get("engine", {})
        self.conf.define("tools.cmake.cmaketoolchain:user_toolchain", [self.cross_toolchain()])
        toolchain = CMakeToolchain(self)
        self.platform_toolchain(toolchain)
        variables = toolchain.cache_variables
        variables.update(self.declared_options())
        variables.update(self.toolchain_inputs())
        variables.update({
            "CMAKE_BUILD_TYPE": "Release",
            "PYTHON_EXECUTABLE": sys.executable,
        })
        variables.update(self.declared_flag_variables())
        include = engine.get("project-include")
        if include:
            applied = os.path.join(self.port_root, include)
        elif engine.get("config-packages"):
            applied = os.path.join(self.recipe_folder, "project-include.cmake")
            if not os.path.isfile(applied):
                raise ConanException(
                    f"{self.name} declares config-packages and nothing was written to {applied}; the "
                    "declaration is what generates it, so generating has to happen before building")
        else:
            applied = None
        if applied:
            name = engine.get("project-name")
            if not name:
                raise ConanException(
                    f"{self.name} says which packages the engine must find by config, or names a "
                    "project-include of its own, but no project-name. CMake applies the file as "
                    "CMAKE_PROJECT_<the name the engine gives project()>_INCLUDE, and the folder the sources "
                    "sit in is not that name; guessing it means the file is silently never included")
            variables[f"CMAKE_PROJECT_{name}_INCLUDE"] = applied
        toolchain.generate()

        deps = CMakeDeps(self)
        wanted = self.configured_packages(self.dependencies.host, self.declared_find_packages())
        for dependency in self.dependencies.host.values():
            if dependency.ref.name not in wanted:
                deps.set_property(dependency.ref.name, "cmake_find_mode", "none")
        deps.generate()
        self._write_found_packages()

        environment = Environment()
        environment.define("CCACHE_BASEDIR", self.port_root)
        environment.vars(self, scope="build").save_script("ccache_basedir")

    FOUND_PACKAGES = "charon-packages.cmake"

    @staticmethod
    def configured_packages(host, found):
        configured = set(found)
        for dependency in host.values():
            if dependency.ref.name in found:
                configured.update(required.ref.name for required in dependency.dependencies.host.values())
        return configured

    def declared_target_packages(self):
        wanted = []
        for kind in ("static-library", "device-library", "executable", "application"):
            declared = self.declared.get(kind) or []
            for target in [declared] if isinstance(declared, dict) else declared:
                wanted += [package for package in target.get("packages", []) if package not in wanted]
        return wanted

    def _write_found_packages(self):
        host = {dependency.ref.name: dependency for dependency in self.dependencies.host.values()}
        lines = []
        for package in self.declared_target_packages():
            if package not in host:
                raise ConanException(f"a target of {self.name} finds {package}, which it does not require; "
                                     f"it requires {', '.join(sorted(host)) or 'nothing'}")
            found = host[package].cpp_info.get_property("cmake_file_name") or package
            lines.append(f"find_package({found} REQUIRED CONFIG)")
        for name, dependency in sorted(host.items()):
            lines += self._objective_c_options(name, dependency.cpp_info)
        with open(os.path.join(self.generators_folder, self.FOUND_PACKAGES), "w") as handle:
            handle.write("\n".join(lines) + "\n")

    @staticmethod
    def _objective_c_options(name, info):
        owners = [(info.get_property("cmake_target_name") or f"{name}::{name}", info)]
        owners += [(component.get_property("cmake_target_name") or f"{name}::{component_name}", component)
                   for component_name, component in sorted(info.components.items()) if component_name]
        lines = []
        for target, owner in owners:
            options = [f'"$<$<COMPILE_LANGUAGE:OBJC>:{flag}>"' for flag in owner.cflags or []]
            options += [f'"$<$<COMPILE_LANGUAGE:OBJCXX>:{flag}>"' for flag in owner.cxxflags or []]
            if options:
                lines += [f"if (TARGET {target})",
                          f"    set_property(TARGET {target} APPEND PROPERTY INTERFACE_COMPILE_OPTIONS",
                          "        " + "\n        ".join(options) + ")",
                          "endif ()"]
        return lines

    def _refuse_graph_by_hand(self):
        host = [dependency for dependency in self.dependencies.host.values() if dependency.package_folder]
        provided = {library: dependency.ref.name for dependency in host
                    for library in dependency.cpp_info.aggregated_components().libs}
        folders = {os.path.normpath(dependency.package_folder): dependency.ref.name for dependency in host}
        context = self._declared_context()
        for kind in ("static-library", "device-library", "executable", "application"):
            declared = self.declared.get(kind) or []
            for target in [declared] if isinstance(declared, dict) else declared:
                for library in target.get("libraries", []):
                    if library in provided:
                        raise ConanException(
                            f"{target.get('name')} links {library} by name, which {provided[library]} provides; "
                            f"name {provided[library]} under packages and link its imported target, so the "
                            "archive is an input the build can see and the checks can read")
                for option in target.get("link-options", []):
                    expanded = self._expand(option, context)
                    if expanded.startswith("-L"):
                        folder = os.path.normpath(expanded[2:])
                        owner = next((name for root, name in folders.items()
                                      if folder == root or folder.startswith(root + os.sep)), None)
                        if owner:
                            raise ConanException(
                                f"{target.get('name')} searches {owner}'s package folder with {option}; name "
                                f"{owner} under packages and link its imported target instead")

    def declared_steps(self):
        chosen = self.conf.get("user.charon:steps", default=None, check_type=list)
        return list(chosen) if chosen else self.declared_pipeline()

    BUILT = "charon-built"

    def declared_build(self):
        self._refuse_graph_by_hand()
        whole = self.conf.get("user.charon:steps", default=None, check_type=list) is None
        finished = os.path.join(self.build_folder, self.BUILT)
        if whole and os.path.exists(finished):
            os.remove(finished)
        for step in self.declared_steps():
            action, _, argument = step.partition(":")
            self.output.title(step)
            self._run_step(action, argument)
        altered = self.altered_packages()
        if altered:
            raise ConanException(f"{self.name} wrote into packages it only reads, so the next build of anything "
                                 f"that uses them gets what this build left there: {'; '.join(altered)}")
        if whole:
            with open(finished, "w") as handle:
                handle.write(" ".join(self.declared_steps()) + "\n")

    MANIFEST = "conanmanifest.txt"
    UNRECORDED = {"conanmanifest.txt", "conan_package.tgz", "conan_export.tgz", "conan_sources.tgz"}

    def altered_packages(self):
        found = []
        for dependency in list(self.dependencies.host.values()) + list(self.dependencies.build.values()):
            folder = dependency.package_folder
            manifest = os.path.join(folder, self.MANIFEST) if folder else None
            if not manifest or not os.path.isfile(manifest):
                continue
            with open(manifest) as handle:
                recorded = dict(line.rsplit(": ", 1) for line in handle.read().splitlines()[1:] if ": " in line)
            present = {}
            for base, _, names in os.walk(folder):
                for name in names:
                    path = os.path.join(base, name)
                    relative = os.path.relpath(path, folder).replace(os.sep, "/")
                    if relative not in self.UNRECORDED:
                        present[relative] = path
            changed = sorted(name for name in set(recorded) | set(present)
                             if name not in present or name not in recorded
                             or self._package_digest(present[name]) != recorded[name])
            if changed:
                shown = ", ".join(changed[:5]) + (f" and {len(changed) - 5} more" if len(changed) > 5 else "")
                found.append(f"{dependency.ref} ({shown})")
        return found

    @staticmethod
    def _package_digest(path):
        if os.path.islink(path):
            return hashlib.md5(os.readlink(path).encode()).hexdigest()
        digest = hashlib.md5()
        with open(path, "rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def declared_pipeline(self):
        variant = self.declared_variant()
        steps = self.declared.get("pipeline", {}).get(variant)
        if not steps:
            raise ConanException(f"{self.name} declares no pipeline for the {variant} variant, so building it "
                                 "would do nothing and report success")
        merged = {name for declared in self.declared.get("variants", {}).values()
                  for name in (declared.get("merge") or [])}
        problems = self.platform_pipeline_problems(variant, steps, merged)
        if problems:
            raise ConanException("; ".join(problems))
        return steps

    def _run_step(self, action, argument):
        steps = {
            "task": self._run_task,
            "build": self._build_target,
            "check": self._run_check,
            "stage": self._run_stage,
        }
        steps.update(self.platform_steps())
        if action not in steps:
            raise ConanException(f"{action} is not a step this toolchain knows; it runs "
                                 f"{', '.join(sorted(steps))}")
        steps[action](argument)

    def _run_task(self, name):
        declared = self.declared.get("tasks", {})
        if name not in declared:
            known = ", ".join(sorted(declared)) or "none declared"
            raise ConanException(f"{self.name} declares no task {name} ({known})")
        body = declared[name]
        if not isinstance(body, dict):
            raise ConanException(
                f"task {name} is declared as {body!r}. A task is a table - [tasks.{name}] with script, shell or "
                "python - so that every task in a declaration reads the same way")
        kinds = [kind for kind in ("script", "shell", "python") if kind in body]
        if len(kinds) != 1:
            raise ConanException(f"task {name} declares {', '.join(kinds) or 'none'} of script, shell and python, "
                                 "and a task has to say exactly one thing to run")
        context = self._declared_context()
        arguments = self._expand(body.get("args", ""), context)
        if kinds[0] == "script":
            return self._run_script(name, "{} {}".format(self._expand(body["script"], context), arguments))
        if kinds[0] == "shell":
            return self.run(" ".join(part for part in (self._expand(body["shell"], context), arguments) if part),
                            cwd=self.port_root)
        return self._run_written(name, body["python"], arguments)

    def _run_script(self, name, commandline):
        words = commandline.split()
        script = os.path.join(self.port_root, words[0])
        if not os.path.isfile(script):
            raise ConanException(f"{script} does not exist, and the task {name} names it")
        arguments = " ".join(f'"{word}"' for word in words[1:])
        self.run(f'"{sys.executable}" "{script}" {arguments}', cwd=self.port_root)

    def _run_written(self, name, body, arguments):
        folder = os.path.join(self.build_folder, "charon-tasks")
        mkdir(self, folder)
        written = os.path.join(folder, f"{name}.py")
        with open(written, "w") as handle:
            handle.write(body)
        self.run(f'"{sys.executable}" "{written}" {arguments}', cwd=self.port_root)

    def _declared_kind(self, name):
        for kind in ("static-library", "device-library", "executable"):
            for target in self.declared.get(kind, []):
                if target.get("name") == name:
                    return kind, target
        application = self.declared.get("application") or {}
        if application.get("name") == name:
            return "application", application
        raise ConanException(f"{self.name} declares no target called {name}")

    def _project_source(self, kind, target):
        project = target.get("cmake")
        if project:
            return os.path.join(self.port_root, project)
        written = os.path.join(self.recipe_folder, kind, "CMakeLists.txt")
        if not os.path.isfile(written):
            raise ConanException(
                f"{target.get('name')} names no cmake project of its own and none was written to {written}; "
                "the declaration is what generates it, so generating has to happen before building")
        return os.path.dirname(written)

    def _cmake_project(self, source, folder, definitions):
        toolchain = os.path.join(self.generators_folder, "conan_toolchain.cmake")
        values = " ".join(f'-D{name}="{value}"' for name, value in definitions.items())
        inputs = " ".join(f'-D{name}="{value}"' for name, value in self.toolchain_inputs().items())
        fresh = " ".join(self.fresh_configure(folder))
        self.run(f'cmake {fresh} --no-warn-unused-cli -S "{source}" -B "{folder}" -G Ninja -DCMAKE_BUILD_TYPE=Release '
                 f'-DCMAKE_TOOLCHAIN_FILE="{toolchain}" {inputs} -DCHARON_PORT="{self.port_root}" '
                 f'-DCHARON_PACKAGES="{os.path.join(self.generators_folder, self.FOUND_PACKAGES)}" {values}')
        self.run(f'cmake --build "{folder}"')
        self._verify_inputs(folder)

    def _build_target(self, name):
        if name == "engine":
            cmake = CMake(self)
            cmake.configure(cli_args=self.fresh_configure(self.build_folder))
            cmake.build()
            self._verify_inputs(self.build_folder)
            return
        if name == "application":
            self.build_application()
            return
        if name in ("static-library", "device-library", "executable"):
            self._build_kind(name)
            return
        kind, target = self._declared_kind(name)
        folder = os.path.join(self.build_folder, os.path.basename(target.get("cmake") or name))
        self._cmake_project(self._project_source(kind, target), folder, self._declared_cache(target))
        if target.get("installs-into") == "stage":
            self._install_into_stage(folder)
            self.installed(folder)

    def _declared_cache(self, *targets):
        context = self._declared_context()
        values = {}
        for target in targets:
            values.update({key: self._expand(value, context)
                           for key, value in (target.get("cache") or {}).items()})
        return values

    def _build_kind(self, kind):
        targets = [target for target in self.declared.get(kind, []) if not target.get("cmake")]
        if not targets:
            raise ConanException(f"{self.name} declares no {kind} for Charon to generate; a target that names a "
                                 "cmake project of its own is built by its own name")
        folder = os.path.join(self.build_folder, kind)
        self._cmake_project(self._project_source(kind, targets[0]), folder, self._declared_cache(*targets))
        if any(target.get("installs-into") == "stage" for target in targets):
            self._install_into_stage(folder)
            self.installed(folder)

    def _install_into_stage(self, folder):
        manifest = os.path.join(folder, "install_manifest.txt")
        stage = os.path.realpath(self.stage_folder)
        if os.path.isfile(manifest):
            with open(manifest) as installed:
                for line in installed:
                    path = os.path.realpath(line.strip())
                    if line.strip() and path.startswith(stage + os.sep) and os.path.lexists(path):
                        os.remove(path)
        self.run(f'cmake --install "{folder}" --prefix "{self.stage_folder}"')

    def declared_find_packages(self):
        wanted = list((self.declared.get("engine") or {}).get("find-packages", []))
        return wanted + [package for package in self.declared_target_packages() if package not in wanted]

    def declared_waivers(self):
        waived = self.declared.get("waive") or {}
        waivable = ("input-minimum",) + tuple(self.platform_waivable())
        for name, why in waived.items():
            if name not in waivable:
                raise ConanException(f"[waive] names {name}, which is not something this toolchain verifies; it "
                                     f"verifies {', '.join(waivable)}")
            reasons = why.values() if name == "input-minimum" and isinstance(why, dict) else [why]
            if not reasons or any(not isinstance(reason, str) or not reason.strip() for reason in reasons):
                raise ConanException(f"[waive] {name} gives no reason, and a check is only left out for one")
        return waived

    def _link_inputs(self, folder):
        if not os.path.isfile(os.path.join(folder, "build.ninja")):
            raise ConanException(f"{folder} has no build.ninja, so there is nothing to ask which objects and archives "
                                 "its links read; the projects Charon configures are generated for Ninja")
        captured = StringIO()
        self.run(f'ninja -C "{folder}" -t inputs', stdout=captured)
        found = set()
        for line in captured.getvalue().splitlines():
            line = line.strip()
            if line.endswith((".o", ".a")):
                path = os.path.normpath(line if os.path.isabs(line) else os.path.join(folder, line))
                if os.path.isfile(path):
                    found.add(path)
        return sorted(found)

    def _verify_inputs(self, folder):
        waived = self.declared_waivers().get("input-minimum")
        if isinstance(waived, str):
            self.output.warning(f"input-minimum not checked: {waived}")
            return
        waived = waived or {}
        packages = {dependency.ref.name: os.path.normpath(dependency.package_folder)
                    for dependency in self.dependencies.host.values() if dependency.package_folder}
        unknown = sorted(set(waived) - set(packages))
        if unknown:
            raise ConanException(f"[waive] input-minimum names {', '.join(unknown)}, which this build does not "
                                 "depend on")
        built_here = os.path.normpath(self.build_folder)
        problems, reported, objects, members = [], [], 0, 0
        for path in self._link_inputs(folder):
            owner = next((name for name, root in packages.items() if path.startswith(root + os.sep)), None)
            if owner in waived:
                continue
            if owner:
                label = f"{owner}/{os.path.relpath(path, packages[owner])}"
            elif path.startswith(built_here + os.sep):
                label = os.path.relpath(path, built_here)
            else:
                label = path
            recorded, findings = self.link_input_findings(path, label)
            if path.endswith(".a"):
                members += recorded
            else:
                objects += 1
            for newer, problem in findings:
                if owner or path.startswith(built_here + os.sep) or newer:
                    problems.append(problem)
                else:
                    reported.append(problem)
        for name in sorted(set(waived)):
            self.output.warning(f"input-minimum not checked for {name}: {waived[name]}")
        for line in reported:
            self.output.warning(f"{line}; it comes from outside the dependency graph, so it is reported, not refused")
        if problems:
            shown = "; ".join(problems[:5]) + (f"; and {len(problems) - 5} more" if len(problems) > 5 else "")
            raise ConanException(f"a link input was not built for this target: {shown}")
        self.output.info(f"{objects} objects and {members} archive members {os.path.basename(folder)} links record "
                         f"{self.settings.os} {self.settings.os.version}")

    def _verify(self, binary, stripped=False):
        self.platform_verify(binary, self.declared_waivers(), stripped)

    def _run_check(self, name):
        checks = self.platform_checks()
        if name not in checks:
            raise ConanException(f"{name} is not a check this toolchain knows; it runs "
                                 f"{', '.join(sorted(checks)) or 'none for this platform'}")
        checks[name]()

    def _clear_stage(self):
        rmdir(self, self.stage_folder)
        mkdir(self, self.stage_folder)

    def _run_stage(self, name):
        stages = {"clear": self._clear_stage}
        stages.update(self.platform_stages())
        if name not in stages:
            raise ConanException(f"{name} is not a staging step this toolchain knows; it runs "
                                 f"{', '.join(sorted(stages))}")
        stages[name]()

    def declared_package(self):
        for name in self.declared.get("port", {}).get("licenses", []):
            copy(self, name, self.port_root, os.path.join(self.package_folder, "licenses"))
        self.platform_package()


class CharonTestPackage:
    """Base class for a recipe's test_package.

    Builds test_package.c or test_package.cpp against the package under test and
    links it for the target, so a package that compiles but cannot be linked
    against fails at conan create rather than inside the port. The program runs
    only where the target can run.
    """

    settings = "os", "arch", "compiler", "build_type"
    generators = "CMakeDeps", "CMakeToolchain", "VirtualRunEnv"
    test_type = "explicit"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def test(self):
        if can_run(self):
            self.run(os.path.join(self.cpp.build.bindir, "test_package"), env="conanrun")

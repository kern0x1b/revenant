import os
import plistlib
import re
import shutil
import struct
import tempfile
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import XCRun, to_apple_arch
from conan.tools.files import copy, mkdir, rmdir
from conan.tools.scm import Version


class CharonAppleConan(ConanFile):
    name = "charon-apple"
    user = "charon"
    channel = "stable"
    version = "1.0"
    package_type = "python-require"
    description = "How Charon builds for Apple platforms: Mach-O, bundles, signing and packages"
    license = "MIT"


class ApplePort:
    """The Apple half of a port's recipe, inherited beside charon-base's CharonPort.

    It answers CharonPort's hooks for Apple platforms: the SDK and target the
    compiler is pointed at, the Mach-O invariants every produced binary is held
    to, bundles, signing, merging slices and the .deb a jailbroken device
    installs.
    """

    def platform_context(self):
        context = {"sdk": self.sdk_path, "triple": self.triple}
        application = self.declared.get("application") or {}
        if application.get("name"):
            bundle = os.path.join(self.build_folder, f"{application['name']}.app")
            context["application"] = bundle
            context["executable"] = os.path.join(bundle, application["name"])
        return context

    def platform_cache_variables(self):
        return {
            "CHARON_FRAMEWORK_ROOT": self.framework_root(),
            "CHARON_SDK": self.sdk_path,
            "CHARON_DEPLOYMENT_TARGET": str(self.settings.os.version),
            "CHARON_ARCHITECTURE": self.apple_architecture,
            "CHARON_TRIPLE": self.triple,
            "CMAKE_OSX_SYSROOT": self.sdk_path,
            "CMAKE_OSX_DEPLOYMENT_TARGET": str(self.settings.os.version),
        }

    def platform_toolchain(self, toolchain):
        toolchain.blocks.remove("apple_system")
        self._lay_out_moved_frameworks()

    def moved_frameworks(self):
        target = Version(str(self.settings.os.version))
        declared = (self.declared_platform() or {}).get("frameworks") or {}
        return sorted(name for name, facts in declared.items()
                      if facts.get("public-since") and target < Version(facts["public-since"]))

    def framework_root(self):
        return os.path.join(self.generators_folder, "frameworks") if self.moved_frameworks() else ""

    def _lay_out_moved_frameworks(self):
        root = self.framework_root()
        if not root:
            return
        rmdir(self, root)
        for name in self.moved_frameworks():
            public = os.path.join(self.sdk_path, "System", "Library", "Frameworks", f"{name}.framework")
            stub = os.path.join(public, f"{name}.tbd")
            if not os.path.isfile(stub):
                raise ConanException(f"{name} was private before {self.settings.os} "
                                     f"{self.declared_platform()['frameworks'][name]['public-since']}, and {stub} is "
                                     "not in the SDK to link it at the private location from")
            with open(stub) as handle:
                text = handle.read()
            public_name = f"/System/Library/Frameworks/{name}.framework/{name}"
            if public_name not in text:
                raise ConanException(f"{stub} does not install at {public_name}, so there is no public location "
                                     "to move it from")
            framework = os.path.join(root, "System", "Library", "Frameworks", f"{name}.framework")
            mkdir(self, framework)
            with open(os.path.join(framework, f"{name}.tbd"), "w") as handle:
                handle.write(text.replace(public_name, f"/System/Library/PrivateFrameworks/{name}.framework/{name}"))
            for entry in sorted(os.listdir(public)):
                if entry != f"{name}.tbd":
                    os.symlink(os.path.join(public, entry), os.path.join(framework, entry))

    def platform_steps(self):
        return {"sign": self._sign_target, "merge": self._merge_target}

    def platform_checks(self):
        return {
            "exports": self._check_exports,
            "no-encryption-info": lambda: MachO(self).refuse_encryption_info(self.stage_folder),
            "imports": self._check_imports,
        }

    def platform_stages(self):
        return {"frameworks": self._stage_frameworks, "plists-to-binary": self._stage_binary_plists}

    def platform_waivable(self):
        return MachO.WAIVABLE

    def platform_pipeline_problems(self, variant, steps, merged):
        if variant in merged and "sign:application" in steps:
            return [f"the {variant} pipeline signs an application that another variant merges; the merged "
                    "executable is signed after the merge, and a signature on one slice is lost in it"]
        if "sign:application" in steps:
            signed = steps.index("sign:application")
            after = [step for step in steps[signed + 1:] if step in ("build:application", "merge:application")]
            if after:
                return [f"the {variant} pipeline runs {', '.join(after)} after sign:application; anything that "
                        "changes the bundle has to come before it is signed"]
        if "build:application" in steps and variant not in merged:
            built = steps.index("build:application")
            if "sign:application" not in steps[built + 1:]:
                return [f"the {variant} pipeline builds the application and never signs it, and an unsigned "
                        "application does not start on the device; add sign:application after build:application "
                        "and after any task that changes the executable, or name {variant} in the merge of the "
                        "variant that signs it"]
        return []

    def platform_verify(self, binary, waived, stripped=False):
        MachO(self).verify(binary, waived, stripped)
        strong, weak = self._late_imports(binary)
        if strong:
            raise ConanException(f"{binary} imports what its minimum release does not have, so dyld refuses to load "
                                 f"it there: {'; '.join(strong)}")
        if "weak-imports" in waived:
            self.output.warning(f"{binary}: weak-imports not checked: {waived['weak-imports']}")
            return
        if weak:
            raise ConanException(f"{binary} weakly imports what its minimum release does not have, so a call jumps "
                                 f"to NULL there: {'; '.join(weak)}")

    MINIMUM = re.compile(r"cmd LC_VERSION_MIN_\w+\s+cmdsize \d+\s+version (\S+)|minos (\S+)")
    IMPORT = re.compile(r"\(undefined\) (weak )?external _(\w+) \(from libSystem\)")

    def _late_imports(self, binary):
        try:
            compat = self.dependencies["apple-compat"]
        except KeyError:
            raise ConanException(f"{self.name} builds for an Apple platform without apple-compat in its graph, and "
                                 "it is what says which system calls arrived when")
        arrived = compat.cpp_info.get_property("charon_arrived") or {}
        macho = MachO(self)
        strong, weak = [], []
        for architecture in macho.output(f'"{macho.tool("lipo")}" -archs "{binary}"').split():
            recorded = self.MINIMUM.search(macho.output(f'"{macho.tool("otool")}" -arch {architecture} -l "{binary}"'))
            if not recorded:
                raise ConanException(f"the {architecture} slice of {binary} records no minimum release, so nothing "
                                     "says which system calls it may import")
            minimum = recorded.group(1) or recorded.group(2)
            listing = macho.output(f'"{macho.tool("nm")}" -m -arch {architecture} "{binary}"')
            for late_weak, symbol in sorted(set(self.IMPORT.findall(listing)), key=lambda found: found[1]):
                if symbol in arrived and Version(minimum) < Version(arrived[symbol]):
                    described = (f"{architecture}: {symbol} arrived in {arrived[symbol]}, after {minimum}; "
                                 f"link apple-compat::{symbol}")
                    (weak if late_weak else strong).append(described)
        return strong, weak

    def link_input_findings(self, path, label):
        arch, target = str(self.settings.arch), str(self.settings.os.version)
        cputype = MachO.CPU_TYPES.get(arch)
        if cputype is None:
            raise ConanException(f"{arch} is not an architecture this toolchain reads link inputs for")
        wanted = MachO.encoded_version(target)
        findings = [(minimum is not None and minimum > wanted, problem)
                    for minimum, problem in MachO.minimum_findings(path, cputype, target, label)]
        return len(MachO.recorded_minimums(path, cputype)), findings

    def installed(self, folder):
        self._sign_installed(folder)

    def build_application(self):
        self._build_application()

    def platform_package(self):
        application = self.declared.get("application", {})
        variant = self.declared_variant()
        builds_application = bool(application) and any(step.partition(":")[2] == "application"
                                                        for step in self.declared_pipeline())
        if builds_application:
            bundle = f"{application['name']}.app"
            shutil.copytree(os.path.join(self.build_folder, bundle),
                            os.path.join(self.package_folder, bundle), symlinks=True, dirs_exist_ok=True)
        else:
            shutil.copytree(self.stage_folder, os.path.join(self.package_folder, "root"),
                            symlinks=True, dirs_exist_ok=True)
        described = self.declared.get("package", {})
        packaged = described.get("variant", variant)
        if packaged != variant:
            if builds_application:
                return
            raise ConanException(f"{self.name} packages the {packaged} variant, and {variant} is not it")
        control = described.get("control")
        if not control:
            raise ConanException(f"{self.name} declares no package control file, so no .deb can be written")
        root = self._distributed_tree(application) if builds_application else self.stage_folder
        scripts = described.get("maintainer-scripts")
        DebianPackage(self, os.path.join(self.port_root, control), root,
                      os.path.join(self.port_root, scripts) if scripts else None
                      ).write(os.path.join(self.package_folder, "deb"))

    def _distributed_tree(self, application):
        platform = self.declared_platform() or {}
        distribution = platform.get("distribution")
        applications = (platform.get("distributed") or {}).get("applications")
        if not applications:
            raise ConanException(f"{self.name} distributes as {distribution or 'nothing named'}, which says nowhere "
                                 "for an application to install, so no package can carry one")
        tree = os.path.join(self.build_folder, "distributed")
        rmdir(self, tree)
        if os.path.isdir(self.stage_folder):
            shutil.copytree(self.stage_folder, tree, symlinks=True)
        bundle = f"{application['name']}.app"
        shutil.copytree(os.path.join(self.build_folder, bundle),
                        os.path.join(tree, applications.lstrip("/"), bundle), symlinks=True)
        return tree

    @property
    def sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path", check_type=str)
        if not sdk:
            raise ConanException("tools.apple:sdk_path is not set; build with the port's profile")
        return sdk

    @property
    def apple_architecture(self):
        architecture = to_apple_arch(self)
        if not architecture:
            raise ConanException(f"{self.settings.arch} is not an architecture the Apple tools have a name for")
        return architecture

    @property
    def triple(self):
        return f"{self.apple_architecture}-apple-{str(self.settings.os).lower()}{self.settings.os.version}"

    def _sign_installed(self, folder):
        macho = MachO(self)
        manifest = os.path.join(folder, "install_manifest.txt")
        with open(manifest) as installed:
            paths = [line.strip() for line in installed if line.strip()]
        entitled = {}
        for kind in ("device-library", "executable"):
            for target in self.declared.get(kind, []):
                if target.get("entitlements"):
                    names = {target["name"], f"{target['name']}{target.get('suffix', '.dylib')}"}
                    entitled.update({name: target["entitlements"] for name in names})
        for path in paths:
            if macho.is_macho(path):
                self._verify(path)
                macho.strip(path)
                self._sign_with(path, entitled.get(os.path.basename(path)))

    def _check_exports(self):
        macho = MachO(self)
        listed_at = self._expand(self.declared_setting("engine", "exports", ""), self._declared_context())
        named = self.declared_setting("engine", "exports-binary", "")
        if not named:
            raise ConanException(f"{self.name} runs check:exports and declares no exports-binary under [engine]; "
                                 "nothing says which binary the export list describes")
        binary = self._expand(named, self._declared_context())
        with open(listed_at) as listing:
            listed = {line.strip() for line in listing if line.strip() and not line.lstrip().startswith("#")}
        exported = set(macho.output(f'"{macho.tool("nm")}" -gUj "{binary}"').split())
        missing, unlisted = sorted(listed - exported), sorted(exported - listed)
        if missing or unlisted:
            raise ConanException(f"{binary} was not linked with {listed_at}: {len(missing)} listed symbols not "
                                 f"exported (first: {missing[:3]}), {len(unlisted)} exported symbols not listed "
                                 f"(first: {unlisted[:3]})")

    def _check_imports(self):
        cache = self.conf.get("user.apple-ios:dyld_shared_cache", check_type=str) or self._held_cache()
        if not os.path.isfile(cache):
            raise ConanException(
                f"check:imports is a step this pipeline declares, and there is no shared cache at {cache} to check "
                "against. Fetch the device's dyld_shared_cache there once, or name another with "
                "user.apple-ios:dyld_shared_cache; a step that reports success having looked at nothing is worse "
                "than no step at all")
        checker = os.path.join(self._build_tool("dyld-imports-check"), "dyld-imports-check")
        application = self.declared.get("application") or {}
        bundle = os.path.join(self.build_folder, f"{application.get('name')}.app") if application else None
        folders = [folder for folder in (self.stage_folder, bundle) if folder and os.path.isdir(folder)]
        if not folders:
            raise ConanException(f"check:imports found neither {self.stage_folder} nor an application bundle, so "
                                 "there is nothing built to check yet; run it after the steps that produce them")
        for folder in folders:
            self.run(f'"{checker}" --cache "{cache}" --dist "{folder}"')

    def _held_cache(self):
        home = self.conf.get("user.charon:home", check_type=str) or os.path.join(os.path.expanduser("~"), ".charon")
        return os.path.join(home, "dyld", f"dyld_shared_cache_{self.apple_architecture}")

    def _stage_binary_plists(self):
        for folder, _, names in os.walk(self.stage_folder):
            for name in names:
                if not name.endswith(".plist"):
                    continue
                path = os.path.join(folder, name)
                with open(path, "rb") as source:
                    content = plistlib.load(source)
                with open(path, "wb") as target:
                    plistlib.dump(content, target, fmt=plistlib.FMT_BINARY)

    def _stage_frameworks(self):
        stage = self.declared.get("stage", {})
        engine = os.path.join(self.stage_folder, stage.get("engine-location", ""))
        macho, installed = MachO(self), {}
        for built, described in stage.get("frameworks", {}).items():
            name = described["as"]
            destination = os.path.join(engine, f"{name}.framework", name)
            mkdir(self, os.path.dirname(destination))
            shutil.copy2(os.path.join(self.build_folder, f"{built}.framework", built), destination)
            installed[destination] = described["replaces"]

        for built, described in stage.get("frameworks", {}).items():
            if not described.get("resources"):
                continue
            source = os.path.join(self.build_folder, f"{built}.framework")
            if not os.path.isdir(source):
                raise ConanException(f"{source} does not exist, and it is where {built} resources come from")
            target = os.path.join(engine, f"{described['as']}.framework")
            omit = set(described.get("omit", []))
            for entry in sorted(os.listdir(source)):
                if entry == built or entry in omit:
                    continue
                path = os.path.join(source, entry)
                if entry.endswith(".lproj"):
                    copy(self, "*.js", path, os.path.join(target, entry))
                elif os.path.isdir(path):
                    shutil.copytree(path, os.path.join(target, entry), symlinks=True, dirs_exist_ok=True)
                else:
                    shutil.copy2(path, target)
            for flatten in described.get("flatten", []):
                origin = os.path.join(target, flatten["from"])
                if not os.path.isdir(origin):
                    continue
                for pattern in flatten.get("patterns", []):
                    copy(self, pattern, origin, os.path.join(target, flatten["into"]))

        runtime, runtime_files = self.declared_runtime()
        for built, renamed in runtime_files.items():
            destination = os.path.join(self.stage_folder, "usr", "lib", renamed)
            mkdir(self, os.path.dirname(destination))
            shutil.copy2(os.path.join(runtime, built), destination)
            installed[destination] = f"/usr/lib/{renamed}"

        macho.retarget(installed)
        compatibility = {os.path.join(engine, f"{described['as']}.framework", described["as"]):
                         described.get("compatibility-version")
                         for described in stage.get("frameworks", {}).values()}
        for binary in installed:
            self._verify(binary)
            if not binary.endswith(".dylib"):
                if compatibility.get(binary):
                    macho.require_compatibility_version(binary, compatibility[binary])
                macho.strip(binary, "-S -x")
            macho.sign(binary)

    def _build_application(self):
        declared = self.declared.get("application", {})
        name = declared.get("name")
        if not name:
            raise ConanException(f"{self.name} declares no application to build")
        bundle = os.path.join(self.build_folder, f"{name}.app")
        frameworks = os.path.join(bundle, "Frameworks")
        rmdir(self, bundle)
        mkdir(self, frameworks)

        folder = os.path.join(self.build_folder, os.path.basename(declared.get("cmake") or "application"))
        self._cmake_project(self._project_source("application", declared), folder, self._declared_cache(declared))
        self.run(f'cmake --install "{folder}" --prefix "{bundle}"')

        macho, bundled = MachO(self), {}
        stage = self.declared.get("stage", {})
        compatibility = {}
        build_only = set((self.declared_platform() or {}).get("build-only") or [])
        for built, described in stage.get("frameworks", {}).items():
            destination = os.path.join(frameworks, f"{built}.framework", built)
            shutil.copytree(os.path.join(self.build_folder, f"{built}.framework"),
                            os.path.dirname(destination), symlinks=True, dirs_exist_ok=True,
                            ignore=lambda folder, names, top=os.path.join(self.build_folder, f"{built}.framework"):
                            [name for name in names if folder == top and name in build_only])
            bundled[destination] = f"@executable_path/Frameworks/{built}.framework/{built}"
            compatibility[destination] = described.get("compatibility-version")
        runtime, runtime_files = self.declared_runtime()
        for built in runtime_files:
            library = os.path.basename(macho.install_name(os.path.join(runtime, built)) or built)
            destination = os.path.join(frameworks, library)
            shutil.copy2(os.path.join(runtime, built), destination)
            bundled[destination] = f"@executable_path/Frameworks/{library}"
        bundled.update(self._declared_bundle(bundle, declared))

        names = macho.retarget(bundled)
        for binary in bundled:
            self._verify(binary)
            if compatibility.get(binary):
                macho.require_compatibility_version(binary, compatibility[binary])
            if declared.get("strip"):
                macho.strip(binary, declared["strip"])
            macho.sign(binary)

        self._write_application_plist(bundle, name, declared)
        executable = os.path.join(bundle, name)
        macho.repoint(executable, names)
        carried = {MachO.library_stem(name) for name in names}
        for binary in [executable] + list(bundled):
            elsewhere = [reference for reference in macho.references(binary)
                         if MachO.library_stem(reference) in carried
                         and not reference.startswith("@executable_path/")]
            if elsewhere:
                raise ConanException(
                    f"{binary} loads {', '.join(elsewhere)} from outside its own bundle while the bundle carries "
                    "that library; it would run against whatever the system has there instead of what it was "
                    "built with, and two copies of one runtime in a process do not agree")
        self._verify(executable)
        if declared.get("strip"):
            macho.strip(executable, declared["strip"])

    def _merge_target(self, name):
        if name != "application":
            raise ConanException(f"merge:{name} is not something this toolchain merges; it merges application")
        application = (self.declared.get("application") or {}).get("name")
        if not application:
            raise ConanException(f"{self.name} declares no application to merge")
        variant = self.declared_variant()
        slices = (self.declared.get("variants", {}).get(variant) or {}).get("merge") or []
        if len(slices) < 2:
            raise ConanException(f"the {variant} variant runs merge:application and names fewer than two slices "
                                 "under merge")
        bundles = [os.path.join(self.port_root, "build", slice_name, f"{application}.app") for slice_name in slices]
        missing = [slice_name for slice_name, bundle in zip(slices, bundles) if not os.path.isdir(bundle)]
        if missing:
            raise ConanException(f"there is no {application}.app for {', '.join(missing)}; build each slice "
                                 "before merging, which charon build does when it builds the merging variant")
        binaries, problems = MachO.merge_plan(bundles)
        if problems:
            raise ConanException(f"the slices of {application}.app cannot be merged: " + "; ".join(problems))
        destination = os.path.join(self.build_folder, f"{application}.app")
        rmdir(self, destination)
        shutil.copytree(bundles[0], destination, symlinks=True)
        macho = MachO(self)
        lipo = macho.tool("lipo")
        for relative in binaries:
            merged = os.path.join(destination, relative)
            inputs = " ".join(f'"{os.path.join(bundle, relative)}"' for bundle in bundles)
            self.run(f'"{lipo}" -create {inputs} -output "{merged}"')
            architectures = macho.output(f'"{lipo}" -archs "{merged}"').split()
            if len(architectures) != len(bundles):
                raise ConanException(f"{merged} came out with {', '.join(architectures) or 'no architecture'} "
                                     f"from {len(bundles)} slices; two slices built for the same architecture "
                                     "cannot be told apart")
            self._verify(merged, stripped=True)

    def _sign_target(self, name):
        if name != "application":
            raise ConanException(f"sign:{name} is not something this toolchain signs; it signs application")
        declared = self.declared.get("application", {})
        executable = self._declared_context().get("executable")
        if not executable or not os.path.isfile(executable):
            raise ConanException(f"sign:application found no executable at {executable}; build:application has "
                                 "to run before it")
        self._sign_with(executable, declared.get("entitlements"))

    def _sign_with(self, binary, entitlements):
        macho = MachO(self)
        if not entitlements:
            macho.sign(binary)
            return
        listed = os.path.join(self.port_root, entitlements)
        if not os.path.isfile(listed):
            raise ConanException(f"{binary} is declared with entitlements {entitlements}, and there is no such file")
        macho.sign(binary, listed)
        waived = self.declared_waivers()
        if "entitlements" in waived:
            self.output.warning(f"{binary}: entitlements not read back: {waived['entitlements']}")
            return
        with open(listed, "rb") as handle:
            wanted = plistlib.load(handle)
        problems = [f"{architecture or 'the binary'}: {problem}"
                    for architecture, signed in macho.entitlements(binary).items()
                    for problem in macho.entitlement_problems(wanted, signed)]
        if problems:
            raise ConanException(f"{binary} was signed without what {entitlements} declares: " + "; ".join(problems))

    def declared_runtime(self):
        stage = self.declared.get("stage", {})
        files = stage.get("runtime") or {}
        if not files:
            return None, {}
        package = stage.get("runtime-from")
        if not package:
            raise ConanException(
                f"{self.name} declares [stage.runtime] and no runtime-from under [stage]; nothing says which "
                "package the runtime libraries it names are copied from")
        return self._components(package).libdirs[0], files

    def _application_plist(self, name, declared):
        described = dict(declared.get("plist", {}))
        scheme = described.pop("url-scheme", None)
        info = {}
        written = declared.get("plist-file")
        if written:
            path = os.path.join(self.port_root, written)
            if not os.path.isfile(path):
                raise ConanException(f"{name} names plist-file {written}, and there is no such file")
            with open(path, "rb") as handle:
                info = plistlib.load(handle)
        info.update(described)
        executable = info.get("CFBundleExecutable")
        if executable is not None and executable != name:
            raise ConanException(
                f"{written or 'the declared plist'} gives CFBundleExecutable {executable}, and the application "
                f"built is {name}; the bundle would not start")
        derived = {
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundleExecutable": name,
            "CFBundleVersion": str(self.version),
            "CFBundleShortVersionString": str(self.version),
            "MinimumOSVersion": str(self.settings.os.version),
        }
        for key, value in derived.items():
            info.setdefault(key, value)
        identifier = info.get("CFBundleIdentifier", name)
        if scheme:
            info["CFBundleURLTypes"] = [{"CFBundleURLName": identifier, "CFBundleURLSchemes": [scheme]}]
        return info

    def _declared_bundle(self, bundle, declared):
        name = declared.get("name")
        context = self._declared_context()
        carried = {}
        for entry in declared.get("bundle", []):
            if not isinstance(entry, dict) or not entry.get("from"):
                raise ConanException(f"{name} bundles {entry!r}; an entry is a table with from and, optionally, "
                                     "into")
            source = self._expand(entry["from"], context)
            if not os.path.isfile(source):
                raise ConanException(f"{name} bundles {source}, and there is no such file")
            into = str(entry.get("into", "Frameworks")).strip("/")
            destination = os.path.join(bundle, into, os.path.basename(source))
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            shutil.copy2(source, destination)
            if MachO.is_macho(destination):
                carried[destination] = f"@executable_path/{into}/{os.path.basename(source)}"
        return carried

    def _write_application_plist(self, bundle, name, declared):
        info = self._application_plist(name, declared)
        with open(os.path.join(bundle, "Info.plist"), "wb") as handle:
            plistlib.dump(info, handle)


class MachO:
    """Reading and correcting the Mach-O files a port produces.

    Every method takes a path and answers about that file, so a port says what
    it wants done and never assembles an otool or install_name_tool command of
    its own. A reference that cannot be resolved is refused rather than left for
    dyld to fail on at load, where iOS 6 gives up with no crash log.
    """

    ENCRYPTED = "LC_ENCRYPTION_INFO"
    MAGIC = (b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe")

    def __init__(self, conanfile):
        self._conanfile = conanfile

    def tool(self, name):
        return XCRun(self._conanfile).find(name)

    def output(self, command):
        captured = StringIO()
        self._conanfile.run(command, stdout=captured)
        return captured.getvalue()

    @classmethod
    def merge_plan(cls, bundles):
        listings = []
        for bundle in bundles:
            files = {}
            for folder, _, names in os.walk(bundle):
                for name in names:
                    path = os.path.join(folder, name)
                    if not os.path.islink(path):
                        files[os.path.relpath(path, bundle)] = path
            listings.append(files)
        problems = []
        every = set().union(*listings)
        partial = sorted(relative for relative in every if any(relative not in listing for listing in listings))
        if partial:
            problems.append("present in only some slices: " + ", ".join(partial))
        binaries = []
        for relative in sorted(every - set(partial)):
            paths = [listing[relative] for listing in listings]
            kinds = [cls.is_macho(path) for path in paths]
            if all(kinds):
                binaries.append(relative)
            elif any(kinds):
                problems.append(f"{relative} is a Mach-O in some slices and not in others")
            else:
                contents = set()
                for path in paths:
                    with open(path, "rb") as handle:
                        contents.add(handle.read())
                if len(contents) > 1:
                    problems.append(cls._difference(relative, bundles, paths))
        return binaries, problems

    @staticmethod
    def _difference(relative, bundles, paths):
        slices = [os.path.basename(os.path.dirname(bundle)) for bundle in bundles]
        if not relative.endswith(".plist"):
            return f"{relative} differs between slices"
        try:
            loaded = []
            for path in paths:
                with open(path, "rb") as handle:
                    loaded.append(plistlib.load(handle))
        except Exception:
            return f"{relative} differs between slices"
        keys = sorted({key for plist in loaded for key in plist
                       if len({repr(other.get(key)) for other in loaded}) > 1})
        described = "; ".join("{} ({})".format(key, ", ".join(f"{slice_name}: {plist.get(key)!r}"
                                                               for slice_name, plist in zip(slices, loaded)))
                              for key in keys)
        advice = ""
        if "MinimumOSVersion" in keys:
            advice = ". Each slice derives MinimumOSVersion from its own target; pin it in plist-file"
        return f"{relative} differs between slices in {described}{advice}"

    @classmethod
    def is_macho(cls, path):
        if os.path.islink(path) or not os.path.isfile(path):
            return False
        with open(path, "rb") as candidate:
            return candidate.read(4) in cls.MAGIC

    ARM, ARM64 = 12, 0x0100000C
    EXECUTABLE = 2
    CODE = 0x80000000 | 0x400
    THUMB_DEFINITION = 0x0008
    SECTION_TYPE = 0xFF
    LAZY_POINTERS = (0x07, 0x10)
    SMALLEST_ARM64_PAGEZERO = 1 << 32
    WAIVABLE = ("thumb-interworking", "pagezero", "entitlements", "input-minimum", "weak-imports")
    CPU_TYPES = {"armv7": 12, "armv7s": 12, "armv8": 0x0100000C, "arm64": 0x0100000C}

    @classmethod
    def recorded_minimums(cls, path, cputype):
        with open(path, "rb") as handle:
            if handle.read(8) != b"!<arch>\n":
                return [(None, minimum) for minimum in cls._minimums_at(handle, 0, cputype)]
            found = []
            at = 8
            while True:
                handle.seek(at)
                header = handle.read(60)
                if len(header) < 60:
                    return found
                name, size = header[:16].decode().strip(), int(header[48:58].decode().strip())
                body = at + 60
                if name.startswith("#1/"):
                    length = int(name[3:])
                    handle.seek(body)
                    name = handle.read(length).rstrip(b"\0").decode(errors="replace")
                    start = body + length
                else:
                    start = body
                if not name.startswith("__.SYMDEF"):
                    found += [(name, minimum) for minimum in cls._minimums_at(handle, start, cputype)]
                at = body + size + (size & 1)

    @classmethod
    def _minimums_at(cls, handle, base, cputype):
        handle.seek(base)
        magic = handle.read(4)
        if magic == b"\xca\xfe\xba\xbe":
            count = struct.unpack(">I", handle.read(4))[0]
            slices = [struct.unpack(">iiIII", handle.read(20)) for _ in range(count)]
            return [minimum for kind, _, offset, _, _ in slices if kind == cputype
                    for minimum in cls._minimums_at(handle, base + offset, cputype)]
        if magic not in (b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe"):
            return []
        kind, _, _, ncmds, sizeofcmds = struct.unpack("<iiIII", handle.read(20))
        if kind != cputype:
            return []
        handle.seek(base + (32 if magic == b"\xcf\xfa\xed\xfe" else 28))
        commands = handle.read(sizeofcmds)
        at = 0
        for _ in range(ncmds):
            command, size = struct.unpack_from("<II", commands, at)
            if command == 0x25:
                return [struct.unpack_from("<I", commands, at + 8)[0]]
            if command == 0x32:
                return [struct.unpack_from("<I", commands, at + 12)[0]]
            at += size
        return [None]

    @staticmethod
    def version_text(encoded):
        return "none" if encoded is None else f"{encoded >> 16}.{(encoded >> 8) & 0xFF}" + (
            f".{encoded & 0xFF}" if encoded & 0xFF else "")

    @staticmethod
    def encoded_version(text):
        parts = [int(part) for part in str(text).split(".")] + [0, 0]
        return (parts[0] << 16) | (parts[1] << 8) | parts[2]

    @classmethod
    def minimum_findings(cls, path, cputype, target, label):
        wanted = cls.encoded_version(target)
        findings = []
        for member, minimum in cls.recorded_minimums(path, cputype):
            if minimum == wanted:
                continue
            named = f"{label}({member})" if member else label
            if minimum is None:
                problem = f"{named} records no minimum OS version, so nothing says it was built for {target}"
            elif minimum > wanted:
                problem = f"{named} was built for iOS {cls.version_text(minimum)}, newer than the {target} this links for"
            else:
                problem = (f"{named} was built for iOS {cls.version_text(minimum)} instead of {target}, which means "
                           "it was compiled without the target's flags")
            findings.append((minimum, problem))
        return findings

    @classmethod
    def minimum_problems(cls, path, cputype, target, label):
        return [problem for _, problem in cls.minimum_findings(path, cputype, target, label)]

    @classmethod
    def images(cls, data):
        magic = data[:4]
        if magic in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
            wide = magic == b"\xca\xfe\xba\xbf"
            count = struct.unpack_from(">I", data, 4)[0]
            entry, layout = (32, ">iiQQI") if wide else (20, ">iiIII")
            return [cls._image(data, struct.unpack_from(layout, data, 8 + index * entry)[2])
                    for index in range(count)]
        return [cls._image(data, 0)]

    @classmethod
    def _image(cls, data, base):
        magic = data[base:base + 4]
        if magic not in (b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe"):
            raise ConanException(f"there is no Mach-O image at offset {base}")
        wide = magic == b"\xcf\xfa\xed\xfe"
        cputype, _, filetype, ncmds, _, _ = struct.unpack_from("<iiIIII", data, base + 4)
        image = {"base": base, "cputype": cputype, "filetype": filetype, "wide": wide,
                 "segments": [], "sections": [], "symtab": None, "rebase": None, "local": None}
        at = base + (32 if wide else 28)
        for _ in range(ncmds):
            command, size = struct.unpack_from("<II", data, at)
            if command in (0x1, 0x19):
                if command == 0x19:
                    name, vmaddr, vmsize, fileoff, _, _, _, nsects, _ = struct.unpack_from("<16sQQQQiiII", data, at + 8)
                    first, entry, layout = at + 72, 80, "<16s16sQQIIIIIIII"
                else:
                    name, vmaddr, vmsize, fileoff, _, _, _, nsects, _ = struct.unpack_from("<16sIIIIiiII", data, at + 8)
                    first, entry, layout = at + 56, 68, "<16s16sIIIIIIIIII"
                image["segments"].append({"name": name.rstrip(b"\0").decode(), "vmaddr": vmaddr,
                                          "vmsize": vmsize, "fileoff": fileoff})
                for index in range(nsects):
                    fields = struct.unpack_from(layout, data, first + index * entry)
                    image["sections"].append({"name": fields[0].rstrip(b"\0").decode(), "addr": fields[2],
                                              "size": fields[3], "flags": fields[8]})
            elif command == 0x2:
                image["symtab"] = struct.unpack_from("<IIII", data, at + 8)
            elif command in (0x22, 0x80000022):
                image["rebase"] = struct.unpack_from("<II", data, at + 8)
            elif command == 0xB:
                image["local"] = struct.unpack_from("<II", data, at + 72)
            at += size
        return image

    @staticmethod
    def _uleb(data, at):
        value, shift = 0, 0
        while True:
            byte = data[at]
            at += 1
            value |= (byte & 0x7F) << shift
            shift += 7
            if byte < 0x80:
                return value, at

    @classmethod
    def rebased_slots(cls, data, image):
        segments = image["segments"]
        slots = []
        if image["rebase"] and image["rebase"][1]:
            offset, size = image["rebase"]
            at, end = image["base"] + offset, image["base"] + offset + size
            kind, segment, address, width = 1, 0, 0, 8 if image["wide"] else 4
            while at < end:
                byte = data[at]
                at += 1
                opcode, immediate = byte & 0xF0, byte & 0x0F
                if opcode == 0x00:
                    break
                if opcode == 0x10:
                    kind = immediate
                elif opcode == 0x20:
                    segment = immediate
                    address, at = cls._uleb(data, at)
                elif opcode == 0x30:
                    step, at = cls._uleb(data, at)
                    address += step
                elif opcode == 0x40:
                    address += immediate * width
                elif opcode in (0x50, 0x60, 0x70, 0x80):
                    if opcode == 0x50:
                        times, skip = immediate, 0
                    elif opcode == 0x60:
                        times, at = cls._uleb(data, at)
                        skip = 0
                    elif opcode == 0x70:
                        times = 1
                        skip, at = cls._uleb(data, at)
                    else:
                        times, at = cls._uleb(data, at)
                        skip, at = cls._uleb(data, at)
                    for _ in range(times):
                        if kind in (1, 2):
                            slots.append((segments[segment]["vmaddr"] + address,
                                          image["base"] + segments[segment]["fileoff"] + address))
                        address += width + skip
                else:
                    raise ConanException(f"rebase opcode {byte:#x} is not one this toolchain reads")
        elif image["local"] and image["local"][1] and not image["wide"]:
            offset, count = image["local"]
            relocated = segments[0]["vmaddr"]
            for index in range(count):
                address, info = struct.unpack_from("<II", data, image["base"] + offset + index * 8)
                if address & 0x80000000:
                    kind, length, address = (address >> 24) & 0xF, (address >> 28) & 0x3, address & 0xFFFFFF
                else:
                    kind, length = (info >> 28) & 0xF, (info >> 25) & 0x3
                if kind != 0 or length != 2:
                    continue
                vmaddr = relocated + address
                for described in segments:
                    if described["vmaddr"] <= vmaddr < described["vmaddr"] + described["vmsize"]:
                        slots.append((vmaddr, image["base"] + described["fileoff"] + vmaddr - described["vmaddr"]))
        return slots

    @classmethod
    def code_symbols(cls, data, image):
        if not image["symtab"]:
            return {}
        symoff, nsyms, stroff, _ = image["symtab"]
        code = {index + 1 for index, section in enumerate(image["sections"]) if section["flags"] & cls.CODE}
        found = {}
        for index in range(nsyms):
            strx, kind, section, desc, value = struct.unpack_from("<IBBHI", data, image["base"] + symoff + index * 12)
            if kind & 0xE0 or (kind & 0x0E) != 0x0E or section not in code:
                continue
            end = data.index(b"\0", image["base"] + stroff + strx)
            name = data[image["base"] + stroff + strx:end].decode(errors="replace")
            found.setdefault(value & ~1, set()).add((bool(desc & cls.THUMB_DEFINITION), name))
        return found

    @classmethod
    def interworking_problems(cls, path):
        with open(path, "rb") as handle:
            data = handle.read()
        problems, checked, into_code = [], 0, 0
        for image in cls.images(data):
            if image["cputype"] != cls.ARM:
                continue
            symbols = cls.code_symbols(data, image)
            code = [(section["addr"], section["addr"] + section["size"]) for section in image["sections"]
                    if section["flags"] & cls.CODE]
            lazy = [(section["addr"], section["addr"] + section["size"]) for section in image["sections"]
                    if section["flags"] & cls.SECTION_TYPE in cls.LAZY_POINTERS]
            for slot, position in cls.rebased_slots(data, image):
                if any(start <= slot < end for start, end in lazy):
                    continue
                pointer = struct.unpack_from("<I", data, position)[0]
                if not any(start <= pointer & ~1 < end for start, end in code):
                    continue
                into_code += 1
                described = symbols.get(pointer & ~1)
                if not described or len({thumb for thumb, _ in described}) != 1:
                    continue
                checked += 1
                thumb = next(iter(described))[0]
                name = sorted(name for _, name in described)[0]
                if thumb and not pointer & 1:
                    problems.append(f"the pointer at {slot:#x} to Thumb function {name} lacks bit 0, so a call "
                                    "through it enters Thumb code in ARM state; the linker dropped it")
                elif not thumb and pointer & 1:
                    problems.append(f"the pointer at {slot:#x} to ARM function {name} has bit 0 set, so a call "
                                    "through it enters ARM code in Thumb state; something rewrote it after the link")
        return problems, checked, into_code

    @classmethod
    def pagezero_problems(cls, path):
        with open(path, "rb") as handle:
            data = handle.read()
        problems = []
        for image in cls.images(data):
            if image["filetype"] != cls.EXECUTABLE or image["cputype"] not in (cls.ARM, cls.ARM64):
                continue
            named = {segment["name"]: segment for segment in image["segments"]}
            zero, text = named.get("__PAGEZERO"), named.get("__TEXT")
            if zero is None or text is None:
                problems.append("an executable without __PAGEZERO and __TEXT does not map the way iOS expects")
            elif image["cputype"] == cls.ARM64 and zero["vmsize"] < cls.SMALLEST_ARM64_PAGEZERO:
                problems.append(f"the arm64 __PAGEZERO is {zero['vmsize']:#x}, and a 64-bit iOS executable needs "
                                f"at least {cls.SMALLEST_ARM64_PAGEZERO:#x}; nothing should pass -pagezero_size")
            elif image["cputype"] == cls.ARM and text["vmaddr"] != zero["vmaddr"] + zero["vmsize"]:
                problems.append(f"__PAGEZERO ends at {zero['vmaddr'] + zero['vmsize']:#x} and __TEXT starts at "
                                f"{text['vmaddr']:#x}; the gap is what a post-link edit of the segment leaves")
        return problems

    @staticmethod
    def entitlement_problems(declared, signed):
        return [f"{key} is declared as {value!r} and the signature carries "
                f"{signed[key]!r}" if key in signed else f"{key} is declared and the signature does not carry it"
                for key, value in declared.items() if signed.get(key, object()) != value]

    def entitlements(self, binary):
        lipo = self.tool("lipo")
        architectures = self.output(f'"{lipo}" -archs "{binary}"').split()
        if len(architectures) < 2:
            return {architecture: self._slice_entitlements(binary) for architecture in architectures or [""]}
        found = {}
        with tempfile.TemporaryDirectory() as folder:
            for architecture in architectures:
                thin = os.path.join(folder, architecture)
                self._conanfile.run(f'"{lipo}" "{binary}" -thin {architecture} -output "{thin}"')
                found[architecture] = self._slice_entitlements(thin)
        return found

    def _slice_entitlements(self, binary):
        captured = StringIO()
        if self._conanfile.run(f'"{self.signer()}" -e "{binary}"', stdout=captured, ignore_errors=True):
            return {}
        text = captured.getvalue().strip()
        return plistlib.loads(text.encode()) if text else {}

    def verify(self, binary, waived, stripped=False):
        problems = []
        if "thumb-interworking" in waived:
            self._conanfile.output.warning(f"{binary}: thumb-interworking not checked: {waived['thumb-interworking']}")
        else:
            found, checked, into_code = self.interworking_problems(binary)
            problems += found
            if into_code and not checked and not stripped:
                problems.append(f"none of its {into_code} rebased code pointers names a function in its symbol "
                                "table, so no pointer's mode could be checked; it arrived stripped, and the check "
                                "has to see it before strip")
            self._conanfile.output.info(f"{os.path.basename(binary)}: {checked} of {into_code} rebased code pointers "
                                        "name a function in the symbol table and match its mode")
        if "pagezero" in waived:
            self._conanfile.output.warning(f"{binary}: pagezero not checked: {waived['pagezero']}")
        else:
            problems += self.pagezero_problems(binary)
        if problems:
            shown = "; ".join(problems[:5]) + (f"; and {len(problems) - 5} more" if len(problems) > 5 else "")
            raise ConanException(f"{binary} is not what the platform runs: {shown}")

    def binaries_under(self, root):
        found = []
        for folder, _, names in os.walk(root):
            for name in names:
                path = os.path.join(folder, name)
                if self.is_macho(path):
                    found.append(path)
        return sorted(found)

    @staticmethod
    def library_stem(reference):
        name = os.path.basename(reference)
        return name.split(".", 1)[0]

    def install_name(self, binary):
        listing = self.output(f'"{self.tool("otool")}" -D "{binary}"').splitlines()
        return listing[1].strip() if len(listing) > 1 else None

    def references(self, binary):
        listing = self.output(f'"{self.tool("otool")}" -L "{binary}"')
        found = [match.group(1) for match in re.finditer(r"^\t(\S+) \(compatibility version", listing, re.M)]
        identity = self.install_name(binary)
        return [reference for reference in found if reference != identity]

    def compatibility_version(self, binary):
        commands = self.output(f'"{self.tool("otool")}" -l "{binary}"').split("Load command")
        identity = next((block for block in commands if "cmd LC_ID_DYLIB" in block), "")
        match = re.search(r"compatibility version (\S+)", identity)
        return match.group(1) if match else None

    def refuse_encryption_info(self, root):
        otool = self.tool("otool")
        stamped = [os.path.relpath(path, root) for path in self.binaries_under(root)
                   if self.ENCRYPTED in self.output(f'"{otool}" -l "{path}"')]
        if stamped:
            raise ConanException(f"linked by a linker that stamps {self.ENCRYPTED}, which iOS 6 refuses in a "
                                 f"library it loads: {', '.join(stamped)}")

    def repoint(self, binary, names):
        install_name_tool = self.tool("install_name_tool")
        for reference in self.references(binary):
            target = names.get(os.path.basename(reference))
            if target and target != reference:
                self._conanfile.run(f'"{install_name_tool}" -change "{reference}" "{target}" "{binary}"')

    def retarget(self, identities):
        names = {}
        for binary, identity in identities.items():
            linked = self.install_name(binary)
            if linked:
                names[os.path.basename(linked)] = identity
            names[os.path.basename(identity)] = identity
        install_name_tool = self.tool("install_name_tool")
        for binary, identity in identities.items():
            self._conanfile.run(f'"{install_name_tool}" -id "{identity}" "{binary}"')
            self.repoint(binary, names)
            unresolved = [reference for reference in self.references(binary) if reference.startswith("@rpath/")]
            if unresolved:
                raise ConanException(f"{binary} still depends on {', '.join(unresolved)}")
        return names

    def require_compatibility_version(self, binary, expected):
        found = self.compatibility_version(binary)
        if found != expected:
            raise ConanException(f"{binary} declares compatibility version {found} and the system's clients of "
                                 f"this framework recorded {expected}")

    def strip(self, binary, arguments="-x"):
        self._conanfile.run(f'"{self.tool("strip")}" {arguments} "{binary}"')

    def signer(self):
        return os.path.join(self._conanfile._build_tool("ldid"), "ldid")

    def sign(self, binary, entitlements=None):
        flags = f'-S"{entitlements}"' if entitlements else "-S"
        self._conanfile.run(f'"{self.signer()}" {flags} "{binary}"')


class DebianPackage:
    """A .deb for the device's dpkg, written from a staged filesystem tree.

    The same archive dpkg-deb and theos's dm.pl write: an ar file holding
    debian-binary, control.tar.gz and data.tar.lzma. The version comes from the
    recipe, so the control file a port keeps says everything but that.
    """

    def __init__(self, conanfile, control, root, scripts=None):
        self._conanfile = conanfile
        self._control = control
        self._root = root
        self._scripts = scripts

    def _fields(self):
        with open(self._control) as template:
            text = template.read().rstrip("\n")
        if re.search(r"^(Version|Installed-Size):", text, re.M):
            raise ConanException(f"{self._control} must not carry Version or Installed-Size; the recipe writes them")
        fields = dict(re.findall(r"^([A-Za-z-]+):\s*(.*)$", text, re.M))
        for required in ("Package", "Architecture"):
            if required not in fields:
                raise ConanException(f"{self._control} has no {required} field")
        size = sum(os.lstat(os.path.join(folder, name)).st_size
                   for folder, _, names in os.walk(self._root) for name in names)
        text += f"\nVersion: {self._conanfile.version}\nInstalled-Size: {(size + 1023) // 1024}\n"
        return fields, text

    @staticmethod
    def _tar(members, compression):
        import io
        import tarfile

        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w", format=tarfile.GNU_FORMAT) as archive:
            for name, path, data in members:
                info = archive.gettarinfo(path, arcname=name) if path else tarfile.TarInfo(name)
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                info.mtime = 0
                if data is not None:
                    info.size = len(data)
                    info.mode = 0o644
                    archive.addfile(info, io.BytesIO(data))
                elif info.isfile():
                    with open(path, "rb") as content:
                        archive.addfile(info, content)
                else:
                    archive.addfile(info)
        payload = buffer.getvalue()
        if compression == "gz":
            import gzip
            payload = gzip.compress(payload, mtime=0)
        if compression == "lzma":
            import lzma
            payload = lzma.compress(payload, format=lzma.FORMAT_ALONE, preset=9)
        return payload

    def _data_members(self):
        members = [("./", self._root, None)]
        for folder, directories, names in os.walk(self._root):
            directories.sort()
            for name in sorted(directories) + sorted(names):
                path = os.path.join(folder, name)
                members.append(("./" + os.path.relpath(path, self._root), path, None))
        return members

    def write(self, destination):
        fields, control = self._fields()
        control_members = [("./", self._root, None), ("./control", None, control.encode())]
        if self._scripts and os.path.isdir(self._scripts):
            for name in sorted(os.listdir(self._scripts)):
                control_members.append((f"./{name}", os.path.join(self._scripts, name), None))
        parts = [
            ("debian-binary", b"2.0\n"),
            ("control.tar.gz", self._tar(control_members, "gz")),
            ("data.tar.lzma", self._tar(self._data_members(), "lzma")),
        ]
        os.makedirs(destination, exist_ok=True)
        path = os.path.join(destination,
                            f"{fields['Package']}_{self._conanfile.version}_{fields['Architecture']}.deb")
        with open(path, "wb") as deb:
            deb.write(b"!<arch>\n")
            for name, data in parts:
                deb.write(f"{name:<16}{0:<12}{0:<6}{0:<6}{0o100644:<8o}{len(data):<10}`\n".encode())
                deb.write(data)
                if len(data) % 2:
                    deb.write(b"\n")
        return path

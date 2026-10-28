import("core.base.option")
import("core.project.config")
import("core.project.project")
import("macho")
import("compat")
import("dyld")
import("firmware")
import("objc")
import("signing")
import("bundle")
import("runtime_guards")
import("shared_runtime", {alias = "staged"})
import("backports_package")

function waivers(target)
    local waived = {}
    for _, name in ipairs(macho.waivable()) do
        waived[name] = target:values("revenant.waive." .. name)
    end
    return waived
end

function import_options(target, provided, runtime)
    return {release = os.getenv("REVENANT_RELEASE") ~= nil, waived = waivers(target)["weak-imports"], exempt = provided,
            runtime = runtime, guards = runtime_guards.guards()}
end

function deployment(target)
    local found = target:toolchain("apple-ios")
    found:load()
    return found:config("deployment")
end

function verify_packages(target)
    local _, extra = project.requires_str()
    for _, required in ipairs(table.wrap(target:get("packages"))) do
        local wanted = required:split("%s+")[1]
        local at = wanted:lastof("@", true)
        local name = wanted:sub(at and at + 1 or 1)
        local declared = (extra or {})[required] or {}
        if not target:pkg(name) and project.required_package(required) and not declared.optional then
            raise("target(%s) adds package %s, and nothing of it reached the target%s", target:name(), required,
                  at and string.format("; a require named after its repository reaches one only under an alias: add_requires(\"%s\", {alias = \"%s\"})", wanted, name)
                     or ", so this configuration holds no install of it")
        end
    end
end

function verify_inputs(target)
    local wanted = macho.encoded_version(deployment(target))
    local problems, objects, members = {}, 0, 0
    local function inspect(file, owner)
        for _, recorded in ipairs(macho.recorded_minimums(file, target:arch())) do
            if recorded.member then
                members = members + 1
            else
                objects = objects + 1
            end
            if recorded.minimum ~= wanted then
                local label = (owner and (owner .. "/") or "") .. path.filename(file) .. (recorded.member and ("(" .. recorded.member .. ")") or "")
                if not recorded.minimum then
                    table.insert(problems, string.format("%s records no minimum release, so nothing says it was built for %s", label, deployment(target)))
                elseif recorded.minimum > wanted then
                    table.insert(problems, string.format("%s was built for iOS %s, newer than the %s this links for", label, macho.version_text(recorded.minimum), deployment(target)))
                else
                    table.insert(problems, string.format("%s was built for iOS %s instead of %s, which means it was compiled without the target's flags", label, macho.version_text(recorded.minimum), deployment(target)))
                end
            end
        end
    end
    for _, file in ipairs(target:objectfiles()) do
        if os.isfile(file) then
            inspect(file)
        end
    end
    for _, package in ipairs(target:orderpkgs()) do
        local reason = target:values("revenant.waive.input-minimum." .. package:name())
        if reason then
            wprint("%s: input-minimum not checked for %s: %s", target:name(), package:name(), reason)
        else
            for _, file in ipairs(table.wrap(package:get("libfiles"))) do
                if file:endswith(".a") and os.isfile(file) then
                    inspect(file, package:name())
                end
            end
        end
    end
    if #problems > 0 then
        local shown = table.concat(table.slice(problems, 1, 5), "; ") .. (#problems > 5 and string.format("; and %d more", #problems - 5) or "")
        raise("a link input of %s was not built for this target: %s", target:name(), shown)
    end
    vprint("%s: %d objects and %d archive members record iOS %s", target:name(), objects, members, deployment(target))
end

function verify_installed(package)
    local chosen = assert(package:toolchains(), package:name() .. " is built for apple-ios without the apple-ios toolchain")[1]
    chosen:load()
    local wanted = macho.encoded_version(chosen:config("deployment"))
    local problems, checked = {}, 0
    for _, file in ipairs(os.files(path.join(package:installdir(), "**"))) do
        if macho.is_macho(file) or file:endswith(".a") then
            local recorded = macho.recorded_minimums(file, package:arch())
            if #recorded == 0 then
                table.insert(problems, string.format("%s holds nothing for %s", path.filename(file), package:arch()))
            end
            for _, entry in ipairs(recorded) do
                checked = checked + 1
                if entry.minimum ~= wanted then
                    table.insert(problems, string.format("%s%s records iOS %s, not the %s this package is built for",
                                 path.filename(file), entry.member and ("(" .. entry.member .. ")") or "",
                                 entry.minimum and macho.version_text(entry.minimum) or "nothing", chosen:config("deployment")))
                end
            end
        end
    end
    if #problems > 0 then
        local shown = table.concat(table.slice(problems, 1, 5), "; ") .. (#problems > 5 and string.format("; and %d more", #problems - 5) or "")
        raise("%s installed what it did not build for %s iOS %s: %s", package:name(), package:arch(), chosen:config("deployment"), shown)
    end
    vprint("%s: %d images record %s iOS %s", package:name(), checked, package:arch(), chosen:config("deployment"))
end

function verify_minimum(target, binary)
    local wanted = macho.encoded_version(deployment(target))
    for _, image in ipairs(macho.images(macho.read(binary))) do
        if image.architecture == target:arch() and image.minimum ~= wanted then
            raise("%s records iOS %s, and this target builds for %s; the linker raised it, which it does when a startup object such as crt1.3.1.o is missing", binary, macho.version_text(image.minimum), deployment(target))
        end
    end
end

function imports_source(target, architecture)
    local tool = path.join(target:pkg("firmware-tools"):installdir(), "bin", "revenant-firmware")
    return (firmware.ensure(architecture or target:arch(), deployment(target), {tool = tool}))
end

function backport_targets(target)
    local found = {}
    for _, dependency in ipairs(target:orderdeps()) do
        if dependency:name():endswith("Backports") and dependency:is_shared() then
            table.insert(found, dependency)
        end
    end
    return found
end

function backport_libraries(target)
    local libraries = {}
    for _, dependency in ipairs(backport_targets(target)) do
        table.insert(libraries, dependency:targetfile())
    end
    return libraries
end

local SHARED = {"swift-runtime", "libcxx"}
local LINKED = {"ffmpeg-hevc"}

function shared_packages(target, aliases)
    local all, identities, libraries = {}, {}, {}
    for _, alias in ipairs(aliases or SHARED) do
        local package = target:pkg(alias)
        for _, entry in ipairs(package and table.wrap((package:envs() or {}).REVENANT_SHARED_PACKAGE)[1] and table.wrap((package:envs() or {}).REVENANT_SHARED_PACKAGE)[1]:split(";") or {}) do
            local name, needs = entry:match("^([^=]+)=?(.*)$")
            local folder = "/usr/lib/revenant/" .. name
            local root = path.join(package:installdir(), "share", "root")
            local described = staged.metadata(path.join(package:installdir(), "share", "shared-packages"), name)
            local held = {}
            for _, file in ipairs(os.files(path.join(root, folder, "*.dylib"))) do
                held[folder .. "/" .. path.filename(file)] = true
                identities[path.filename(file)] = folder .. "/" .. path.filename(file)
                table.insert(libraries, file)
            end
            table.insert(all, {meta = described, root = root, name = name, relation = "=",
                               version = described.version, needs = needs ~= "" and needs or nil, held = held})
        end
    end
    return all, identities, libraries
end

function shared_runtime(target)
    local all, identities, libraries = shared_packages(target)
    if #all == 0 then
        return nil
    end
    local byname = {}
    for _, shared in ipairs(all) do
        byname[shared.name] = shared
    end
    for _, shared in ipairs(all) do
        if shared.needs and not byname[shared.needs] then
            raise("target(%s) shares %s, which is linked against %s, and the target itself takes the C++ runtime from a different build; require revenant@libcxx with the same configs as the runtime does (packaged)", target:name(), shared.name, shared.needs)
        end
    end
    local used = {}
    for _, reference in ipairs(macho.images(macho.read(target:targetfile()))[1].libraries) do
        for _, shared in ipairs(all) do
            used[shared.name] = used[shared.name] or shared.held[reference]
        end
    end
    local packages, pending = {}, table.keys(used)
    while #pending > 0 do
        local shared = byname[table.remove(pending)]
        if not packages[shared.name] then
            packages[shared.name] = shared
            if shared.needs then
                table.insert(pending, shared.needs)
            end
        end
    end
    local listed = {}
    for _, name in ipairs(table.orderkeys(packages)) do
        table.insert(listed, packages[name])
    end
    return {packages = listed, identities = identities, libraries = libraries}
end

local PLATFORM_FOLDER = "/usr/lib/revenant/org.revenant.backports/"

function platform_libraries(target)
    local libraries, seen = {}, {}
    local pending = table.wrap(target:values("revenant.platform"))
    while #pending > 0 do
        local file = table.remove(pending, 1)
        if not os.isfile(file) then
            raise("target(%s) names %s as a library the platform package provides, and it is not built: build it first", target:name(), file)
        end
        if not seen[file] then
            seen[file] = true
            table.insert(libraries, file)
            for _, reference in ipairs(macho.images(macho.read(file))[1].libraries) do
                if reference:startswith(PLATFORM_FOLDER) then
                    table.insert(pending, path.join(path.directory(file), path.filename(reference)))
                end
            end
        end
    end
    return libraries
end

function provided_libraries(target)
    local shared = shared_runtime(target)
    return table.join(backport_libraries(target), platform_libraries(target), shared and shared.libraries or {})
end

function project_backports()
    local found = {}
    for _, target in ipairs(project.ordertargets()) do
        if target:name():endswith("Backports") and target:is_shared() and target:is_plat("iphoneos") then
            table.insert(found, target)
        end
    end
    return found
end

function backports_deb(signer)
    if not signer:pkg("ldid") then
        raise("target(%s) signs the Backports package, and carries no ldid to sign it with: add_packages(\"ldid\") to it, or a rule that adds it", signer:name())
    end
    local all, identities = shared_packages(signer)
    local targets = project_backports()
    local linked, linked_identities = linked_packages(targets)
    table.join2(all, linked)
    for leaf, identity in pairs(linked_identities) do
        identities[leaf] = identity
    end
    return backports_package.ensure({targets = targets, ldid = ldid(signer), packages = all, provided = identities,
                                     runtime = backports_runtime(targets),
                                     builddir = path.join(config.builddir(), ".revenant", "backports")})
end

function linked_packages(targets)
    local all, identities, seen = {}, {}, {}
    for _, target in ipairs(targets) do
        local found, found_identities = shared_packages(target, LINKED)
        for leaf, identity in pairs(found_identities) do
            identities[leaf] = identity
        end
        for _, package in ipairs(found) do
            if not seen[package.name] then
                seen[package.name] = true
                table.insert(all, package)
            end
        end
    end
    if #all > 1 then
        raise("the Backports libraries link %d FFmpeg HEVC decoders, %s; the package set carries one", #all, table.concat(table.imap(all, function (_, package) return package.name end), " and "))
    end
    return all, identities
end

function backports_runtime(targets)
    local linked
    for _, target in ipairs(targets) do
        local package = target:pkg("libcxx")
        if package then
            if linked and linked:installdir() ~= package:installdir() then
                raise("the Backports libraries link two C++ runtimes, %s and %s; the package carries one", linked:installdir(), package:installdir())
            end
            linked = package
        end
    end
    return linked and backports_package.carried_runtime(linked) or {}
end

function backport_package(target)
    if #backport_targets(target) == 0 then
        return nil
    end
    return backports_deb(target)
end

function guarded_selectors(target)
    return table.wrap(target:values("revenant.guarded_selectors"))
end

function report_selectors(source, binaries, architecture, folder, provided, declared)
    local found = objc.absent_selectors(source, table.join(binaries, provided or {}), architecture, declared)
    for _, binary in ipairs(binaries) do
        local missing = found[binary]
        if missing then
            local named = folder and path.relative(binary, folder) or binary
            local limit = option.get("verbose") and #missing or 12
            local shown = table.concat(table.slice(missing, 1, math.min(limit, #missing)), " ") .. (#missing > limit and string.format(" and %d more, all of them under xmake -v", #missing - limit) or "")
            cprint("${color.warning}warning:${clear} %s sends %d selector%s no class of the %s release it is checked against implements and no target declares as guarded: %s; a selector the app sends only behind respondsToSelector: or a version check is declared with set_values(\"revenant.guarded_selectors\", ...) on the target that sends it",
                   named, #missing, #missing == 1 and "" or "s", architecture, shown)
        end
    end
end

function verify_one_runtime(target)
    local marks, cxx = {}, {}
    for _, dependency in ipairs(target:orderpkgs()) do
        for _, mark in ipairs(table.wrap((dependency:envs() or {}).REVENANT_SWIFT_RUNTIME_MARK)) do
            marks[mark] = marks[mark] or {}
            table.insert(marks[mark], dependency:name())
        end
        for _, folder in ipairs(table.wrap(dependency:get("linkdirs"))) do
            if os.isfile(path.join(folder, "libc++.dylib")) then
                cxx[folder] = cxx[folder] or {}
                table.insert(cxx[folder], dependency:name())
            end
        end
    end
    for _, what in ipairs({"swift-runtime", "libcxx"}) do
        local builds = what == "libcxx" and cxx or marks
        local names = table.orderkeys(builds)
        if #names > 1 then
            local described = {}
            for _, name in ipairs(names) do
                table.insert(described, string.format("%s (%s)", name:match("packages/(.*)$") or name, table.concat(table.unique(builds[name]), ", ")))
            end
            raise("target(%s) links %d builds of %s at once: %s; a package compiled against it must ask for the same configs as the program does, so that there is one build: require it with the program's configs, or give its recipe the configs to pass on",
                  target:name(), #names, what, table.concat(described, " and "))
        end
    end
end

function verify(target, binary, opt)
    opt = opt or {}
    verify_minimum(target, binary)
    macho.verify(binary, {waived = waivers(target), arrived = compat.arrived("iOS"), process_wide = compat.process_wide(),
                          stripped = opt.stripped})
    if opt.imports ~= false then
        local source = imports_source(target)
        local provided = provided_libraries(target)
        dyld.check(source, table.join({binary}, provided), nil, import_options(target, provided))
        report_selectors(source, {binary}, target:arch(), nil, provided, guarded_selectors(target))
    end
end

function carried_folder(target)
    local control = target:values("revenant.control")
    if not control then
        raise("target(%s) carries %s, and a tweak or daemon keeps what it carries in /usr/lib/revenant/<Package>; name the package with set_values(\"revenant.control\", ...)", target:name(), table.concat(table.wrap(target:values("revenant.libraries")), ", "))
    end
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    local package = debian.control_fields(path.absolute(control, target:scriptdir())).Package
    if not package or package == "" then
        raise("%s has no Package field to name the folder target(%s) carries its libraries in", control, target:name())
    end
    return "/usr/lib/revenant/" .. package
end

local function carries_runtime(library)
    return library.package ~= nil and table.contains(SHARED, library.package)
end

local function carries_guarded(library)
    return carries_runtime(library) or (library.package ~= nil and runtime_guards.declares(library.package))
end

function reached(offered, roots)
    local byname = {}
    for _, library in ipairs(offered) do
        byname[library.name] = library
    end
    local libraries, taken, pending = {}, {}, table.copy(roots)
    while #pending > 0 do
        for _, reference in ipairs(macho.images(macho.read(table.remove(pending)))[1].libraries) do
            local library = byname[path.filename(reference)]
            if library and not taken[library] then
                taken[library] = true
                table.insert(libraries, library)
                table.insert(pending, library.source)
            end
        end
    end
    return libraries
end

function place_carried(target, root, binary)
    local libraries = reached(bundle.carried_libraries(target, "revenant.libraries"), {binary})
    local shared = shared_runtime(target)
    if #libraries == 0 then
        if shared then
            bundle.retarget({binary}, {}, {provided = shared.identities})
        end
        return {binary}
    end
    local folder = carried_folder(target)
    local identities, binaries, runtime = {}, {binary}, {}
    for _, library in ipairs(libraries) do
        local destination = path.join(root, folder, library.name)
        os.mkdir(path.directory(destination))
        os.vcp(library.source, destination)
        identities[destination] = folder .. "/" .. library.name
        table.insert(binaries, destination)
        if carries_guarded(library) then
            table.insert(runtime, destination)
        end
    end
    bundle.retarget(binaries, identities, {home = folder .. "/", provided = shared and shared.identities})
    return binaries, runtime
end

function verify_placed(target, installed)
    if #table.wrap(target:values("revenant.libraries")) == 0 and not shared_runtime(target) then
        return verify(target, target:targetfile())
    end
    local root = path.join(target:targetdir(), ".revenant", "placed", target:name())
    os.tryrm(root)
    local binary = path.join(root, installed)
    os.mkdir(path.directory(binary))
    os.vcp(target:targetfile(), binary)
    local binaries, runtime = place_carried(target, root, binary)
    for _, placed in ipairs(binaries) do
        verify(target, placed, {imports = false})
    end
    local source = imports_source(target)
    local provided = provided_libraries(target)
    dyld.check(source, table.join(binaries, provided), root, import_options(target, provided, runtime))
    report_selectors(source, binaries, target:arch(), root, provided, guarded_selectors(target))
end

function copy_program(source, destination, description)
    os.mkdir(path.directory(destination))
    os.vcp(source, destination)
    local wanted, got = os.filesize(source), os.isfile(destination) and os.filesize(destination) or -1
    if got ~= wanted then
        raise("%s: %s is %d B after being copied and %s is %d B; the image would hold a program that was not built",
               description, destination, got, source, wanted)
    end
    return destination
end

function macho_uuid(binary)
    if not os.isfile(binary) then
        return nil
    end
    local listing = os.tmpfile() .. ".otool"
    os.vrunv("otool", {"-l", binary}, {stdout = listing})
    local reading, uuid = false, nil
    for line in io.readfile(listing):gmatch("[^\n]+") do
        if line:match("cmd +LC_UUID") then
            reading = 1
        elseif reading and reading < 3 then
            reading = reading + 1
            if reading == 3 then
                uuid = line:match("^ +uuid +(%S+)")
                break
            end
        end
    end
    os.tryrm(listing)
    return uuid
end

function verify_provenance(source, installed, description)
    if not os.isfile(installed) then
        raise("%s: %s is not there, so the image would hold no program at all", description, installed)
    end
    if os.mtime(installed) < os.mtime(source) then
        raise("%s: %s is older than the %s it was copied from, so the image would hold a program that was not built",
               description, installed, source)
    end
    local wanted, got = macho_uuid(source), macho_uuid(installed)
    if wanted and got and wanted ~= got then
        raise("%s: %s carries LC_UUID %s and %s carries %s, so the image would hold a program from another build",
               description, installed, got, source, wanted)
    end
    if (wanted and not got) or (got and not wanted) then
        raise("%s: %s carries %s and %s carries %s, so one of the two is not this build's program",
               description, installed, got and got or "no LC_UUID", source, wanted and wanted or "no LC_UUID")
    end
    return installed
end

function install_placed(target, installed)
    local binary = path.join(target:installdir(), installed)
    copy_program(target:targetfile(), binary, target:name())
    verify_provenance(target:targetfile(), binary, target:name())
    local binaries = place_carried(target, target:installdir(), binary)
    for index = #binaries, 1, -1 do
        finish(target, binaries[index])
    end
end

function ldid(target)
    return path.join(target:pkg("ldid"):installdir(), "bin", "ldid")
end

function strip(target, binary)
    local arguments = (target:values("revenant.strip") or "-x"):split("%s+")
    os.vrunv("xcrun", table.join({"strip"}, arguments, {binary}))
end

function sign(target, binary, entitlements)
    signing.sign(ldid(target), binary, {
        entitlements = entitlements and path.join(target:scriptdir(), entitlements),
        waived = waivers(target)
    })
end

function finish(target, binary)
    strip(target, binary)
    sign(target, binary, target:values("revenant.entitlements"))
end

function install_files(target)
    local sources, destinations = target:installfiles(target:installdir())
    for index, source in ipairs(sources or {}) do
        os.mkdir(path.directory(destinations[index]))
        os.vcp(source, destinations[index])
    end
end

function application(target)
    local name = target:basename()
    local folder = path.join(target:targetdir(), name .. ".app")
    os.tryrm(folder)
    local frameworks = path.join(folder, "Frameworks")
    local executable = path.join(folder, name)
    os.mkdir(folder)
    os.vcp(target:targetfile(), executable)
    local identities = {}
    local binaries, runtime = {executable}, {}
    local carried, held, roots = {}, {}, {executable}
    for _, library in ipairs(bundle.carried_libraries(target)) do
        table.insert(carries_runtime(library) and held or carried, library)
        if not carries_runtime(library) then
            table.insert(roots, library.source)
        end
    end
    table.join2(carried, reached(held, roots))
    for _, library in ipairs(carried) do
        local destination = path.join(frameworks, library.name)
        os.mkdir(frameworks)
        os.vcp(library.source, destination)
        identities[destination] = "@executable_path/Frameworks/" .. library.name
        table.insert(binaries, destination)
        if carries_guarded(library) then
            table.insert(runtime, destination)
        end
    end
    local shared = shared_runtime(target)
    bundle.retarget(binaries, identities, {provided = shared and shared.identities})
    bundle.copy_resources(target, folder)
    bundle.write_plist(path.join(folder, "Info.plist"), bundle.info(target, deployment(target)))
    for _, binary in ipairs(binaries) do
        verify(target, binary, {imports = false})
        strip(target, binary)
    end
    for index = #binaries, 1, -1 do
        sign(target, binaries[index], binaries[index] == executable and target:values("revenant.entitlements") or nil)
    end
    if not os.getenv("REVENANT_SLICE") then
        local source = imports_source(target)
        local provided = provided_libraries(target)
        dyld.check(source, table.join(binaries, provided), folder, import_options(target, provided, runtime))
        report_selectors(source, binaries, target:arch(), folder, provided, guarded_selectors(target))
    end
    return folder
end

import("core.base.option")
import("core.project.project")
import("macho")
import("compat")
import("dyld")
import("firmware")
import("objc")
import("signing")
import("bundle")
import("backports")
import("runtime_guards")
import("shared_runtime", {alias = "staged"})

function waivers(target)
    local waived = {}
    for _, name in ipairs(macho.waivable()) do
        waived[name] = target:values("charon.waive." .. name)
    end
    return waived
end

-- The libraries other packages provide (the backports, a shared runtime) are checked with the program, and a weak import in
-- one of them is that package's to answer for when it is built, not a reason to refuse this program.
-- runtime: the copies the program carries of the runtime's libraries and of the packages that declare guard rows, whose weak
-- imports are that library's to answer for where its guard table records them (apple.runtime_guards).
function import_options(target, provided, runtime)
    return {release = os.getenv("CHARON_RELEASE") ~= nil, waived = waivers(target)["weak-imports"], exempt = provided,
            runtime = runtime, guards = runtime_guards.guards()}
end

function deployment(target)
    local found = target:toolchain("apple-ios")
    found:load()
    return found:config("deployment")
end

-- xmake hands a target the packages it adds under the name a require carries,
-- which is its alias, or its own name when it has none: a require named after
-- the repository it comes from reaches no target without one. A target that
-- adds a package and never receives it links against the frameworks of the
-- release alone, and the program it builds fails on the device saying nothing.
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
        local reason = target:values("charon.waive.input-minimum." .. package:name())
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

-- A package checks what it installs: every image is for the architecture and the release it was built for. The sources of
-- a package are one directory for every architecture, so a build tree, or an object, that another configuration left
-- behind would otherwise reach a port as a library it cannot use. Nothing downstream would say so either: a port's link
-- checks its own objects and the static archives of its packages, not the libraries a package installs.
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
    local tool = path.join(target:pkg("firmware-tools"):installdir(), "bin", "charon-firmware")
    return (firmware.ensure(architecture or target:arch(), deployment(target), {tool = tool}))
end

function backport_libraries(target)
    local package = target:pkg("apple-backports")
    local libraries = {}
    for _, folder in ipairs(package and table.wrap(package:get("linkdirs")) or {}) do
        for _, library in ipairs(backports.libraries()) do
            local file = path.join(folder, "lib" .. library.name .. ".dylib")
            if os.isfile(file) then
                table.insert(libraries, file)
            end
        end
    end
    if package and #libraries == 0 then
        raise("target(%s) uses apple-backports, and its link folders %s hold none of its libraries", target:name(), table.concat(table.wrap(package:get("linkdirs")), " "))
    end
    return libraries
end

-- The packages of the runtime a program shares rather than carries: the ones charon@swift-runtime and charon@libcxx wrote
-- for their builds, and the libraries in them under the names the program will find them by.
local SHARED = {"swift-runtime", "libcxx"}

-- Answers the packages of the shared runtime the target's binary is linked against, with what each needs, or nil when it
-- shares none. A package the binary does not load is not depended on: a daemon has no use for the UIKit overlays, and
-- depending on them would put UIKit in its process.
function shared_runtime(target)
    local all, identities, libraries = {}, {}, {}
    for _, alias in ipairs(SHARED) do
        local package = target:pkg(alias)
        for _, entry in ipairs(package and table.wrap((package:envs() or {}).CHARON_SHARED_PACKAGE)[1] and table.wrap((package:envs() or {}).CHARON_SHARED_PACKAGE)[1]:split(";") or {}) do
            local name, needs = entry:match("^([^=]+)=?(.*)$")
            local folder = "/usr/lib/charon/" .. name
            -- what the package left of itself: the tree its libraries are in, and what its Debian package is written from
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
    if #all == 0 then
        return nil
    end
    local byname = {}
    for _, shared in ipairs(all) do
        byname[shared.name] = shared
    end
    -- One copy of libc++abi to a process: the runtime and the program name the same build of it.
    for _, shared in ipairs(all) do
        if shared.needs and not byname[shared.needs] then
            raise("target(%s) shares %s, which is linked against %s, and the target itself takes the C++ runtime from a different build; require charon@libcxx with the same configs as the runtime does (packaged)", target:name(), shared.name, shared.needs)
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

-- What the release's own libraries do not hold and the program finds installed by a package it depends on.
function provided_libraries(target)
    local shared = shared_runtime(target)
    return table.join(backport_libraries(target), shared and shared.libraries or {})
end

function backport_package(target)
    local libraries = backport_libraries(target)
    if #libraries == 0 then
        return nil
    end
    local debs = os.files(path.join(path.directory(path.directory(libraries[1])), "share", backports.package_name() .. "_*.deb"))
    if #debs ~= 1 then
        raise("target(%s) uses apple-backports, whose install holds %d %s packages instead of one", target:name(), #debs, backports.package_name())
    end
    return {deb = debs[1], name = backports.package_name(), relation = ">=", version = path.filename(debs[1]):match("^[^_]+_([^_]+)_")}
end

function report_selectors(source, binaries, architecture, folder, provided)
    local found = objc.absent_selectors(source, table.join(binaries, provided or {}), architecture)
    for _, binary in ipairs(binaries) do
        local missing = found[binary]
        if missing then
            local named = folder and path.relative(binary, folder) or binary
            local limit = option.get("verbose") and #missing or 12
            local shown = table.concat(table.slice(missing, 1, math.min(limit, #missing)), " ") .. (#missing > limit and string.format(" and %d more, all of them under xmake -v", #missing - limit) or "")
            -- xmake shows only the first wprint of a whole run without -v, and one run reports every binary of a
            -- build, so each binary's warning is printed as its own line, as dyld.check prints its warnings.
            cprint("${color.warning}warning:${clear} %s sends %d selector%s no class of the %s release it is checked against implements, which must run only behind respondsToSelector: or a version check: %s",
                   named, #missing, #missing == 1 and "" or "s", architecture, shown)
        end
    end
end

function report_registry(target, binary)
    local libraries = backport_libraries(target)
    if #libraries == 0 then
        return
    end
    local root = path.join(path.directory(path.directory(libraries[1])), "share")
    if not os.isdir(path.join(root, "registry")) then
        return
    end
    local used = macho.imported_symbols(binary, target:arch())
    for selector in pairs((objc.binary_selectors(binary, target:arch()) or {used = {}}).used) do
        used[selector:sub(2)] = true
    end
    local advised = backports.advice(root, used)
    if #advised == 0 then
        return
    end
    local told = {}
    for _, entry in ipairs(advised) do
        table.insert(told, string.format("  %s (iOS %s) is %s: %s", entry.api, entry.introduced or "?", entry.status, entry.effect or "?"))
    end
    cprint("${color.warning}warning:${clear} %s calls %d API the backports do not carry as the release that added them does:\n%s",
           path.filename(binary), #advised, table.concat(told, "\n"))
end

-- One build of the runtime, and one of the C++ runtime, to a program. A package compiled against the runtime (a library of
-- Swift) asks for it with its own configs, and one that asks for another build than the program does puts two of them in the
-- link: the program compiles against one, links libswiftCore from whichever folder comes first, and either fails on the mark
-- or, when the first is the one it compiled against, quietly ignores the variant it asked for. Neither is the answer; refuse.
-- Every package that was built against a runtime reports that runtime's mark in its environment, and a folder that holds
-- libc++ is one build of it.
function verify_one_runtime(target)
    local marks, cxx = {}, {}
    for _, dependency in ipairs(target:orderpkgs()) do
        for _, mark in ipairs(table.wrap((dependency:envs() or {}).CHARON_SWIFT_RUNTIME_MARK)) do
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
        report_selectors(source, {binary}, target:arch(), nil, provided)
        report_registry(target, binary)
    end
end

function carried_folder(target)
    local control = target:values("charon.control")
    if not control then
        raise("target(%s) carries %s, and a tweak or daemon keeps what it carries in /usr/lib/charon/<Package>; name the package with set_values(\"charon.control\", ...)", target:name(), table.concat(table.wrap(target:values("charon.libraries")), ", "))
    end
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    local package = debian.control_fields(path.absolute(control, target:scriptdir())).Package
    if not package or package == "" then
        raise("%s has no Package field to name the folder target(%s) carries its libraries in", control, target:name())
    end
    return "/usr/lib/charon/" .. package
end

-- The copies a program carries of the runtime's libraries are that runtime's images, as they are when it shares them: a weak
-- import its guard table records is the runtime's to answer for, and the program's own images are checked as usual.
local function carries_runtime(library)
    return library.package ~= nil and table.contains(SHARED, library.package)
end

-- The copies a program carries whose weak imports the guard table answers for: the runtime's, and a package's own libraries
-- that the package declares rows for (apple.runtime_guards' PACKAGES). Only the runtime's are shared, so only they are held.
local function carries_guarded(library)
    return carries_runtime(library) or (library.package ~= nil and runtime_guards.declares(library.package))
end

-- The libraries of `offered` (a list of {name, source}) the images in `roots` load, directly or through one another: what a
-- program carries of a package is what it links, and not every library the package holds.
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
    local libraries = reached(bundle.carried_libraries(target, "charon.libraries"), {binary})
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
    if #table.wrap(target:values("charon.libraries")) == 0 and not shared_runtime(target) then
        return verify(target, target:targetfile())
    end
    local root = path.join(target:targetdir(), ".charon", "placed", target:name())
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
    report_selectors(source, binaries, target:arch(), root, provided)
end

-- A copy that failed must not pass for one that happened. os.vcp is a clone-file copy and reports
-- failure by returning nothing at all, so a caller that ignores it writes a package without the program
-- in it and the install still says it installed one: the guest then runs whatever the image last had,
-- which is how an install reports success and leaves the program two edits old. The size is the check,
-- because a program is never rewritten to the same length by accident mid-install.
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

-- A file's LC_UUID, which is the one thing neither strip nor a signature touches: strip rewrites the
-- bytes before the signature and ldid adds one after, so a size or a hash says nothing about which build
-- a copy came from - measured, a build output and the copy an install stages of it report the same
-- __TEXT size and differ by 1128 bytes - and the UUID says exactly that. Read with the host's otool,
-- the way the platform's other Mach-O questions are read off a binary.
-- A file's LC_UUID, which is the one thing neither strip nor a signature touches: strip rewrites the
-- bytes before the signature and ldid adds one after, so a size or a hash says nothing about which build a
-- copy came from - measured, a build output and the copy an install stages of it report the same __TEXT
-- size and differ by 1128 bytes - and the UUID says exactly that. otool reads the byte order itself, so
-- the Mach-O is not parsed here; the two lines after LC_UUID are cmdsize and then the uuid.
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

-- That the file an install staged is the build's own, and not an earlier one. An install that stages a
-- program it did not build writes a package, says it installed one, and leaves the image with whatever
-- it last had - so both are refused here, the copy being older than its source and the copy carrying
-- another build's UUID, and the file is named either way.
function verify_provenance(source, installed, description)
    if not os.isfile(installed) then
        raise("%s: %s is not there, so the image would hold no program at all", description, installed)
    end
    if os.mtime(installed) < os.mtime(source) then
        raise("%s: %s is older than the %s it was copied from, so the image would hold a program that was not built",
               description, installed, source)
    end
    -- Two builds, and the copy is from the other one. This is the check that strip and a signature cannot
    -- hide behind, and it is what catches a stage that was never refreshed.
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
    local arguments = (target:values("charon.strip") or "-x"):split("%s+")
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
    sign(target, binary, target:values("charon.entitlements"))
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
    -- The runtime's libraries are the ones the program loads, through its own libraries as well; the rest of what it carries
    -- is carried whether it names it or not (a framework it opens at run time is no link of the executable's).
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
        sign(target, binaries[index], binaries[index] == executable and target:values("charon.entitlements") or nil)
    end
    if not os.getenv("CHARON_SLICE") then
        local source = imports_source(target)
        local provided = provided_libraries(target)
        dyld.check(source, table.join(binaries, provided), folder, import_options(target, provided, runtime))
        report_selectors(source, binaries, target:arch(), folder, provided)
    end
    return folder
end

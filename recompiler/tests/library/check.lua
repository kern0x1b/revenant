local function segments(file)
    local list, current, section = {}, nil, nil
    for line in os.iorunv("otool", {"-l", file}):gmatch("[^\n]+") do
        if line:match("^Load command") then
            current, section = nil, nil
        elseif line:match("^%s+cmd LC_SEGMENT$") then
            current = {sections = {}}
            section = nil
            table.insert(list, current)
        elseif current then
            local sectname = line:match("^%s+sectname (%S+)")
            if sectname then
                section = {name = sectname}
                table.insert(current.sections, section)
            elseif section then
                section.offset = section.offset or tonumber(line:match("^%s+offset (%d+)") or "")
                section.size = section.size or tonumber(line:match("^%s+size 0x(%x+)") or "", 16)
            else
                current.name = current.name or line:match("^%s+segname (%S+)")
                current.address = current.address or tonumber(line:match("^%s+vmaddr 0x(%x+)") or "", 16)
                current.size = current.size or tonumber(line:match("^%s+vmsize 0x(%x+)") or "", 16)
            end
        end
    end
    return list
end

local function word(data, offset)
    local a, b, c, d = data:byte(offset, offset + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

local function guest_header(file, list)
    for _, segment in ipairs(list) do
        for _, section in ipairs(segment.sections) do
            if segment.name == "__XGUEST" and section.name == "__image" then
                local data = io.readfile(file, {encoding = "binary"})
                local at = section.offset + 1
                return {offset = section.offset, size = section.size, magic = word(data, at), version = word(data, at + 4), low = word(data, at + 8),
                        high = word(data, at + 12), count = word(data, at + 16), data = data}
            end
        end
    end
end

local function exports(file)
    local list = {}
    for line in os.iorunv("nm", {"-gU", file}):gmatch("[^\n]+") do
        table.insert(list, line:match("(%S+)$"))
    end
    table.sort(list)
    return list
end

local function dependencies(file, dirs, found)
    for line in os.iorunv("otool", {"-L", file}):gmatch("[^\n]+") do
        local leaf = line:match("^%s+@rpath/(%S+)")
        if leaf and not found[leaf] then
            for _, dir in ipairs(dirs) do
                local candidate = path.join(dir, leaf)
                if os.isfile(candidate) then
                    found[leaf] = candidate
                    dependencies(candidate, dirs, found)
                    break
                end
            end
        end
    end
end

local function map_phases(text)
    local phases = {}
    for line in text:gmatch("[^\r\n]+") do
        local phase, rest = line:match("^xl%-map (%S+) (.+)$")
        if phase then
            local entry = phases[phase]
            if not entry then
                entry = {regions = {}, holes = 0}
                phases[phase] = entry
            end
            local first, last, size, protection, maximum, share, tag, name =
                rest:match("^region 0x(%x+) 0x(%x+) 0x(%x+) (%S+)/(%S+) (%S+) (%d+) ?(.*)$")
            if first then
                table.insert(entry.regions, {first = tonumber(first, 16), last = tonumber(last, 16), size = tonumber(size, 16), protection = protection,
                                             maximum = maximum, share = share, tag = tonumber(tag), name = name})
            elseif rest:match("^hole 0x%x+ 0x%x+ 0x%x+$") then
                entry.holes = entry.holes + 1
            elseif rest == "begin" then
                entry.begin = true
            elseif rest == "end" then
                entry.finish = true
            else
                local mapped, free, largest_start, largest_size, low =
                    rest:match("^summary mapped=0x(%x+) free=0x(%x+) largest_start=0x(%x+) largest_size=0x(%x+) free_below_0x30000000=0x(%x+)$")
                if mapped then
                    entry.summary = {mapped = tonumber(mapped, 16), free = tonumber(free, 16), largest_start = tonumber(largest_start, 16),
                                     largest_size = tonumber(largest_size, 16), low = tonumber(low, 16)}
                end
            end
        end
    end
    return phases
end

local function map_overlap(entry, low, high)
    local covered, overlapping = 0, {}
    for _, region in ipairs(entry.regions) do
        local first, last = math.max(region.first, low), math.min(region.last, high)
        if last > first then
            covered = covered + (last - first)
            table.insert(overlapping, region)
        end
    end
    return covered, overlapping
end

local function check_map(corpus, text, phases, what)
    local found = map_phases(text)
    for _, name in ipairs(phases) do
        local entry = found[name]
        if not entry or not entry.begin or not entry.finish or not entry.summary then
            io.write(text)
            corpus.fail("%s: the map %s is missing or has no begin, end or summary line", what, name)
        end
        local previous = 0
        for _, region in ipairs(entry.regions) do
            if region.first < previous or region.last <= region.first or region.last - region.first ~= region.size then
                io.write(text)
                corpus.fail("%s: the map %s lists a region 0x%x-0x%x out of order, empty or of another size than its range", what, name, region.first, region.last)
            end
            previous = region.last
        end
        if #entry.regions < 10 or entry.summary.largest_size < 0x100000 or entry.summary.mapped == 0 then
            io.write(text)
            corpus.fail("%s: the map %s has %d regions and a largest hole of 0x%x", what, name, #entry.regions, entry.summary.largest_size)
        end
    end
    return found
end

local EXPECTED = {"reserve", "load", "class", "create", "methods", "describe", "bundle", "bundle.path", "token", "category", "completion", "completion.thread"}
local SWIFT_HOST_EXPECTED = {"host.bridge.before", "host.names", "names.disjoint", "host.bridge.after"}

local function build_objc(e, corpus, o, here)
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-Wl,-no_objc_category_merging", "-O2", "-w", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/RCFixture.dylib", "-framework", "Foundation", "-I", here,
                   path.join(here, "fixture.m"), "-o", o("RCFixture.dylib")})
    io.writefile(o("includes.h"), string.format('#include "%s"\n#include "%s"\n', path.join(e.recompiler, "include", "uikit-includes.h"), path.join(here, "RCFixture.h")))
    local install = os.getenv("XL_LIBRARY_INSTALL_NAME") == "executable" and "@executable_path/RCFixture.dylib" or nil
    return {XL_LIBRARY = "1", XL_INSTALL_NAME = install}, {}
end

local function build_swift(e, corpus, o, here)
    local libs = os.getenv("XL_SWIFTOBJC_LIBS")
    if not libs or not os.isdir(libs) then
        raise("XL_SWIFTOBJC_LIBS must name the folder with libswiftCore.dylib (the arm64 runtime of revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
    end
    local swift, layouts = corpus.swift()
    os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                 "-runtime-compatibility-version", "none", "-emit-library", "-module-name", "RCFixture",
                                                 "-emit-objc-header-path", o("RCFixture-Swift.h"), "-Xlinker", "-install_name", "-Xlinker", "@rpath/RCFixture.dylib",
                                                 "-o", o("RCFixture.dylib"), path.join(here, "fixture.swift")})
    io.writefile(o("includes.h"), string.format('#include "%s"\n#include "%s"\n', path.join(e.recompiler, "include", "swiftdemo-includes.h"), o("RCFixture-Swift.h")))
    return {XL_LIBRARY = "1", XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"},
           {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
end

function main(out, ...)
    local variant, host_only = "objc", false
    for _, argument in ipairs({...}) do
        if type(argument) == "table" then
            host_only = argument.host_only or host_only
        elseif argument == "--host-only" then
            host_only = true
        else
            variant = argument
        end
    end
    local build = ({objc = build_objc, swift = build_swift})[variant]
    if not build then
        raise("the library variant is objc or swift, not %s", variant)
    end
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("library-" .. variant, out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end

    local options, images = build(e, corpus, o, here)
    translate.translate(o("RCFixture.dylib"), o("includes.h"), o("xl"), images, options)
    local library = o("xl/RCFixture.dylib")

    local list = segments(library)
    local previous = -1
    for _, segment in ipairs(list) do
        if segment.address < previous then
            corpus.fail("segment %s is below the segment before it, which dyld refuses", segment.name)
        end
        previous = segment.address + segment.size
    end
    local names = {}
    for _, segment in ipairs(list) do
        names[segment.name] = segment
        if segment.name:match("^__X%d") then
            corpus.fail("the library has the guest segment %s: guest segments are bytes of %s, mapped by the loader", segment.name, "__XGUEST")
        end
    end
    if not names.__LINKEDIT or not names.__XGUEST then
        corpus.fail("the library has no __LINKEDIT or no __XGUEST segment")
    end
    local base = tonumber(os.getenv("XL_BASE") or "0x10000000")
    local guest = guest_header(library, list)
    if not guest or guest.magic ~= 0x49474c58 or guest.version ~= 1 or guest.count == 0 then
        corpus.fail("the section __XGUEST,__image does not start with a version 1 header with segments")
    end
    if guest.low % 0x4000 ~= 0 or guest.high % 0x4000 ~= 0 or guest.low < base or guest.low >= guest.high then
        corpus.fail("the guest image range 0x%x-0x%x is not whole 16 KiB granules from the base 0x%x up", guest.low, guest.high, base)
    end
    local symbols = {}
    local categories = 0
    for _, symbol in ipairs(exports(library)) do
        if symbol:startswith("_xl_objc_category_") then
            categories = categories + 1
        else
            table.insert(symbols, symbol)
        end
    end
    if table.concat(symbols, " ") ~= "_xl_library_diagnostics _xl_library_init" then
        corpus.fail("the library exports %s, not exactly its two entry points and the category structures the registry lists", table.concat(symbols, " "))
    end
    local registry = o("xl/RCFixture-classes.dylib")
    if not os.isfile(registry) then
        corpus.fail("the registry %s was not built", registry)
    end
    local lists = {}
    for _, segment in ipairs(segments(registry)) do
        for _, section in ipairs(segment.sections) do
            lists[section.name] = section.size
        end
    end
    for name, size in pairs(lists) do
        if not name:startswith("__objc_") and size > 0 then
            corpus.fail("the registry has the section %s of %d bytes: it holds only what libobjc reads", name, size)
        end
    end
    if (lists.__objc_classlist or 0) < 8 or (lists.__objc_catlist or 0) ~= 4 * categories or #exports(registry) ~= 0 then
        corpus.fail("the registry lists %d bytes of classes and %d bytes of categories for %d category structures, and exports %d symbols", lists.__objc_classlist or 0, lists.__objc_catlist or 0, categories, #exports(registry))
    end

    local host_sources = {path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c")}
    local host_flags = {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit"}
    local expected = EXPECTED
    local runtime
    local bridging = (os.getenv("XL_LIBRARY_HOST_BRIDGING") or "") ~= ""
    local host_runtime = os.getenv("XL_LIBRARY_HOST_RUNTIME")
    if variant == "swift" then
        local swift = corpus.swift()
        runtime = corpus.swift_armv7()
        os.execv(path.join(swift, "bin", "swiftc"), table.join({"-target", "armv7-apple-ios6.0", "-clang-target", "armv7-apple-ios6.0", "-sdk", e.sdk,
                                                     "-resource-dir", path.join(runtime, "lib", "swift"), "-I", path.join(runtime, "lib", "swift", "iphoneos"),
                                                     "-Xfrontend", "-bundled-swift-runtime",
                                                     "-runtime-compatibility-version", "none", "-plugin-path", path.join(swift, "lib", "swift", "host", "plugins"),
                                                     "-Xfrontend", "-disable-implicit-concurrency-module-import", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                                                     "-parse-as-library", "-wmo", "-O", "-module-name", "RCHost", "-emit-object", "-o", o("hostswift.o")},
                                                     bridging and {"-DBRIDGING"} or {}, {path.join(here, "hostswift.swift")}))
        table.join2(host_flags, {"-DRC_SWIFT_HOST", "-L", path.join(runtime, "lib", "swift", "iphoneos"), "-lswiftCore",
                                  "-Wl,-rpath,@executable_path", o("hostswift.o")})
        if bridging then
            table.join2(host_flags, {"-DRC_BRIDGING", "-lswiftFoundation"})
        end
        expected = {}
        for _, name in ipairs(EXPECTED) do
            if name ~= "category" then
                table.insert(expected, name)
            end
        end
        expected = table.join(expected, SWIFT_HOST_EXPECTED)
    end
    corpus.armv7(e, table.join(host_flags, host_sources, {"-o", o("host")}))
    corpus.sign(e, o("host"))
    if host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/xl-library"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(library, remote .. "/RCFixture.dylib")
    device.copy(registry, remote .. "/RCFixture-classes.dylib")
    device.run("mkdir -p " .. remote .. "/alone")
    device.copy(library, remote .. "/alone/RCFixture.dylib")
    device.copy(o("host"), remote .. "/xl-library-host")
    if runtime and not host_runtime then
        local found = {}
        dependencies(o("host"), {path.join(runtime, "lib", "swift", "iphoneos"), corpus.libcxx_armv7()}, found)
        for leaf, file in pairs(found) do
            os.cp(file, o("runtime-" .. leaf))
            os.runv("chmod", {"u+w", o("runtime-" .. leaf)})
            corpus.sign(e, o("runtime-" .. leaf))
            device.copy(o("runtime-" .. leaf), remote .. "/" .. leaf)
        end
    end
    local resident = os.getenv("XL_LIBRARY_RESIDENT_MB") or "85"
    local launches = tonumber(os.getenv("XL_LIBRARY_LAUNCHES") or "1")
    local environment = "DYLD_FALLBACK_LIBRARY_PATH=" .. (host_runtime or remote)
    if os.getenv("XL_LIBRARY_INSTALL_NAME") == "executable" and variant == "objc" then
        environment = "XL_LIBRARY_NO_FALLBACK=1"
    end
    local function launch(arguments, extra)
        return try { function ()
            return device.run("chmod +x " .. remote .. "/xl-library-host && cd " .. remote .. " && " .. (extra or "") .. environment .. " ./xl-library-host " .. arguments .. " 2>&1; echo exit=$?")
        end } or ""
    end
    local function verify(output, names, what)
        local text = "\n" .. output:gsub("\r", "")
        for _, name in ipairs(names) do
            if not text:find("\nok " .. name .. "\n", 1, true) then
                io.write(output)
                corpus.fail("%s: the host did not report ok for %s", what, name)
            end
        end
        if text:find("\nFAIL ", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
            io.write(output)
            corpus.fail("%s: the host reported a failure or did not run to its end", what)
        end
        if text:find("is implemented in both", 1, true) then
            io.write(output)
            corpus.fail("%s: the Objective-C runtime found two classes of one name, the host's and the library's", what)
        end
    end

    local range = string.format("%x-%x", guest.low, guest.high)
    local newer = o("RCFixtureV2.dylib")
    local patched = guest.data:sub(1, guest.offset + 4) .. "\2\0\0\0" .. guest.data:sub(guest.offset + 9)
    io.writefile(newer, patched, {encoding = "binary"})
    os.runv("chmod", {"u+w", newer})
    corpus.sign(e, newer)
    device.copy(newer, remote .. "/RCFixtureV2.dylib")

    local controls = {
        {"a guest range another mapping holds", remote .. "/RCFixture.dylib 20 @" .. range .. " --expect=busy", {"occupy", "reserve.refused", "load.refused", "class.absent", "occupant.intact"}},
        {"a library with a guest image format this loader does not read", remote .. "/RCFixtureV2.dylib 20 --expect=image", {"reserve.refused", "load.refused", "class.absent"}},
        {"a library whose registry is not next to it", remote .. "/alone/RCFixture.dylib 20 --expect=registry", {"reserve.refused", "load.refused", "class.absent"}},
        {"an init without a reservation, over a mapping with data", remote .. "/RCFixture.dylib 20 +" .. range .. " --expect=direct", {"occupy", "dlopen", "init.refused", "init.final", "occupant.intact"}},
    }
    local outputs = {}
    for _, control in ipairs(controls) do
        local output = launch(control[2])
        table.insert(outputs, output)
        verify(output, control[3], control[1])
    end
    local output
    for launch_number = 1, launches do
        output = launch(remote .. "/RCFixture.dylib " .. resident)
        if launches > 1 then
            io.writefile(o(string.format("run-%02d.txt", launch_number)), output)
        end
        verify(output, expected, "launch " .. launch_number)
    end
    for _, text in ipairs({output, table.concat(outputs, "\n")}) do
        if text:find("xl-map", 1, true) then
            io.write(text)
            corpus.fail("the host printed a map of the address space with XL_LOADER_MAP unset")
        end
    end
    local first, last = math.huge, 0
    for _, segment in ipairs(list) do
        if segment.name ~= "__PAGEZERO" and segment.size > 0 then
            first = math.min(first, segment.address)
            last = math.max(last, segment.address + segment.size)
        end
    end
    local host_size = last - first
    local mapped = launch(remote .. "/RCFixture.dylib " .. resident, "XL_LOADER_MAP=1 ")
    verify(mapped, expected, "launch with XL_LOADER_MAP=1")
    local found = check_map(corpus, mapped, {"before-reserve", "reserve", "before-dlopen", "load"}, "XL_LOADER_MAP=1")
    if not mapped:find("\nxl-map reserve config host_reserve=1 host_size=0x" .. string.format("%x", host_size), 1, true) or
       found["before-dlopen"].summary.largest_size < host_size then
        io.write(mapped)
        corpus.fail("the map has no config line of the reservation of the host part, or no hole of its %d bytes at the dlopen", host_size)
    end
    if map_overlap(found["before-reserve"], guest.low, guest.high) ~= 0 then
        io.write(mapped)
        corpus.fail("the map before the reservation already shows a mapping inside the guest range 0x%x-0x%x", guest.low, guest.high)
    end
    local covered, held = map_overlap(found.reserve, guest.low, guest.high)
    for _, region in ipairs(held) do
        if region.protection ~= "---" then
            io.write(mapped)
            corpus.fail("the map after xl_reserve shows 0x%x-0x%x of the guest range with protection %s, not ---", region.first, region.last, region.protection)
        end
    end
    if covered ~= guest.high - guest.low then
        io.write(mapped)
        corpus.fail("the map after xl_reserve covers 0x%x of the guest range 0x%x-0x%x", covered, guest.low, guest.high)
    end
    local room = false
    for _, region in ipairs(found.reserve.regions) do
        if region.protection == "---" and region.size >= host_size and (region.last <= guest.low or region.first >= guest.high) then
            room = true
        end
    end
    if not room then
        io.write(mapped)
        corpus.fail("the map after xl_reserve shows no inaccessible region of the host part's %d bytes outside the guest range", host_size)
    end
    local function names_library(entry)
        for _, region in ipairs(entry.regions) do
            if region.name:find("RCFixture.dylib", 1, true) then
                return true
            end
        end
        return false
    end
    local _, mapped_guest = map_overlap(found.load, guest.low, guest.high)
    local readable = false
    for _, region in ipairs(mapped_guest) do
        readable = readable or region.protection:sub(1, 1) == "r"
    end
    if not readable or names_library(found.reserve) or not names_library(found.load) then
        io.write(mapped)
        corpus.fail("the map after xl_load shows no readable guest segment, or the library's own image is not where it should be (reserve: %s, load: %s)",
                    tostring(names_library(found.reserve)), tostring(names_library(found.load)))
    end
    local unreserved = launch(remote .. "/RCFixture.dylib " .. resident, "XL_LOADER_MAP=1 XL_LOADER_HOST_RESERVE=0 ")
    verify(unreserved, expected, "launch with XL_LOADER_HOST_RESERVE=0")
    local bare = check_map(corpus, unreserved, {"before-reserve", "reserve", "before-dlopen", "load"}, "XL_LOADER_HOST_RESERVE=0")
    local _, bare_held = map_overlap(bare.reserve, guest.low, guest.high)
    local bare_room = false
    for _, region in ipairs(bare.reserve.regions) do
        if region.protection == "---" and region.size >= host_size and (region.last <= guest.low or region.first >= guest.high) then
            bare_room = true
        end
    end
    if not unreserved:find("\nxl-map reserve config host_reserve=0 host_size=0x" .. string.format("%x", host_size) .. " host_low=0x0 ", 1, true) or bare_room or #bare_held == 0 or
       not names_library(bare.load) then
        io.write(unreserved)
        corpus.fail("with XL_LOADER_HOST_RESERVE=0 the loader still holds room for the host part, lost the guest reservation, or the library did not load")
    end
    local crash_log = "/private/var/revenant/xlate-crash.log"
    local function crash(extra)
        device.run("rm -f " .. crash_log)
        local text = launch(remote .. "/RCFixture.dylib " .. resident .. " --abort", extra)
        return text .. "\n" .. (try { function ()
            return device.run("cat " .. crash_log .. " 2>/dev/null; true")
        end } or "")
    end
    local crashed = crash("XL_LOADER_MAP=1 ")
    if not crashed:find("\nok diagnostics\n", 1, true) or not crashed:find("xlate: signal 6", 1, true) then
        io.write(crashed)
        corpus.fail("the host that aborts did not reach the crash handler of the runtime")
    end
    local crash_found = check_map(corpus, crashed, {"crash"}, "a crash with XL_LOADER_MAP=1")
    local _, crash_guest = map_overlap(crash_found.crash, guest.low, guest.high)
    local crash_readable = false
    for _, region in ipairs(crash_guest) do
        crash_readable = crash_readable or region.protection:sub(1, 1) == "r"
    end
    if not crash_readable then
        io.write(crashed)
        corpus.fail("the map in the crash handler shows no readable guest segment")
    end
    local silent = crash("")
    if not silent:find("xlate: signal 6", 1, true) or silent:find("xl-map", 1, true) then
        io.write(silent)
        corpus.fail("the crash handler did not run, or printed a map with XL_LOADER_MAP unset")
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), output .. table.concat(outputs, "\n") .. mapped .. crashed)
    print("ok: a translated library loads into a %s MB host and answers (%d checks in each of %d launches, %d negative controls)", resident, #expected, launches, #controls)
end

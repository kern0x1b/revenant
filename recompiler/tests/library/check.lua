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

local EXPECTED = {"reserve", "load", "class", "create", "methods", "describe", "bundle", "bundle.path", "token", "completion", "completion.thread"}
local SWIFT_HOST_EXPECTED = {"host.bridge.before", "host.names", "names.disjoint", "host.bridge.after"}

local function build_objc(e, corpus, o, here)
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/RCFixture.dylib", "-framework", "Foundation", "-I", here,
                   path.join(here, "fixture.m"), "-o", o("RCFixture.dylib")})
    io.writefile(o("includes.h"), string.format('#include "%s"\n#include "%s"\n', path.join(e.recompiler, "include", "uikit-includes.h"), path.join(here, "RCFixture.h")))
    return {XL_LIBRARY = "1"}, {}
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
    local symbols = exports(library)
    if table.concat(symbols, " ") ~= "_xl_library_diagnostics _xl_library_init" then
        corpus.fail("the library exports %s, not exactly its two entry points", table.concat(symbols, " "))
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
        expected = table.join(EXPECTED, SWIFT_HOST_EXPECTED)
    end
    corpus.armv7(e, table.join(host_flags, host_sources, {"-o", o("host")}))
    corpus.sign(e, o("host"))
    if host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.run("mkdir -p /var/tmp/xl-library")
    device.copy(library, "/var/tmp/xl-library/RCFixture.dylib")
    device.copy(o("host"), "/var/tmp/xl-library/xl-library-host")
    if runtime and not host_runtime then
        local found = {}
        dependencies(o("host"), {path.join(runtime, "lib", "swift", "iphoneos"), corpus.libcxx_armv7()}, found)
        for leaf, file in pairs(found) do
            os.cp(file, o("runtime-" .. leaf))
            os.runv("chmod", {"u+w", o("runtime-" .. leaf)})
            corpus.sign(e, o("runtime-" .. leaf))
            device.copy(o("runtime-" .. leaf), "/var/tmp/xl-library/" .. leaf)
        end
    end
    local resident = os.getenv("XL_LIBRARY_RESIDENT_MB") or "85"
    local launches = tonumber(os.getenv("XL_LIBRARY_LAUNCHES") or "1")
    local environment = "DYLD_FALLBACK_LIBRARY_PATH=" .. (host_runtime or "/var/tmp/xl-library")
    local function launch(arguments)
        return try { function ()
            return device.run("chmod +x /var/tmp/xl-library/xl-library-host && cd /var/tmp/xl-library && " .. environment .. " ./xl-library-host " .. arguments .. " 2>&1; echo exit=$?")
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
    device.copy(newer, "/var/tmp/xl-library/RCFixtureV2.dylib")

    local controls = {
        {"a guest range another mapping holds", "/var/tmp/xl-library/RCFixture.dylib 20 @" .. range .. " --expect=busy", {"occupy", "reserve.refused", "load.refused", "class.absent", "occupant.intact"}},
        {"a library with a guest image format this loader does not read", "/var/tmp/xl-library/RCFixtureV2.dylib 20 --expect=image", {"reserve.refused", "load.refused", "class.absent"}},
        {"an init without a reservation, over a mapping with data", "/var/tmp/xl-library/RCFixture.dylib 20 +" .. range .. " --expect=direct", {"occupy", "dlopen", "init.refused", "init.final", "occupant.intact"}},
    }
    local outputs = {}
    for _, control in ipairs(controls) do
        local output = launch(control[2])
        table.insert(outputs, output)
        verify(output, control[3], control[1])
    end
    local output
    for launch_number = 1, launches do
        output = launch("/var/tmp/xl-library/RCFixture.dylib " .. resident)
        if launches > 1 then
            io.writefile(o(string.format("run-%02d.txt", launch_number)), output)
        end
        verify(output, expected, "launch " .. launch_number)
    end
    device.run("rm -rf /var/tmp/xl-library")
    io.writefile(o("run.txt"), output .. table.concat(outputs, "\n"))
    print("ok: a translated library loads into a %s MB host and answers (%d checks in each of %d launches, %d negative controls)", resident, #expected, launches, #controls)
end

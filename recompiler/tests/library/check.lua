local function segments(file)
    local list, current = {}, nil
    for line in os.iorunv("otool", {"-l", file}):gmatch("[^\n]+") do
        if line:match("^Load command") then
            current = nil
        elseif line:match("^%s+cmd LC_SEGMENT$") then
            current = {}
            table.insert(list, current)
        elseif current then
            current.name = current.name or line:match("^%s+segname (%S+)")
            current.address = current.address or tonumber(line:match("^%s+vmaddr 0x(%x+)") or "", 16)
            current.size = current.size or tonumber(line:match("^%s+vmsize 0x(%x+)") or "", 16)
        end
    end
    return list
end

local function exports(file)
    local list = {}
    for line in os.iorunv("nm", {"-gU", file}):gmatch("[^\n]+") do
        table.insert(list, line:match("(%S+)$"))
    end
    table.sort(list)
    return list
end

local EXPECTED = {"reserve", "load", "class", "create", "methods", "describe", "bundle", "bundle.path", "token", "completion", "completion.thread"}

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
    end
    if not names.__LINKEDIT or names.__LINKEDIT.address < 0x10000000 then
        corpus.fail("__LINKEDIT is not placed after the guest segments")
    end
    local symbols = exports(library)
    if table.concat(symbols, " ") ~= "_xl_library_diagnostics _xl_library_init" then
        corpus.fail("the library exports %s, not exactly its two entry points", table.concat(symbols, " "))
    end

    corpus.armv7(e, {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit",
                     path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("host")})
    corpus.sign(e, o("host"))
    if host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.run("mkdir -p /var/tmp/xl-library")
    device.copy(library, "/var/tmp/xl-library/RCFixture.dylib")
    device.copy(o("host"), "/var/tmp/xl-library/xl-library-host")
    local resident = os.getenv("XL_LIBRARY_RESIDENT_MB") or "85"
    local output = try { function ()
        return device.run("chmod +x /var/tmp/xl-library/xl-library-host && /var/tmp/xl-library/xl-library-host /var/tmp/xl-library/RCFixture.dylib " .. resident .. "; echo exit=$?")
    end } or ""
    device.run("rm -rf /var/tmp/xl-library")
    io.writefile(o("run.txt"), output)
    local text = "\n" .. output:gsub("\r", "")
    for _, name in ipairs(EXPECTED) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            io.write(output)
            corpus.fail("the host did not report ok for %s", name)
        end
    end
    if text:find("\nFAIL ", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
        io.write(output)
        corpus.fail("the host reported a failure or did not run to its end")
    end
    print("ok: a translated library loads into a %s MB host and answers (%d checks)", resident, #EXPECTED)
end

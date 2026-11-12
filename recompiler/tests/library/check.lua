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

local EXPECTED = {"reserve", "load", "class", "create", "methods", "string", "bundle", "bundle.path", "token", "completion", "completion.thread"}

function main(out, opt)
    opt = type(opt) == "table" and opt or {host_only = opt == "--host-only"}
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("library", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end

    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/RCFixture.dylib", "-framework", "Foundation", "-I", here,
                   path.join(here, "fixture.m"), "-o", o("RCFixture.dylib")})
    io.writefile(o("includes.h"), string.format('#include "%s"\n#include "%s"\n', path.join(e.recompiler, "include", "uikit-includes.h"), path.join(here, "RCFixture.h")))
    translate.translate(o("RCFixture.dylib"), o("includes.h"), o("xl"), {}, {XL_LIBRARY = "1"})
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
    if opt.host_only then
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

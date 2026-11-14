local STEPS = {
    {"stepDictionary", {"dictionary.string"}},
    {"stepDictionaryAny", {"dictionary.any"}},
    {"stepClosures", {"closures.array"}},
    {"stepNested", {"array.nested"}},
    {"stepSubstring", {"substring.split"}},
    {"stepStress", {"stress.append"}},
    {"stepProxyCount", {"proxy.count"}},
    {"stepProxyKind", {"proxy.kind"}},
    {"stepProxyDescription", {"proxy.description"}},
    {"stepProxyIdentity", {"proxy.identity"}},
    {"stepProxyNested", {"proxy.nested"}},
    {"stepProxyMutation", {"proxy.mutation"}},
    {"stepProxyAny", {"proxy.any"}},
    {"stepProxyLifetime", {"proxy.alive", "proxy.released"}},
    {"stepProxyUnique", {"proxy.unique.inplace", "proxy.unique.copied", "proxy.unique.values", "proxy.unique.balanced"}},
    {"stepProxyWeak", {"proxy.weak.alive", "proxy.weak.cleared", "proxy.weak.recreated", "proxy.weak.balanced"}},
    {"stepProxyRace", {"proxy.race", "proxy.race.balanced"}},
    {"stepProxyObject", {"proxy.object"}},
    {"stepProxyKeys", {"proxy.keys"}},
    {"stepProxyValues", {"proxy.values"}},
    {"stepProxyEnumerate", {"proxy.enumerate"}},
    {"stepHostCount", {"host.count"}},
    {"stepHostObject", {"host.object.found", "host.object.missing"}},
    {"stepHostKeyEnumerator", {"host.keyenumerator"}},
    {"stepHostAllKeys", {"host.allkeys"}},
    {"stepHostAllValues", {"host.allvalues"}},
    {"stepHostGetObjects", {"host.getobjects"}},
    {"stepHostFast", {"host.fastenumeration"}},
    {"stepHostEnumerate", {"host.enumerate"}},
    {"stepHostSequence", {"host.sequence.batch", "host.sequence.items", "host.sequence.mutations", "host.sequence.forin"}},
}
local CONTROLS = {"stepProxyKind", "stepProxyDescription", "stepProxyIdentity", "stepProxyNested", "stepProxyAny", "stepProxyLifetime", "stepProxyUnique", "stepProxyWeak"}

function main(out, ...)
    local host_only, device_only = false, false
    for _, argument in ipairs({...}) do
        if type(argument) == "table" then
            host_only = argument.host_only or host_only
            device_only = argument.device_only or device_only
        elseif argument == "--host-only" then
            host_only = true
        elseif argument == "--device-only" then
            device_only = true
        end
    end
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("libgenerics", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local libraries = o("xl/LibGenerics.dylib")

    if not device_only then
        local libs = os.getenv("XL_SWIFTOBJC_LIBS")
        if not libs or not os.isdir(libs) then
            raise("XL_SWIFTOBJC_LIBS must name the folder with libswiftCore.dylib (the arm64 runtime of revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
        end
        local swift, layouts = corpus.swift()
        os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                     "-runtime-compatibility-version", "none", "-emit-library", "-module-name", "LibGenerics",
                                                     "-Xlinker", "-install_name", "-Xlinker", "@rpath/LibGenerics.dylib", "-o", o("LibGenerics.dylib"),
                                                     path.join(here, "fixture.swift")})
        local includes = o("includes.h")
        io.writefile(includes, string.format('#include "%s"\n#include <Foundation/Foundation.h>\n', path.join(e.recompiler, "include", "swiftdemo-includes.h")))
        local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
        translate.translate(o("LibGenerics.dylib"), includes, o("xl"), images,
                            {XL_LIBRARY = "1", XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"})
        if not os.isfile(libraries) or not os.isfile(o("xl/LibGenerics-classes.dylib")) then
            corpus.fail("the library or its registry was not built")
        end
        local declared = false
        for _, line in ipairs(io.readfile(o("xl/report.txt")):split("\n", {plain = true})) do
            if line:find("getCharacters:range:]", 1, true) and line:find("host IMP from", 1, true) then
                if not line:find("host IMP from SDK declaration", 1, true) or not line:find("{_NSRange=II}", 1, true) then
                    corpus.fail("a host IMP of getCharacters:range: that Swift declares with {?=qq} is not the SDK's {_NSRange=II}: " .. line)
                end
                declared = true
            end
        end
        if not declared then
            corpus.fail("the report names no host IMP of getCharacters:range:")
        end
        local flags = {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit"}
        corpus.armv7(e, table.join(flags, {path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("host")}))
        corpus.sign(e, o("host"))
        if host_only then
            print("ok (host part)")
            return
        end
    elseif not os.isfile(libraries) then
        raise("--device-only needs the translated library %s of an earlier --host-only run", libraries)
    end

    local device = corpus.device()
    local remote = device.scratch .. "/xl-libgenerics"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(libraries, remote .. "/LibGenerics.dylib")
    device.copy(o("xl/LibGenerics-classes.dylib"), remote .. "/LibGenerics-classes.dylib")
    device.copy(o("host"), remote .. "/host")
    local log = {}
    for _, step in ipairs(STEPS) do
        local output = try { function ()
            return device.run("chmod +x " .. remote .. "/host && cd " .. remote .. " && MallocScribble=1 MallocGuardEdges=1 DYLD_FALLBACK_LIBRARY_PATH=" .. remote ..
                              " ./host " .. remote .. "/LibGenerics.dylib LibGenerics " .. step[1] .. " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, output)
        local text = "\n" .. output:gsub("\r", "")
        for _, name in ipairs(step[2]) do
            if not text:find("\nok " .. name .. "\n", 1, true) then
                io.write(output)
                corpus.fail("%s: the library did not report ok for %s", step[1], name)
            end
        end
        if text:find("\nFAIL ", 1, true) or text:find("malloc: ***", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
            io.write(output)
            corpus.fail("%s: the library reported a failure, the heap was corrupted, or the process did not run to its end", step[1])
        end
    end
    for _, step in ipairs(CONTROLS) do
        local control = try { function ()
            return device.run("cd " .. remote .. " && XL_PROXY=0 DYLD_FALLBACK_LIBRARY_PATH=" .. remote .. " ./host " .. remote .. "/LibGenerics.dylib LibGenerics " .. step ..
                              " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, control)
        if control:find("\ndone\nexit=0\n", 1, true) then
            io.write(control)
            corpus.fail("%s with XL_PROXY=0 ran to its end: the host reached an object of a generic class the guest allocated without a proxy and nothing failed", step)
        end
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), table.concat(log, "\n"))
    print("ok: %d steps of generic classes the Swift runtime instantiates at run time ran in a translated library", #STEPS)
end

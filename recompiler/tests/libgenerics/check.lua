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
    {"stepClassesOfHost", {"hostclass.guest.literal", "hostclass.guest.mutable", "hostclass.guest.copy", "hostclass.metatype.literal",
                         "hostclass.metatype.mutable", "hostclass.metatype.copy", "hostclass.conforms", "hostclass.superclass",
                         "hostclass.number", "hostclass.control", "generic.dyncast", "generic.superclass", "generic.subclass"}},
    {"stepSwiftObjectHash", {"swiftobject.hash"}},
    {"stepProxyHash", {"proxy.hash"}},
    {"stepPlainHash", {"plain.hash"}},
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
    {"stepShortString", {"short.string"}},
    {"stepDlsymFunction", {"dlsym.typeid", "dlsym.object"}},
    {"stepExtraInhabitants", {"xi.enum.generic", "xi.enum.inline", "xi.enum.word", "xi.enum.copies", "xi.enum.destroyed", "xi.enum.balance",
                              "xi.struct.generic", "xi.struct.inline", "xi.struct.copies", "xi.struct.destroyed", "xi.struct.balance",
                              "xi.struct.consumed", "xi.struct.released", "xi.enum.consumed", "xi.enum.released", "xi.class.released"}},
    {"stepExtraInhabitantsBig", {"xi.big.generic", "xi.big.inline", "xi.big.word", "xi.big.copies", "xi.big.balance"}},
    {"stepExtraInhabitantsStdlib", {"xi.stdlib.generic", "xi.stdlib.inline", "xi.stdlib.copies", "xi.stdlib.destroyed", "xi.stdlib.balance",
                                  "xi.stdlib.consumed", "xi.stdlib.released"}},
    {"stepHostSequence", {"host.sequence.batch", "host.sequence.items", "host.sequence.mutations", "host.sequence.forin"}},
}
local BARE_CONTROLS = {"stepShortString"}
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
        local empties = {}
        for index = 0, 4094 do
            table.insert(empties, "c" .. index)
        end
        io.writefile(o("xibig.swift"), table.concat({
            "import Foundation",
            "enum XiBig { case payload(XiRoot), " .. table.concat(empties, ", ") .. " }",
            "@inline(never) func xiBigName(_ value: XiBig?) -> Int {",
            "    switch value {",
            "    case .none: return -1",
            "    case .some(.payload): return -2",
            "    case .some(.c0): return 0",
            "    case .some(.c4094): return 4094",
            "    default: return -3",
            "    }",
            "}",
            "extension LibGenerics {",
            "    @objc public func stepExtraInhabitantsBig() {",
            "        xiDeinits = 0",
            "        do {",
            "            let root = XiRoot()",
            "            let first = xiMake(XiBig.c0, true)",
            "            let last = xiMake(XiBig.c4094, true)",
            "            let none = xiMake(XiBig.c0, false)",
            "            let payload = xiMake(XiBig.payload(root), true)",
            "            report(\"xi.big.generic\", xiIsSome(first) && xiIsSome(last) && xiIsSome(payload) && !xiIsSome(none))",
            "            report(\"xi.big.inline\", xiBigName(first) == 0 && xiBigName(last) == 4094 && xiBigName(payload) == -2 && xiBigName(none) == -1)",
            "            report(\"xi.big.word\", xiWord(first) == 0 && xiWord(last) == 4094 && xiWord(none) == 4095)",
            "            let kept = xiCopies(payload, 6) + xiCopies(last, 6) + xiCopies(none, 6)",
            "            report(\"xi.big.copies\", kept.count == 18 && xiDeinits == 0)",
            "            withExtendedLifetime(root) {}",
            "        }",
            "        report(\"xi.big.balance\", xiDeinits == 1)",
            "    }",
            "}",
            ""}, "\n"))
        os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                     "-runtime-compatibility-version", "none", "-emit-library", "-module-name", "LibGenerics",
                                                     "-Xlinker", "-install_name", "-Xlinker", "@rpath/LibGenerics.dylib", "-o", o("LibGenerics.dylib"),
                                                     path.join(here, "fixture.swift"), o("xibig.swift")})
        local includes = o("includes.h")
        io.writefile(includes, string.format('#include "%s"\n#include <Foundation/Foundation.h>\n', path.join(e.recompiler, "include", "swiftdemo-includes.h")))
        local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
        translate.translate(o("LibGenerics.dylib"), includes, o("xl"), images,
                            {XL_LIBRARY = "1", XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1",
                             XL_XI_EXCEPT = "Plain AnyHashable"})
        local touched = {}
        for _, line in ipairs(io.readfile(o("xl/report.txt")):split("\n", {plain = true})) do
            local site = line:match("^xi%-compare: (.*)$")
            if site then
                for _, name in ipairs({"XiBox", "Plain", "AnyHashable", "AncestorRepresentation", "SmallVectorBase"}) do
                    if site:find(name, 1, true) then
                        touched[name] = (touched[name] or 0) + 1
                    end
                end
            end
        end
        for _, name in ipairs({"XiBox", "AncestorRepresentation"}) do
            if not touched[name] then
                corpus.fail("the report of the translation names no compare with 4 GB rewritten in a witness of %s (xi-compare lines)", name)
            end
        end
        for _, name in ipairs({"Plain", "AnyHashable", "SmallVectorBase"}) do
            if touched[name] then
                corpus.fail("the lift rewrote %d compares of %s, which must keep the compiler's compare with 4 GB (the control, or an integer clamp)", touched[name], name)
            end
        end
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
        local loader = path.join(e.recompiler, "src", "loader", "xl_loader.c")
        local tagged = path.join(here, "..", "..", "..", "frameworks", "Backports", "src", "Foundation", "NSString+TaggedASCII.m")
        corpus.armv7(e, table.join(flags, {path.join(here, "host.m"), loader, tagged, "-o", o("host")}))
        corpus.sign(e, o("host"))
        corpus.armv7(e, table.join(flags, {path.join(here, "host.m"), loader, "-o", o("host_bare")}))
        corpus.sign(e, o("host_bare"))
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
    device.copy(o("host_bare"), remote .. "/host_bare")
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
    do
        local control = try { function ()
            return device.run("cd " .. remote .. " && DYLD_FALLBACK_LIBRARY_PATH=" .. remote .. " ./host " .. remote .. "/LibGenerics.dylib LibGenerics stepExtraInhabitantsControl 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, control)
        local text = "\n" .. control:gsub("\r", "")
        for _, name in ipairs({"xi.control.struct", "xi.control.enum", "xi.control.stdlib"}) do
            if not text:find("\nFAIL " .. name .. "\n", 1, true) then
                io.write(control)
                corpus.fail("%s on witnesses that keep the compiler's compare with 4 GB did not fail: the destroy of the optional released its class although the witness reads the pointer of the host as an extra inhabitant, so the rewrite is not what makes xi.struct.released and xi.stdlib.released work", name)
            end
        end
    end
    for _, step in ipairs(BARE_CONTROLS) do
        local control = try { function ()
            return device.run("chmod +x " .. remote .. "/host_bare && cd " .. remote .. " && DYLD_FALLBACK_LIBRARY_PATH=" .. remote .. " ./host_bare " .. remote ..
                              "/LibGenerics.dylib LibGenerics " .. step .. " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, control)
        if control:find("\nok short.string\n", 1, true) or control:find("\ndone\nexit=0\n", 1, true) then
            io.write(control)
            corpus.fail("%s on a host without NSString+TaggedASCII ran to its end: the host has the factory the Swift runtime sends for a short ASCII string, so the backport is not what makes it work", step)
        end
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), table.concat(log, "\n"))
    print("ok: %d steps of generic classes the Swift runtime instantiates at run time ran in a translated library", #STEPS)
end

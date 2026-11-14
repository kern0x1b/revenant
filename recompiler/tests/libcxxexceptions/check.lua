local STEPS = {
    {"stepValue", {"value.int", "value.pointer", "value.string", "value.fundamental", "value.struct", "value.reference",
                   "value.pointer.class", "value.exact"}},
    {"stepHierarchy", {"hier.base", "hier.middle", "hier.exact", "hier.sliced", "hier.multiple", "hier.multiple.first", "hier.virtual",
                       "hier.virtual.sibling", "hier.nomatch"}},
    {"stepStandard", {"std.what", "std.sibling", "std.out_of_range", "std.logic_error", "std.string.at", "std.bad_function_call",
                      "std.bad_cast", "std.typeid"}},
    {"stepNested", {"nested.other", "nested.rethrow", "nested.catchall.rethrow", "nested.inside.handler", "nested.uncaught"}},
    {"stepUnwind", {"unwind.value", "unwind.destructors", "unwind.order", "unwind.constructor", "unwind.copy.live", "unwind.copy.released",
                    "unwind.rethrow.live", "unwind.rethrow.released", "unwind.loop"}},
    {"stepPointer", {"ptr.current", "ptr.rethrow", "ptr.copy", "ptr.object", "ptr.released", "ptr.equal", "ptr.nested"}},
    {"stepForeign", {"foreign.standard", "foreign.integer", "foreign.objc", "foreign.rethrow", "foreign.pointer"}},
    {"stepRoundTrip", {"roundtrip.guest.host.guest", "roundtrip.standard"}},
    {"stepEscape", {}, "host.caught.other"},
    {"stepEscapeInteger", {}, "host.caught.int 42"},
    {"stepEscapeStandard", {}, "host.caught.other"},
}

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("libcxxexceptions", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end

    local libs = os.getenv("XL_CXX_LIBS") or corpus.libcxx_arm64()
    if not os.isfile(path.join(libs, "libc++.1.dylib")) or not os.isfile(path.join(libs, "libc++abi.1.dylib")) then
        raise("XL_CXX_LIBS names %s, which has no libc++.1.dylib and libc++abi.1.dylib", libs)
    end
    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-mno-outline", "-w", "-std=c++17", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/LibCxxExceptions.dylib",
                   "-framework", "Foundation", "-lc++", path.join(here, "fixture.mm"), "-o", o("LibCxxExceptions.dylib")})
    translate.translate(o("LibCxxExceptions.dylib"), path.join(here, "includes.h"), o("xl"),
                        {path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")},
                        {XL_LIBRARY = "1", XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib")})
    local library = o("xl/LibCxxExceptions.dylib")
    local registry = o("xl/LibCxxExceptions-classes.dylib")
    if not os.isfile(library) or not os.isfile(registry) then
        corpus.fail("the library or its registry was not built")
    end
    local report = io.readfile(o("xl/report.txt"))
    if report:find("___cxa_throw: UNSUPPORTED", 1, true) then
        corpus.fail("the translation leaves __cxa_throw as a fault: a C++ exception thrown by guest code is not implemented")
    end

    local flags = {"-O2", "-w", "-std=c++17", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit", "-lc++"}
    corpus.armv7(e, {"-O2", "-w", "-I", path.join(e.recompiler, "include"), "-c", path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("xl_loader.o")})
    corpus.armv7(e, table.join(flags, {path.join(here, "host.mm"), o("xl_loader.o"), "-o", o("host")}))
    corpus.sign(e, o("host"))
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/xl-libcxxexceptions"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(library, remote .. "/LibCxxExceptions.dylib")
    device.copy(registry, remote .. "/LibCxxExceptions-classes.dylib")
    device.copy(o("host"), remote .. "/host")
    local log, failures = {}, {}
    for _, step in ipairs(STEPS) do
        local output = try { function ()
            return device.run("chmod +x " .. remote .. "/host && cd " .. remote .. " && MallocScribble=1 MallocGuardEdges=1 DYLD_FALLBACK_LIBRARY_PATH=" .. remote ..
                              " ./host " .. remote .. "/LibCxxExceptions.dylib LibCxxExceptions " .. step[1] .. " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, output)
        local text = "\n" .. output:gsub("\r", "")
        local problem
        for _, name in ipairs(step[2]) do
            if not text:find("\nok " .. name .. "\n", 1, true) then
                problem = problem or string.format("%s: the library did not report ok for %s", step[1], name)
            end
        end
        if step[3] and not text:find("\n" .. step[3] .. "\n", 1, true) then
            problem = problem or string.format("%s: the host did not report %q", step[1], step[3])
        end
        if text:find("\nFAIL ", 1, true) or text:find("malloc: ***", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
            problem = problem or string.format("%s: the library reported a failure, the heap was corrupted, or the process did not run to its end", step[1])
        end
        if problem then
            io.write(output)
            table.insert(failures, problem)
        end
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), table.concat(log, "\n"))
    if #failures > 0 then
        corpus.fail("%s", table.concat(failures, "\n"))
    end
    print("ok: %d steps of C++ exceptions thrown and caught by guest code ran in a translated library", #STEPS)
end

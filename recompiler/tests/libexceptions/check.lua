local STEPS = {
    {"stepGuest", {"guest.throw", "guest.destructors", "guest.finally"}},
    {"stepHost", {"host.throw", "host.destructors", "host.finally"}},
    {"stepSubclass", {"subclass.throw", "subclass.finally"}},
    {"stepObject", {"object.throw", "object.finally"}},
    {"stepCatchAll", {"catchall.throw", "catchall.destructors", "catchall.none"}},
    {"stepFrame", {"frame.stack"}},
}

function main(out, opt)
    opt = type(opt) == "table" and opt or {}
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("libexceptions", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end

    corpus.ios(e, {"-fuse-ld=" .. e.ld, "-O2", "-w", "-fobjc-arc", "-dynamiclib", "-install_name", "@rpath/LibExceptions.dylib", "-framework", "Foundation", "-lc++",
                   path.join(here, "fixture.mm"), "-o", o("LibExceptions.dylib")})
    translate.translate(o("LibExceptions.dylib"), path.join(here, "includes.h"), o("xl"), {}, {XL_LIBRARY = "1"})
    local library = o("xl/LibExceptions.dylib")
    local registry = o("xl/LibExceptions-classes.dylib")
    if not os.isfile(library) or not os.isfile(registry) then
        corpus.fail("the library or its registry was not built")
    end
    local imports = os.iorunv("nm", {"-u", library})
    if not imports:find("_Unwind_SjLj_Register", 1, true) then
        corpus.fail("the translated library does not register SjLj frames")
    end

    local flags = {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-framework", "Foundation", "-framework", "UIKit"}
    corpus.armv7(e, table.join(flags, {path.join(here, "host.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("host")}))
    corpus.sign(e, o("host"))
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = "/var/tmp/xl-libexceptions"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(library, remote .. "/LibExceptions.dylib")
    device.copy(registry, remote .. "/LibExceptions-classes.dylib")
    device.copy(o("host"), remote .. "/host")
    local log = {}
    for _, step in ipairs(STEPS) do
        local output = try { function ()
            return device.run("chmod +x " .. remote .. "/host && cd " .. remote .. " && DYLD_FALLBACK_LIBRARY_PATH=" .. remote .. " ./host " .. remote ..
                              "/LibExceptions.dylib LibExceptions " .. step[1] .. " 2>&1; echo exit=$?")
        end } or ""
        table.insert(log, output)
        local text = "\n" .. output:gsub("\r", "")
        for _, name in ipairs(step[2]) do
            if not text:find("\nok " .. name .. "\n", 1, true) then
                io.write(output)
                corpus.fail("%s: the library did not report ok for %s", step[1], name)
            end
        end
        if text:find("\nFAIL ", 1, true) or not text:find("\ndone\nexit=0\n", 1, true) then
            io.write(output)
            corpus.fail("%s: the library reported a failure or the process did not run to its end", step[1])
        end
    end
    device.run("rm -rf " .. remote)
    io.writefile(o("run.txt"), table.concat(log, "\n"))
    print("ok: %d steps of Objective-C exceptions, C++ cleanups and a large stack frame ran in a translated library", #STEPS)
end

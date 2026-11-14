function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("exceptions", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local expected = path.join(here, "..", "data", "exceptions", "expected.txt")
    local sources = {path.join(here, "main.m"), path.join(here, "guarded.mm")}
    local libraries = {"-framework", "Foundation", "-lc++"}

    os.execv("xcrun", table.join({"clang", "-arch", "arm64", "-O2", "-w"}, sources, libraries, {"-o", o("Exceptions-mac")}))
    os.execv(o("Exceptions-mac"), {}, {stdout = o("run-mac.txt")})
    corpus.same(expected, o("run-mac.txt"), "the Objective-C runtime on this Mac prints something else than expected.txt")

    corpus.ios(e, table.join({"-fuse-ld=" .. e.ld, "-O2", "-w", "-D_FORTIFY_SOURCE=0"}, sources, libraries, {"-o", o("Exceptions-arm64")}))
    translate.translate(o("Exceptions-arm64"), path.join(here, "includes.h"), o("xl"))

    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("probe.bc"), "--ir", o("probe.ll"), "--bridge", o("xl/libxl-guest.dylib"),
                                         "--passthrough", o("xl/passthrough.txt"), o("Exceptions-arm64"), o("xl/libxl-guest.dylib")}, o("xlate.log"))
    if not ok then
        corpus.fail("xlate failed:\n%s", log)
    end
    local calls, functions, pads = log:match("xlate: (%d+) call sites in (%d+) functions unwind to (%d+) landing pads")
    if not calls or tonumber(calls) < 20 or tonumber(pads) < 6 then
        corpus.fail("expected at least 20 call sites unwinding to 6 landing pads, xlate says:\n%s", log)
    end
    if log:find("left as plain calls", 1, true) or log:find("LSDA", 1, true) then
        corpus.fail("xlate left exception edges out:\n%s", log)
    end
    local ir = io.readfile(o("probe.ll"))
    for _, needle in ipairs({"invoke ", "landingpad", "__objc_personality_v0", "__gxx_personality_sj0"}) do
        if not ir:find(needle, 1, true) then
            corpus.fail("the lifted module has no %s", needle)
        end
    end
    if not os.iorunv("nm", {"-u", o("xl/Exceptions")}):find("_Unwind_SjLj_Register", 1, true) then
        corpus.fail("the translated program does not register SjLj frames")
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/Exceptions"
    device.copy(o("xl/Exceptions"), remote)
    io.writefile(o("run.txt"), device.run(string.format("chmod +x %s && %s 2>/dev/null; rm -f %s", remote, remote, remote)))
    corpus.same(expected, o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end

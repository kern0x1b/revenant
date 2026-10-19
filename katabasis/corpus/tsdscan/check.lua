function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "scripts"), anonymous = true})
    local e
    e, out = corpus.setup("tsdscan", out)
    local here = os.scriptdir()
    for _, name in ipairs({"good", "bad", "good.log", "bad.log", "good.json", "bad.json"}) do
        os.tryrm(path.join(out, name))
    end
    os.execv("xcrun", {"clang", "-arch", "arm64", "-O2", "-w", "-DTSD_OFFSET=0x358", path.join(here, "main.c"), "-o", path.join(out, "good")})
    os.execv("xcrun", {"clang", "-arch", "arm64", "-O2", "-w", "-DTSD_OFFSET=0x40", path.join(here, "main.c"), "-o", path.join(out, "bad")})

    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--objc-manifest", path.join(out, "good.json"), path.join(out, "good")}, path.join(out, "good.log"))
    if not ok then
        io.write(log)
        corpus.fail("xlate refused the one audited offset (0x358)")
    end
    ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--objc-manifest", path.join(out, "bad.json"), path.join(out, "bad")}, path.join(out, "bad.log"))
    if ok then
        io.write(log)
        corpus.fail("xlate accepted an unaudited TPIDRRO_EL0 offset (0x40)")
    end
    if not log:find("not on the audited allow-list", 1, true) then
        io.write(log)
        corpus.fail("xlate refused main for a different reason")
    end
    if not log:find("0x40", 1, true) then
        io.write(log)
        corpus.fail("the refusal did not name the offset")
    end
    for _, fn in ipairs({"read_tsd_slot", "dead_path_clobber", "callee_reads_tsd"}) do
        if not log:find(fn, 1, true) then
            io.write(log)
            corpus.fail("the refusal did not name %s, so this shape of access is not caught", fn)
        end
    end
    print("ok")
end

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local e
    e, out = corpus.setup("jumptable", out)
    local here = os.scriptdir()
    local binary = path.join(out, "jumptable-arm64")
    corpus.ios(e, {"-O2", "-w", "-o", binary, path.join(here, "main.c"), path.join(here, "dispatch.s")})
    io.writefile(path.join(out, "passthrough.txt"), "")
    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", path.join(out, "out.bc"), "--layout", path.join(out, "layout.txt"),
                                         "--state-header", path.join(out, "xl_state.h"), "--passthrough", path.join(out, "passthrough.txt"), binary},
                               path.join(out, "xlate.log"))
    io.write(log)
    if not ok then
        corpus.fail("xlate failed on %s", binary)
    end
    if not log:find(", 4 jump table targets,", 1, true) then
        corpus.fail("xlate did not report finding all 4 case bodies past the gap (see %s)", path.join(out, "xlate.log"))
    end
    print("ok")
end

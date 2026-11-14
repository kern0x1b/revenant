function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("flagflow", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    io.writefile(o("passthrough.txt"), "")

    local function build(name, source, flags)
        local library = o(name .. ".dylib")
        corpus.ios(e, table.join({"-fuse-ld=" .. e.ld, "-w", "-dynamiclib", "-install_name", "@rpath/" .. name .. ".dylib"}, flags or {},
                                 {path.join(here, source), "-o", library}))
        return library
    end

    local function lift(name, library)
        return corpus.run(e.xlate, {"--base", "0x10000000", "--output", o(name .. ".bc"), "--layout", o(name .. ".layout"), "--passthrough", o("passthrough.txt"),
                                    "--state-header", o(name .. ".h"), "--library", "--flag-flow-summary", o(name .. ".summary"), library}, o(name .. ".log"))
    end

    local function refused(name, source, flags, needles)
        local ok, log = lift(name, build(name, source, flags))
        if ok then
            corpus.fail("%s: a translation that passes the condition flags across a call was not refused", name)
        end
        for _, needle in ipairs(needles) do
            if not log:find(needle, 1, true) then
                corpus.fail("%s: the error does not say %q:\n%s", name, needle, log)
            end
        end
        if not log:find("pass the condition flags across a call", 1, true) then
            corpus.fail("%s: the error does not end with the explanation:\n%s", name, log)
        end
    end

    refused("direct", "direct.S", nil, {"error: ", "function 0x", " calls 0x", "and reads the flags (csinc/cset) after the call returns"})
    refused("indirect", "indirect.S", nil, {"calls through a register at 0x", "and reads the flags (csinc/cset) after the call returns"})
    refused("entry", "entry.S", nil, {"reads the flags (csinc/cset) on entry"})
    refused("outlined", "notes.c", {"-Oz"}, {"error: ", "reads the flags (b.cond) after the call returns"})

    for _, name in ipairs({"clean", "plain"}) do
        local library = name == "clean" and build(name, "clean.S") or build(name, "notes.c", {"-Oz", "-mno-outline"})
        local ok, log = lift(name, library)
        if not ok then
            corpus.fail("%s: a translation with no flags across a call was refused:\n%s", name, log)
        end
        local summary = io.readfile(o(name .. ".summary"))
        if not summary:find("0 calls that pass the flags", 1, true) then
            corpus.fail("%s: the summary does not say that no call passes the flags:\n%s", name, summary)
        end
        if name == "clean" and not summary:find("1 reads after a call that never returns ignored", 1, true) then
            corpus.fail("clean: the read of the flags after a call to a function that never returns was not ignored once:\n%s", summary)
        end
    end
    print("ok: a call that passes the condition flags (a direct, an indirect or an entry read, and the outlined function of Apple clang -Oz) stops the translation; the same code without flags across calls and the read after a call that never returns are translated")
end

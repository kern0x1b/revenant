function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("outliner", out)
    local clang = path.join(e.llvmbin, "clang")
    local version = os.iorunv(clang, {"--version"}):match("[^\n]+")
    local asm = os.iorunv(clang, {"-x", "ir", "-target", "armv7-apple-ios6.0", "-mthumb", "-O2", "-w", "-mllvm", "-enable-machine-outliner=always", "-S",
                                  path.join(os.scriptdir(), "repro.ll"), "-o", "-"})
    io.writefile(path.join(out, "repro.s"), asm)

    local sites, unbalanced, pushed = 0, 0, nil
    for line in asm:gmatch("[^\n]+") do
        local push = line:match("^%s+str%S*%s+lr, %[sp, #%-(%d+)%]!")
        if push then
            pushed = tonumber(push)
        else
            local pop = line:match("^%s+ldr%S*%s+lr, %[sp%], #(%d+)")
            if pop and pushed then
                sites = sites + 1
                if tonumber(pop) ~= pushed then
                    unbalanced = unbalanced + 1
                end
                pushed = nil
            end
        end
    end
    if sites == 0 then
        corpus.fail("the outliner made no call that saves lr on the stack, so repro.ll no longer shows the case; %s", version)
    end
    if unbalanced > 0 then
        print("%s: the outliner still moves sp by a different amount when it saves and when it restores lr (%d of %d calls); the lifted code stays out of the outliner", version,
              unbalanced, sites)
    else
        print("%s: the outliner saves and restores lr by the same amount in all %d calls; try it again: compile the lifted code with -mllvm -enable-machine-outliner=always and run hostbridges and libexceptions on the phone", version, sites)
    end
end

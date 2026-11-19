local LINES = {"pairs.bare", "pairs.add with 1 threads", "pairs.cas with 1 threads", "pairs.add32 with 1 threads", "pairs.add with 2 threads", "pairs.cas with 2 threads", "pairs.add32 with 2 threads", "pairs.swap with 2 threads",
               "pairs.torn with 2 threads", "pairs.add with 4 threads", "pairs.cas with 4 threads", "pairs.add32 with 4 threads",
               "pairs.swap with 4 threads", "pairs.torn with 4 threads"}
local MONITOR = {"pairs.elsewhere", "pairs.after-single", "pairs.single-after", "pairs.twice"}
local WORKERS = {"pair_add", "pair_cas", "pair_swap", "pair_store", "pair_torn", "pair32_add", "pair_bare", "pair_elsewhere", "pair_after_single",
                 "single_after_pair", "pair_twice"}

local function functions(listing)
    local bodies, current = {}, nil
    for line in (listing .. "\n"):gmatch("([^\n]*)\n") do
        local label = line:match("^(_[%w_]+):$")
        if label then
            current = label
            bodies[current] = {}
        elseif current then
            table.insert(bodies[current], line)
        end
    end
    return bodies
end

local function lifted(ir, guest)
    local start = ir:find("\ndefine [^\n]*@sub_" .. guest .. "%(")
    if not start then
        return nil
    end
    local stop = ir:find("\n}\n", start, true)
    return ir:sub(start, stop)
end

local function count(text, pattern)
    local _, found = text:gsub(pattern, "")
    return found
end

local function verify(corpus, text, where, names)
    text = "\n" .. text:gsub("\r", "")
    for _, name in ipairs(names) do
        if not text:find("\nok " .. name, 1, true) then
            io.write(text)
            corpus.fail("%s did not report ok for %s", where, name)
        end
    end
    if text:find("\nFAIL ", 1, true) or not text:find("\ndone\n", 1, true) then
        io.write(text)
        corpus.fail("%s reported a failure or did not run to its end", where)
    end
end

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local options = corpus.options(...)
    local e
    e, out = corpus.setup("llscpair", out)
    local function o(file)
        return path.join(out, file)
    end
    local source = path.join(os.scriptdir(), "main.c")
    local runtime = path.join(e.root, "recompiler", "src", "runtime")
    local program, binary = o("llscpair"), o("llscpair-workers-arm64")
    if not options.device_only then
        for _, name in ipairs({"llscpair", "llscpair-workers-arm64", "llscpair-mac", "out.bc", "out.ll", "xlate.log", "coverage.log", "coverage.txt", "lifted-host.o",
                               "lifted-armv7.o", "pair-armv7.o", "lifted", "lifted-control-1", "lifted-control-2", "out-host.bc"}) do
            os.tryrm(o(name))
        end
        os.execv("cc", {"-O2", "-march=armv8-a", "-w", source, "-o", o("llscpair-mac")})
        local native = os.iorunv(o("llscpair-mac"), {})
        verify(corpus, native, "the program on this Mac", LINES)
        print("ok: on the processor of this Mac no update of a pair is lost and no pair is read torn (%d scenarios)", #LINES)

        corpus.ios(e, {"-march=armv8-a", "-O2", "-w", "-fno-stack-protector", "-D_FORTIFY_SOURCE=0", "-o", program, source})
        corpus.ios(e, {"-march=armv8-a", "-O2", "-w", "-DWORKERS_ALONE", "-o", binary, path.join(os.scriptdir(), "workers.c")})
        local disassembly = functions(os.iorunv("xcrun", {"otool", "-tV", binary}))
        local cases = {}
        for line in os.iorunv("xcrun", {"nm", binary}):gmatch("[^\n]+") do
            local address, symbol = line:match("^(%x+) [Tt] _([%w_]+)$")
            if symbol and table.contains(WORKERS, symbol) then
                local case = {symbol = symbol, guest = format("%x", tonumber(address, 16) - 0x100000000 + 0x10000000), loads = 0, stores = 0, narrow = 0, single = 0, single_stores = 0}
                for _, line in ipairs(disassembly["_" .. symbol] or {}) do
                    local mnemonic, operands = line:match("^%x+\t(%a+)\t(.*)$")
                    if mnemonic == "ldxp" or mnemonic == "ldaxp" then
                        case.loads = case.loads + 1
                        case.narrow = case.narrow + (operands:find("^w") and 1 or 0)
                    elseif mnemonic == "stxp" or mnemonic == "stlxp" then
                        case.stores = case.stores + 1
                    elseif mnemonic == "ldxr" then
                        case.single = case.single + 1
                    elseif mnemonic == "stxr" then
                        case.single_stores = case.single_stores + 1
                    end
                end
                cases[symbol] = case
            end
        end
        for _, symbol in ipairs(WORKERS) do
            local case = cases[symbol]
            if not case or case.stores + case.single_stores == 0 or (case.loads == 0 and symbol ~= "pair_bare" and symbol ~= "pair_after_single") then
                corpus.fail("%s does not carry a load-pair and a store-pair: clang did not emit the exclusive pair loop this case is for", symbol)
            end
        end
        if cases.pair32_add.narrow ~= 1 then
            corpus.fail("pair32_add does not carry the 32-bit form of the load-pair")
        end

        io.writefile(o("passthrough.txt"), "")
        local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--coverage", o("coverage.txt"), binary}, o("coverage.log"))
        if not ok or not log:find("coverage: 0 of ", 1, true) then
            io.write(log)
            corpus.fail("xlate left an instruction of %s unlifted (see %s)", binary, o("coverage.txt"))
        end
        ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("out.bc"), "--layout", o("layout.txt"),
                                       "--state-header", o("xl_state.h"), "--passthrough", o("passthrough.txt"), binary}, o("xlate.log"))
        if not ok or not log:find(", 0 failures", 1, true) then
            io.write(log)
            corpus.fail("xlate did not lift every function of %s (see %s)", binary, o("xlate.log"))
        end
        local declarations = {}
        for _, symbol in ipairs(WORKERS) do
            table.insert(declarations, format("void sub_%s(void *state);", cases[symbol].guest))
            table.insert(declarations, format("#define SUB_%s sub_%s", symbol, cases[symbol].guest))
        end
        io.writefile(o("lifted.h"), table.concat(declarations, "\n") .. "\n")
        ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--host-triple", "arm64-apple-macos", "--host-datalayout", "e-m:o-i64:64-i128:128-n32:64-S128-Fn32",
                                       "--output", o("out-host.bc"), "--layout", o("layout-host.txt"), "--state-header", o("xl_state_host.h"),
                                       "--passthrough", o("passthrough.txt"), binary}, o("xlate-host.log"))
        if not ok or not log:find(", 0 failures", 1, true) or io.readfile(o("xl_state_host.h")) ~= io.readfile(o("xl_state.h")) then
            io.write(log)
            corpus.fail("xlate did not lift %s a second time with the pointers of this Mac, or laid the state out differently (see %s)", binary, o("xlate-host.log"))
        end
        os.execv(path.join(e.llvmbin, "clang"), {"-target", "arm64-apple-macos", "-Wno-override-module", "-O2", "-c", o("out-host.bc"), "-o", o("lifted-host.o")})
        local driver = {"-O2", "-w", "-I", out, path.join(os.scriptdir(), "lifted.c"), o("lifted-host.o")}
        os.execv("cc", table.join(driver, {path.join(runtime, "pair.c"), "-o", o("lifted")}))
        local ran, result = corpus.run(o("lifted"), {}, o("lifted.txt"))
        io.write(result)
        if not ran then
            corpus.fail("the lifted functions, run on this Mac by two and by four threads, lost updates of a pair or read a pair torn")
        end
        verify(corpus, result, "the lifted functions on this Mac", table.join(LINES, MONITOR))
        local stored, failed = result:match("xlate: pair stores: (%d+) stored and (%d+) failed since the start")
        if not stored or tonumber(stored) < 4000000 or tonumber(failed) == 0 then
            corpus.fail("the run does not report its pair stores, or reports none that failed: two threads never met on a pair, so it proved nothing")
        end
        print("ok: the lifted functions, run on this Mac by two and by four threads, lost no update of a pair and read no pair torn; %s pair stores stored and %s found the pair changed", stored, failed)

        for control, wanted in ipairs({{"FAIL pairs.add with 2 threads", "FAIL pairs.cas with 4 threads"}, {"FAIL pairs.add with 4 threads"}}) do
            local name = "lifted-control-" .. control
            os.execv("cc", table.join(driver, {"-DCONTROL=" .. control, path.join(os.scriptdir(), "control.c"), "-o", o(name)}))
            local passed, text = corpus.run(o(name), {}, o(name .. ".txt"))
            for _, line in ipairs(wanted) do
                if passed or not text:find("\n" .. line, 1, true) then
                    io.write(text)
                    corpus.fail("the control %d (%s) did not fail with %s", control, control == 1 and "a pair store that does not compare" or "a pair store that compares and stores without the lock", line)
                end
            end
        end
        print("ok: the controls with a pair store that does not compare, and with one that compares and stores without the lock, lost updates")

        local held, report = corpus.run(o("lifted"), {"--fault"}, o("fault.txt"))
        if not held or not report:find("xlate: pair stores: 0 stored and 0 failed since the start", 1, true) or not report:find("; 1 of 64 locks held now\n", 1, true) then
            io.write(report)
            corpus.fail("a pair store that faulted inside its lock did not leave a handler able to report the pair stores with the lock held")
        end
        print("ok: a pair store that faults with its lock held leaves the signal handler able to report: %s", report:match("xlate: pair stores: [^\n]*"))

        local state = io.readfile(o("xl_state.h"))
        for _, slot in ipairs({"EXCL_ADDR", "EXCL_VAL", "EXCL_VAL2"}) do
            if not state:find("#define XL_OFFSET_" .. slot .. " ", 1, true) then
                corpus.fail("%s does not export the exclusive monitor slot %s", o("xl_state.h"), slot)
            end
        end
        os.execv(path.join(e.llvmbin, "llvm-dis"), {o("out.bc"), "-o", o("out.ll")})
        local ir = io.readfile(o("out.ll"))
        for _, symbol in ipairs(WORKERS) do
            local case = cases[symbol]
            local body = lifted(ir, case.guest)
            if not body then
                corpus.fail("no lifted function sub_%s for %s", case.guest, symbol)
            end
            local calls = count(body, "call i32 @rellume_aarch64_stxp%(")
            local loads = count(body, "load atomic i64, ptr [^,]+ %a+, align 8%f[^%d]")
            local exchanges = count(body, "cmpxchg ptr [^,]+, i64 ")
            local wide_stores = case.stores - case.narrow
            local wide_loads = 2 * (case.loads - case.narrow) + case.narrow + case.single
            local narrow_stores = case.narrow + case.single_stores
            if calls ~= wide_stores or loads ~= wide_loads or exchanges ~= narrow_stores then
                io.write(body, "\n")
                corpus.fail("%s (sub_%s) is not lifted to %d atomic loads, %d calls of the pair store and %d cmpxchg: it has %d, %d and %d", symbol, case.guest,
                            wide_loads, wide_stores, narrow_stores, loads, calls, exchanges)
            end
        end
        print("ok: %d functions, each load-pair lifted to two atomic loads into the monitor and each store-pair to one call of the pair store; the 32-bit pair is one 64-bit exclusive", #WORKERS)

        local clang = path.join(e.llvmbin, "clang")
        os.execv(clang, {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-w", "-c", o("out.bc"), "-o", o("lifted-armv7.o")})
        os.execv(clang, {"-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-O2", "-I", runtime, "-c", path.join(runtime, "pair.c"), "-o", o("pair-armv7.o")})
        local undefined = os.iorunv("xcrun", {"nm", "-u", o("lifted-armv7.o")})
        if not undefined:find("_rellume_aarch64_stxp\n", 1, true) or undefined:find("atomic", 1, true) or undefined:find("sync_", 1, true) then
            io.write(undefined)
            corpus.fail("the lifted code compiled for armv7 needs a library call for an atomic, which iOS 6 does not have, or does not call the pair store")
        end
        local called = os.iorunv("xcrun", {"nm", "-u", o("pair-armv7.o")}):trim()
        if called ~= "_thread_switch" then
            print(called)
            corpus.fail("the pair store calls something else than thread_switch, which it calls while it waits and holds nothing: a call inside the lock could keep it held, and a library call for an atomic does not exist on iOS 6")
        end
        local armv7 = os.iorunv("xcrun", {"otool", "-tV", o("pair-armv7.o")})
        if not armv7:find("\tldrex\t", 1, true) or not armv7:find("\tstrex\t", 1, true) then
            corpus.fail("the pair store compiled for armv7 does not take its lock with ldrex and strex")
        end
        print("ok: for armv7 the lifted code calls the pair store, whose lock is an inline ldrex and strex, and nothing asks for an atomic library call")
        translate.translate(program, path.join(e.recompiler, "include", "common-includes.h"), o("xl"))
    end
    if options.host_only then
        print("ok (host part)")
        return
    end
    local device = corpus.device()
    local remote = device.scratch .. "/xl-llscpair"
    device.copy(o("xl/llscpair"), remote)
    local output = try { function ()
        return device.run(string.format("sysctl -n hw.ncpu; chmod +x %s && %s; echo exit=$?; rm -f %s", remote, remote, remote))
    end } or ""
    io.writefile(o("run.txt"), output)
    io.write(output)
    verify(corpus, output, "the translated program", LINES)
    if not output:find("exit=0", 1, true) then
        corpus.fail("the translated program did not exit with 0")
    end
    print("ok: the translated program, on the %s processors of the device, lost no update of a pair and read no pair torn (%d scenarios)", output:match("^(%d+)") or "?", #LINES)
end

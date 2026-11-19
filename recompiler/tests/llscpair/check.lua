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

local function said(text, name)
    for line in text:gmatch("[^\r\n]+") do
        local rest = line:match("^%a+ (.*)$")
        if rest and rest:sub(1, #name + 1) == name .. ":" then
            return line
        end
    end
end

local function verify(corpus, text, where, names, ended)
    local wrong, apart = {}, {}
    for _, name in ipairs(names) do
        local line = said(text, name)
        if not line then
            table.insert(wrong, "no line for " .. name)
        elseif line:find("^APART ") then
            table.insert(apart, line)
        elseif not line:find("^ok ") then
            table.insert(wrong, line)
        end
    end
    if #wrong > 0 then
        io.write(text)
        corpus.fail("%s, which ended with %s: %s", where, ended, table.concat(wrong, "; "))
    end
    if #apart > 0 then
        io.write(text)
        corpus.fail("%s proved nothing in %d scenarios, whose threads never worked at the same time (a processor too busy, not a lost update): %s", where, #apart,
                    table.concat(apart, "; "))
    end
    text = "\n" .. text:gsub("\r", "")
    if text:find("\nFAIL ", 1, true) or not text:find("\ndone\n", 1, true) then
        io.write(text)
        corpus.fail("%s ended with %s and without its last line; the last it wrote is [%s]", where, ended, text:match("\n(FAIL [^\n]*)") or text:trim():match("[^\n]*$"))
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
                               "lifted-armv7.o", "pair-armv7.o", "lifted", "lifted-control-1", "lifted-control-2", "lifted-control-3", "out-host.bc"}) do
            os.tryrm(o(name))
        end
        os.execv("cc", {"-O2", "-march=armv8-a", "-w", source, "-o", o("llscpair-mac")})
        local _, native, left = corpus.run(o("llscpair-mac"), {}, o("native.txt"))
        verify(corpus, native, "the program on this Mac", LINES, left)
        print("ok: on the processor of this Mac no update of a pair is lost and no pair is read torn (%d scenarios)", #LINES)

        corpus.ios(e, {"-march=armv8-a", "-O2", "-w", "-fno-stack-protector", "-D_FORTIFY_SOURCE=0", "-o", program, source})
        corpus.ios(e, {"-march=armv8-a", "-O2", "-w", "-DWORKERS_ALONE", "-o", binary, path.join(os.scriptdir(), "workers.c")})
        local disassembly = functions(corpus.output("xcrun", {"otool", "-tV", binary}, o("otool-workers.txt")))
        local cases = {}
        for line in corpus.output("xcrun", {"nm", binary}, o("nm-workers.txt")):gmatch("[^\n]+") do
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
        local _, result, finished = corpus.run(o("lifted"), {}, o("lifted.txt"))
        verify(corpus, result, "the lifted functions on this Mac", table.join(LINES, MONITOR), finished)
        io.write(result)
        local stored, failed = result:match("xlate: pair stores: (%d+) stored and (%d+) failed since the start")
        if not stored or tonumber(stored) < 4000000 or tonumber(failed) == 0 then
            corpus.fail("the run does not report its pair stores, or reports none that failed: two threads never met on a pair, so it proved nothing")
        end
        print("ok: the lifted functions, run on this Mac by two and by four threads, lost no update of a pair and read no pair torn; %s pair stores stored and %s found the pair changed", stored, failed)

        for control, wanted in ipairs({{"pairs.add with 2 threads", "pairs.cas with 4 threads"}, {"pairs.add with 4 threads"}}) do
            local name = "lifted-control-" .. control
            os.execv("cc", table.join(driver, {"-DCONTROL=" .. control, path.join(os.scriptdir(), "control.c"), "-o", o(name)}))
            local passed, text, left = corpus.run(o(name), {}, o(name .. ".txt"))
            for _, scenario in ipairs(wanted) do
                local line = said(text, scenario)
                if passed or not line or not line:find("^FAIL ") then
                    io.write(text)
                    corpus.fail("the control %d (%s) lost nothing in %s: it ended with %s and wrote [%s]", control,
                                control == 1 and "a pair store that does not compare" or "a pair store that compares and stores without the lock", scenario, left,
                                line or "no line for it")
                end
            end
        end
        print("ok: the controls with a pair store that does not compare, and with one that compares and stores without the lock, lost updates")

        local function ended(program, asked)
            return os.iorunv("sh", {"-c", string.format("'%s' %s 2>&1; echo exit=$?", program, asked)})
        end
        local processor = ended(o("llscpair-mac"), "--overlap")
        if not processor:find("exit=138", 1, true) or processor:find("pairs.overlap", 1, true) then
            io.write(processor)
            corpus.fail("the processor of this Mac did not answer a 64-bit pair at 8 mod 16 with an alignment fault: the rule the pair store enforces is not the processor's")
        end
        local stopped = ended(o("lifted"), "--overlap")
        if not stopped:find("xlate: a store%-pair at 0x%x+ is not aligned to 16 bytes") or not stopped:find("exit=134", 1, true) or stopped:find("pairs.overlap", 1, true) then
            io.write(stopped)
            corpus.fail("two 64-bit pairs that share a word, which arm64 answers with an alignment fault, did not stop the lifted run at the first store")
        end
        os.execv("cc", table.join(driver, {"-DCONTROL=3", path.join(os.scriptdir(), "control.c"), "-o", o("lifted-control-3")}))
        local shared = ended(o("lifted-control-3"), "--overlap")
        local overlap = said(shared, "pairs.overlap with 2 threads")
        if not overlap or not overlap:find("^FAIL ") then
            io.write(shared)
            corpus.fail("the control 3 (a lock for each 16 bytes and no look at the alignment) lost no update of the word two pairs share: it wrote [%s]",
                        overlap or shared:trim())
        end
        for _, program in ipairs({o("llscpair-mac"), o("lifted")}) do
            local narrow = ended(program, "--overlap32")
            if narrow:find("FAIL", 1, true) or not (narrow:find("ok pairs.overlap32", 1, true) or narrow:find("exit=138", 1, true)) then
                io.write(narrow)
                corpus.fail("two 32-bit pairs that share a word did not keep every update in %s, where such a pair is one exclusive of 64 bits, which stores whole or faults: it wrote [%s]",
                            program, said(narrow, "pairs.overlap32 with 2 threads") or narrow:trim())
            end
        end
        print("ok: two 64-bit pairs that share a word fault on this processor and stop the lifted run (%s); the control with a lock for each 16 bytes loses updates; two 32-bit pairs that share a word lose none",
              stopped:match("xlate: a store%-pair[^\n]*"))

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
        local undefined = corpus.output("xcrun", {"nm", "-u", o("lifted-armv7.o")}, o("nm-lifted-armv7.txt"))
        if not undefined:find("_rellume_aarch64_stxp\n", 1, true) or undefined:find("atomic", 1, true) or undefined:find("sync_", 1, true) then
            io.write(undefined)
            corpus.fail("the lifted code compiled for armv7 needs a library call for an atomic, which iOS 6 does not have, or does not call the pair store")
        end
        local called = corpus.output("xcrun", {"nm", "-u", o("pair-armv7.o")}, o("nm-pair-armv7.txt")):trim():gsub("%s+", " ")
        if called ~= "_abort _thread_switch _write" then
            print(called)
            corpus.fail("the pair store imports something else than thread_switch and the write and abort of its refusal: a library call for an atomic does not exist on iOS 6")
        end
        local armv7 = corpus.output("xcrun", {"otool", "-tV", o("pair-armv7.o")}, o("otool-pair-armv7.txt"))
        if not armv7:find("\tldrex\t", 1, true) or not armv7:find("\tstrex\t", 1, true) then
            corpus.fail("the pair store compiled for armv7 does not take its lock with ldrex and strex")
        end
        local starts, waits, refusals = {}, 0, 0
        for line in corpus.output("xcrun", {"nm", "-n", o("pair-armv7.o")}, o("nm-pair-sorted.txt")):gmatch("[^\n]+") do
            local address, symbol = line:match("^(%x+) [Tt] (_[%w_]+)$")
            if address then
                table.insert(starts, {tonumber(address, 16), symbol})
            end
        end
        local function inside(address)
            local found
            for _, start in ipairs(starts) do
                if start[1] <= address then
                    found = start[2]
                end
            end
            return found
        end
        for line in corpus.output("xcrun", {"otool", "-rv", o("pair-armv7.o")}, o("otool-pair-relocations.txt")):gmatch("[^\n]+") do
            local address, extern, target = line:match("^(%x+) True%s+long%s+(%a+)%s+T_BR%d+%s+False%s+(.+)$")
            if address then
                local caller = inside(tonumber(address, 16))
                local callee = extern == "True" and target or (armv7:match("\n" .. address .. "\t[%x ]+\tblx?\t(_[%w_]+)") or "?")
                if caller == "_rellume_aarch64_stxp" and callee == "_thread_switch" then
                    waits = waits + 1
                elseif caller == "_rellume_aarch64_stxp" and callee == "_xl_pair_unaligned" then
                    refusals = refusals + 1
                elseif not (caller == "_xl_pair_unaligned" and (callee == "_write" or callee == "_abort" or callee == "_xl_line_text")) then
                    print(line)
                    corpus.fail("%s calls %s: the pair store may call thread_switch (while it waits and holds nothing) and its refusal (which does not return), and nothing else: a call inside the lock could keep it held",
                                tostring(caller), callee)
                end
            end
        end
        if waits ~= 1 or refusals ~= 1 then
            print(armv7)
            corpus.fail("the pair store compiled for armv7 has %d calls of thread_switch and %d of its refusal where one of each is its whole shape", waits, refusals)
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
        return device.run(string.format("sysctl -n hw.ncpu; chmod +x %s && %s; echo exit=$?; echo overlap; %s --overlap 2>&1; echo exit=$?; echo overlap32; %s --overlap32 2>&1; echo exit=$?; rm -f %s",
                                        remote, remote, remote, remote, remote))
    end } or ""
    io.writefile(o("run.txt"), output)
    io.write(output)
    local whole, wide, narrow = output:gsub("\r", ""):match("^(.-)\noverlap\n(.-)\noverlap32\n(.*)$")
    if not whole then
        corpus.fail("the run on the device did not reach its three parts")
    end
    verify(corpus, whole, "the translated program", LINES, whole:match("exit=%d+") or "no exit status")
    if not whole:find("exit=0", 1, true) then
        corpus.fail("the translated program did not exit with 0")
    end
    if not wide:find("xlate: a store%-pair at 0x%x+ is not aligned to 16 bytes") or wide:find("pairs.overlap", 1, true) or wide:find("exit=0", 1, true) then
        corpus.fail("two 64-bit pairs that share a word did not stop the translated program at the first store")
    end
    if narrow:find("FAIL", 1, true) or not (narrow:find("ok pairs.overlap32", 1, true) or not narrow:find("exit=0", 1, true)) then
        corpus.fail("two 32-bit pairs that share a word lost an update on the device: such a pair is one exclusive of 64 bits, which stores whole or faults")
    end
    print("ok: on the device two 64-bit pairs that share a word stop the program, and two 32-bit ones %s", narrow:find("ok pairs.overlap32", 1, true) and "lose no update" or "fault")
    print("ok: the translated program, on the %s processors of the device, lost no update of a pair and read no pair torn (%d scenarios)", output:match("^(%d+)") or "?", #LINES)
end

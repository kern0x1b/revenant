local acquires = {relaxed = false, acquire = true, release = false, acq_rel = true, seq_cst = true}
local releases = {relaxed = false, acquire = false, release = true, acq_rel = true, seq_cst = true}
local sizes = {["8"] = "b", ["16"] = "h", ["32"] = "", ["64"] = ""}

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

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("llsc", out)
    local function o(file)
        return path.join(out, file)
    end
    for _, name in ipairs({"llsc-arm64", "out.bc", "out.ll", "xlate.log", "coverage.log", "coverage.txt", "lifted-armv7.o"}) do
        os.tryrm(o(name))
    end
    local binary = o("llsc-arm64")
    corpus.ios(e, {"-march=armv8-a", "-O2", "-w", "-o", binary, path.join(os.scriptdir(), "main.c")})

    local disassembly = functions(os.iorunv("xcrun", {"otool", "-tV", binary}))
    local cases = {}
    for line in os.iorunv("xcrun", {"nm", binary}):gmatch("[^\n]+") do
        local address, symbol = line:match("^(%x+) T (_llsc_[%w_]+)$")
        if symbol then
            local operation, bits, order = symbol:match("^_llsc_(%a+)_(%d+)_([%a_]+)$")
            table.insert(cases, {symbol = symbol, operation = operation, bits = bits, order = order,
                                 guest = format("%x", tonumber(address, 16) - 0x100000000 + 0x10000000)})
        end
    end
    table.sort(cases, function (a, b) return a.symbol < b.symbol end)
    if #cases ~= 160 then
        corpus.fail("expected 160 llsc_ functions in %s, found %d", binary, #cases)
    end
    for _, case in ipairs(cases) do
        local load = (acquires[case.order] and "ldaxr" or "ldxr") .. sizes[case.bits]
        local store = (releases[case.order] and "stlxr" or "stxr") .. sizes[case.bits]
        local found = {}
        for _, line in ipairs(disassembly[case.symbol] or {}) do
            for _, mnemonic in ipairs({load, store}) do
                if line:match("^%x+\t" .. mnemonic .. "\t") then
                    found[mnemonic] = true
                end
            end
        end
        if not found[load] or not found[store] then
            corpus.fail("%s does not carry %s and %s: clang did not emit the exclusive loop this case is for", case.symbol, load, store)
        end
    end

    io.writefile(o("passthrough.txt"), "")
    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--coverage", o("coverage.txt"), binary}, o("coverage.log"))
    io.write(log)
    if not ok or not log:find("coverage: 0 of ", 1, true) then
        corpus.fail("xlate left an instruction of %s unlifted, clrex among them (see %s)", binary, o("coverage.txt"))
    end

    ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("out.bc"), "--layout", o("layout.txt"),
                                   "--state-header", o("xl_state.h"), "--passthrough", o("passthrough.txt"), binary}, o("xlate.log"))
    io.write(log)
    if not ok or not log:find(", 0 failures", 1, true) then
        corpus.fail("xlate did not lift every function of %s (see %s)", binary, o("xlate.log"))
    end
    local state = io.readfile(o("xl_state.h"))
    for _, slot in ipairs({"EXCL_ADDR", "EXCL_VAL"}) do
        if not state:find("#define XL_OFFSET_" .. slot .. " ", 1, true) then
            corpus.fail("%s does not export the exclusive monitor slot %s", o("xl_state.h"), slot)
        end
    end
    os.execv(path.join(e.llvmbin, "llvm-dis"), {o("out.bc"), "-o", o("out.ll")})
    local ir = io.readfile(o("out.ll"))
    for _, case in ipairs(cases) do
        local body = lifted(ir, case.guest)
        if not body then
            corpus.fail("no lifted function sub_%s for %s", case.guest, case.symbol)
        end
        local bytes = tostring(tonumber(case.bits) // 8)
        local success = releases[case.order] and "release" or "monotonic"
        local loading = acquires[case.order] and "acquire" or "monotonic"
        local exchanges = count(body, "cmpxchg ")
        local wanted = count(body, "cmpxchg ptr [^,]+, i" .. case.bits .. " [^,]+, i" .. case.bits .. " [^,]+ " .. success .. " monotonic, align " .. bytes .. "%f[^%d]")
        local loads = count(body, "load atomic i" .. case.bits .. ", ptr [^,]+ " .. loading .. ", align " .. bytes .. "%f[^%d]")
        if exchanges == 0 or exchanges ~= wanted or loads == 0 or count(body, "atomicrmw ") ~= 0 then
            io.write(body, "\n")
            corpus.fail("%s (sub_%s) is not lifted to an exclusive load of %s and a %s cmpxchg of the monitor", case.symbol, case.guest, loading, success)
        end
    end
    print("ok: 160 exclusive loops, each lifted to its width's atomic load and a cmpxchg of the monitor, in its ordering")

    os.execv(path.join(e.llvmbin, "clang"), {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-w",
                                                 "-c", o("out.bc"), "-o", o("lifted-armv7.o")})
    local armv7 = os.iorunv("xcrun", {"otool", "-tV", o("lifted-armv7.o")})
    for _, exclusive in ipairs({"ldrexb", "strexb", "ldrexh", "strexh", "ldrex", "strex", "ldrexd", "strexd"}) do
        if not armv7:find("\t" .. exclusive .. "\t", 1, true) then
            corpus.fail("the lifted code compiled for armv7 has no %s: an exclusive width was not lowered to its pair", exclusive)
        end
    end
    print("ok: the lifted code compiles for armv7 to byte, halfword, word and doubleword exclusive pairs")
end

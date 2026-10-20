local mnemonics = {add = "ldadd", ["and"] = "ldclr", xor = "ldeor", ["or"] = "ldset", xchg = "swp",
                   smax = "ldsmax", smin = "ldsmin", umax = "ldumax", umin = "ldumin", cas = "cas"}
local operations = {add = "add", ["and"] = "and", xor = "xor", ["or"] = "or", xchg = "xchg",
                    smax = "max", smin = "min", umax = "umax", umin = "umin"}
local suffixes = {relaxed = "", acquire = "a", release = "l", acq_rel = "al", seq_cst = "al"}
local orderings = {relaxed = "monotonic", acquire = "acquire", release = "release", acq_rel = "acq_rel", seq_cst = "acq_rel"}
local failures = {relaxed = "monotonic", acquire = "acquire", release = "monotonic", acq_rel = "acquire", seq_cst = "acquire"}
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

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("lse", out)
    local function o(file)
        return path.join(out, file)
    end
    for _, name in ipairs({"lse-arm64", "out.bc", "out.ll", "xlate.log", "lifted-armv7.o"}) do
        os.tryrm(o(name))
    end
    local binary = o("lse-arm64")
    corpus.ios(e, {"-march=armv8.1-a", "-O2", "-w", "-o", binary, path.join(os.scriptdir(), "main.c")})

    local disassembly = functions(os.iorunv("xcrun", {"otool", "-tV", binary}))
    local cases = {}
    for line in os.iorunv("xcrun", {"nm", binary}):gmatch("[^\n]+") do
        local address, symbol = line:match("^(%x+) T (_lse_[%w_]+)$")
        if symbol then
            local operation, bits, order = symbol:match("^_lse_(%a+)_(%d+)_([%a_]+)$")
            table.insert(cases, {symbol = symbol, operation = operation, bits = bits, order = order,
                                 guest = format("%x", tonumber(address, 16) - 0x100000000 + 0x10000000)})
        end
    end
    table.sort(cases, function (a, b) return a.symbol < b.symbol end)
    if #cases ~= 200 then
        corpus.fail("expected 200 lse_ functions in %s, found %d", binary, #cases)
    end
    for _, case in ipairs(cases) do
        local mnemonic = mnemonics[case.operation] .. suffixes[case.order] .. sizes[case.bits]
        local register = case.bits == "64" and "x" or "w"
        local found = false
        for _, line in ipairs(disassembly[case.symbol] or {}) do
            if line:match("^%x+\t" .. mnemonic .. "\t" .. register .. "%d") then
                found = true
            end
        end
        if not found then
            corpus.fail("%s does not carry %s on %s registers: clang did not emit the LSE form this case is for", case.symbol, mnemonic, register)
        end
    end

    io.writefile(o("passthrough.txt"), "")
    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("out.bc"), "--layout", o("layout.txt"),
                                         "--state-header", o("xl_state.h"), "--passthrough", o("passthrough.txt"), binary}, o("xlate.log"))
    io.write(log)
    if not ok or not log:find(", 0 failures", 1, true) then
        corpus.fail("xlate did not lift every function of %s (see %s)", binary, o("xlate.log"))
    end
    os.execv(path.join(e.llvmbin, "llvm-dis"), {o("out.bc"), "-o", o("out.ll")})
    local ir = io.readfile(o("out.ll"))
    for _, case in ipairs(cases) do
        local body = lifted(ir, case.guest)
        if not body then
            corpus.fail("no lifted function sub_%s for %s", case.guest, case.symbol)
        end
        local _, rmws = body:gsub("atomicrmw ", "")
        local _, exchanges = body:gsub("cmpxchg ", "")
        local atomics = rmws + exchanges
        local bytes = tostring(tonumber(case.bits) // 8)
        local want
        if case.operation == "cas" then
            want = "cmpxchg ptr [^,]+, i" .. case.bits .. " [^,]+, i" .. case.bits .. " [^,]+ " .. orderings[case.order] .. " " .. failures[case.order] .. ", align " .. bytes .. "%f[^%d]"
        else
            want = "atomicrmw " .. operations[case.operation] .. " ptr [^,]+, i" .. case.bits .. " [^,]+ " .. orderings[case.order] .. ", align " .. bytes .. "%f[^%d]"
        end
        if atomics ~= 1 or not body:find(want) then
            io.write(body, "\n")
            corpus.fail("%s (sub_%s) is not lifted to one %s", case.symbol, case.guest, want)
        end
    end
    print("ok: 200 LSE functions, each lifted to the atomic of its operation, width and ordering")

    os.execv(path.join(e.llvmbin, "clang"), {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-w",
                                                 "-c", o("out.bc"), "-o", o("lifted-armv7.o")})
    local armv7 = os.iorunv("xcrun", {"otool", "-tV", o("lifted-armv7.o")})
    for _, exclusive in ipairs({"ldrexb", "strexb", "ldrexh", "strexh", "ldrex", "strex", "ldrexd", "strexd"}) do
        if not armv7:find("\t" .. exclusive .. "\t", 1, true) then
            corpus.fail("the lifted code compiled for armv7 has no %s: an atomic width was not lowered to its exclusive pair", exclusive)
        end
    end
    print("ok: the lifted code compiles for armv7 to byte, halfword, word and doubleword exclusive pairs")
end

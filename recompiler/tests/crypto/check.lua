local decoded_names = {"aese", "aesd", "aesmc", "aesimc", "sha1c", "sha1p", "sha1m", "sha1h", "sha1su0", "sha1su1",
                       "sha256h", "sha256h2", "sha256su0", "sha256su1", "pmull", "sli", "sri", "saddlv", "uaddlv", "fcvt_h", "fcvt_s", "fcvt_d"}
local decoded = {}
for _, name in ipairs(decoded_names) do
    decoded[name] = true
end
local arrangement = {aese = 1, aesd = 1, aesmc = 1, aesimc = 1}
local three_operands = {sha1c = true, sha1p = true, sha1m = true, sha1su0 = true, sha256h = true, sha256h2 = true, sha256su1 = true, pmull = true}
local arrangement_of = {["8b"] = 0, ["16b"] = 1, ["4h"] = 2, ["8h"] = 3, ["2s"] = 4, ["4s"] = 5, ["1d"] = 6, ["2d"] = 7}
local precision_of = {h = 1, s = 2, d = 3}
local lenient = {sli = true, sri = true, saddlv = true, uaddlv = true, fcvt_h = true, fcvt_s = true, fcvt_d = true}
local SCALAR = 16

local functions = {
    crypto_aese = {mnemonic = "aese.16b", calls = {"aese"}},
    crypto_aesd = {mnemonic = "aesd.16b", calls = {"aesd"}},
    crypto_aesmc = {mnemonic = "aesmc.16b", calls = {"aesmc"}},
    crypto_aesimc = {mnemonic = "aesimc.16b", calls = {"aesimc"}},
    crypto_sha1c = {mnemonic = "sha1c.4s", calls = {"sha1c"}},
    crypto_sha1p = {mnemonic = "sha1p.4s", calls = {"sha1p"}},
    crypto_sha1m = {mnemonic = "sha1m.4s", calls = {"sha1m"}},
    crypto_sha1h = {mnemonic = "sha1h", calls = {}, funnel = true},
    crypto_sha1su0 = {mnemonic = "sha1su0.4s", calls = {"sha1su0"}},
    crypto_sha1su1 = {mnemonic = "sha1su1.4s", calls = {"sha1su1"}},
    crypto_sha256h = {mnemonic = "sha256h.4s", calls = {"sha256h"}},
    crypto_sha256h2 = {mnemonic = "sha256h2.4s", calls = {"sha256h2"}},
    crypto_sha256su0 = {mnemonic = "sha256su0.4s", calls = {"sha256su0"}},
    crypto_sha256su1 = {mnemonic = "sha256su1.4s", calls = {"sha256su1"}},
    crypto_pmull_8b = {mnemonic = "pmull.8h", calls = {"pmull8"}},
    crypto_pmull2_16b = {mnemonic = "pmull2.8h", calls = {"pmull8"}},
    crypto_pmull_1d = {mnemonic = "pmull.1q", calls = {"pmull64"}},
    crypto_pmull2_2d = {mnemonic = "pmull2.1q", calls = {"pmull64"}},
    crypto_trn1_16b = {mnemonic = "trn1.16b", calls = {}},
    crypto_trn2_16b = {mnemonic = "trn2.16b", calls = {}},
    crypto_trn1_8h = {mnemonic = "trn1.8h", calls = {}},
    crypto_trn2_8h = {mnemonic = "trn2.8h", calls = {}},
    crypto_trn1_4s = {mnemonic = "trn1.4s", calls = {}},
    crypto_trn2_4s = {mnemonic = "trn2.4s", calls = {}},
    crypto_trn1_2d = {mnemonic = "trn1.2d", calls = {}},
    crypto_trn2_2d = {mnemonic = "trn2.2d", calls = {}},
    crypto_trn1_8b = {mnemonic = "trn1.8b", calls = {}},
    crypto_trn2_8b = {mnemonic = "trn2.8b", calls = {}},
    crypto_sli_16b = {mnemonic = "sli.16b", calls = {}},
    crypto_sli_8h = {mnemonic = "sli.8h", calls = {}},
    crypto_sli_4s = {mnemonic = "sli.4s", calls = {}},
    crypto_sli_2d = {mnemonic = "sli.2d", calls = {}},
    crypto_sli_8b = {mnemonic = "sli.8b", calls = {}},
    crypto_sli_4h = {mnemonic = "sli.4h", calls = {}},
    crypto_sli_2s = {mnemonic = "sli.2s", calls = {}},
    crypto_sli_4s_by_0 = {mnemonic = "sli.4s", calls = {}},
    crypto_sli_d = {mnemonic = "sli", calls = {}},
    crypto_sri_16b = {mnemonic = "sri.16b", calls = {}},
    crypto_sri_8h = {mnemonic = "sri.8h", calls = {}},
    crypto_sri_4s = {mnemonic = "sri.4s", calls = {}},
    crypto_sri_2d = {mnemonic = "sri.2d", calls = {}},
    crypto_sri_8b = {mnemonic = "sri.8b", calls = {}},
    crypto_sri_4h = {mnemonic = "sri.4h", calls = {}},
    crypto_sri_2s = {mnemonic = "sri.2s", calls = {}},
    crypto_sri_4s_by_32 = {mnemonic = "sri.4s", calls = {}},
    crypto_sri_d = {mnemonic = "sri", calls = {}},
    crypto_uaddlv_16b = {mnemonic = "uaddlv.16b", calls = {}},
    crypto_uaddlv_8b = {mnemonic = "uaddlv.8b", calls = {}},
    crypto_uaddlv_8h = {mnemonic = "uaddlv.8h", calls = {}},
    crypto_uaddlv_4h = {mnemonic = "uaddlv.4h", calls = {}},
    crypto_uaddlv_4s = {mnemonic = "uaddlv.4s", calls = {}},
    crypto_saddlv_16b = {mnemonic = "saddlv.16b", calls = {}},
    crypto_saddlv_8b = {mnemonic = "saddlv.8b", calls = {}},
    crypto_saddlv_8h = {mnemonic = "saddlv.8h", calls = {}},
    crypto_saddlv_4h = {mnemonic = "saddlv.4h", calls = {}},
    crypto_saddlv_4s = {mnemonic = "saddlv.4s", calls = {}},
    crypto_fcvt_h_s = {mnemonic = "fcvt", calls = {"fcvt_h_s"}},
    crypto_fcvt_h_d = {mnemonic = "fcvt", calls = {"fcvt_h_d"}},
    crypto_fcvt_s_h = {mnemonic = "fcvt", calls = {"fcvt_s_h"}},
    crypto_fcvt_d_h = {mnemonic = "fcvt", calls = {"fcvt_d_h"}},
    crypto_round = {mnemonic = "aesmc.16b", calls = {"aese", "aesmc"}},
    crypto_adc_x = {mnemonic = "adc", calls = {}},
    crypto_adc_w = {mnemonic = "adc", calls = {}},
    crypto_adcs_x = {mnemonic = "adcs", calls = {}},
    crypto_adcs_w = {mnemonic = "adcs", calls = {}},
    crypto_sbc_x = {mnemonic = "sbc", calls = {}},
    crypto_sbc_w = {mnemonic = "sbc", calls = {}},
    crypto_sbcs_x = {mnemonic = "sbcs", calls = {}},
    crypto_sbcs_w = {mnemonic = "sbcs", calls = {}},
    crypto_ngc_x = {mnemonic = "ngc", calls = {}},
    crypto_ngcs_x = {mnemonic = "ngcs", calls = {}},
    crypto_ngcs_w = {mnemonic = "ngcs", calls = {}},
    crypto_final_reduction = {mnemonic = "sbcs", calls = {}},
}

local function native_oracle(corpus, out)
    local driver = path.join(out, "helpers")
    os.execv("cc", {"-O2", "-march=armv8-a+crypto", "-w", path.join(os.scriptdir(), "driver.c"), "-o", driver})
    local result = os.iorunv(driver, {})
    io.write(result)
    local comparisons, failures = result:match("(%d+) comparisons, (%d+) failures")
    if not comparisons or failures ~= "0" then
        corpus.fail("the helpers of src/runtime/crypto.c disagree with the hardware instructions or with the FIPS vectors")
    end
    print("ok: the helpers agree with the hardware instructions and the FIPS 197 and FIPS 180-4 vectors in %s comparisons", comparisons)
end

local function encodings()
    local words = {}
    local function add(word)
        table.insert(words, string.format("%08x", word))
    end
    for _, base in ipairs({0x4E284800, 0x4E285800, 0x4E286800, 0x4E287800, 0x5E280800, 0x5E281800, 0x5E282800}) do
        for rn = 0, 31 do
            for rd = 0, 31 do
                add(base | rn << 5 | rd)
            end
        end
    end
    local function three_registers(base)
        for rm = 0, 31 do
            for rn = 0, 31 do
                for rd = 0, 31 do
                    add(base | rm << 16 | rn << 5 | rd)
                end
            end
        end
    end
    for opcode = 0, 6 do
        three_registers(0x5E000000 | opcode << 12)
    end
    for _, base in ipairs({0x0E20E000, 0x4E20E000, 0x0EE0E000, 0x4EE0E000}) do
        three_registers(base)
    end
    local index = 0
    for _, top in ipairs({0x0E, 0x1E, 0x2E, 0x3E, 0x4E, 0x5E, 0x6E, 0x7E}) do
        for middle = 0, 0x3FFF do
            add(top << 24 | middle << 10 | ((index * 13 + 5) % 32) << 5 | (index * 7) % 32)
            index = index + 1
        end
    end
    for _, top in ipairs({0x0F, 0x2F, 0x4F, 0x6F, 0x5F, 0x7F}) do
        for _, opcode in ipairs({0x08, 0x0A}) do
            for shift = 8, 127 do
                add(top << 24 | shift << 16 | opcode << 11 | 1 << 10 | ((shift * 5 + 3) % 32) << 5 | (shift * 11 + 7) % 32)
            end
        end
    end
    for _, base in ipairs({0x0E303800, 0x4E303800, 0x2E303800, 0x6E303800}) do
        for size = 0, base & 0x40000000 ~= 0 and 2 or 1 do
            for rn = 0, 31 do
                for rd = 0, 31 do
                    add(base | size << 22 | rn << 5 | rd)
                end
            end
        end
    end
    for _, source in ipairs({0, 1, 3}) do
        for _, target in ipairs({0, 1, 3}) do
            if source ~= target then
                for rn = 0, 31 do
                    for rd = 0, 31 do
                        add(0x1E204000 | source << 22 | target << 15 | rn << 5 | rd)
                    end
                end
            end
        end
    end
    return words
end

local function disassembly(listing)
    local result = {}
    for line in listing:gmatch("[^\n]+") do
        local text = line:match("^%s+%x+:%s*(.-)%s*$")
        if text then
            local mnemonic, suffix, operands = text:match("^([%w_]+)%.?([%w_]*)%s*(.*)$")
            local registers, letters = {}, {}
            for letter, number in (operands or ""):gmatch("%f[%w]([vqsdh])(%d+)%f[%D]") do
                table.insert(registers, tonumber(number))
                table.insert(letters, letter)
            end
            local immediate = (operands or ""):match("#(0x%x+)$") or (operands or ""):match("#(%d+)$")
            table.insert(result, {mnemonic = mnemonic or "other", suffix = suffix, registers = registers, letters = letters, immediate = tonumber(immediate)})
        end
    end
    return result
end

local function decoder_oracle(corpus, e, out)
    local words = encodings()
    local lines = {}
    for _, word in ipairs(words) do
        table.insert(lines, string.format(".inst 0x%s", word))
    end
    local source, object = path.join(out, "words.s"), path.join(out, "words.o")
    io.writefile(source, table.concat(lines, "\n") .. "\n")
    os.execv("xcrun", {"clang", "-target", "arm64-apple-macos", "-march=armv8-a+crypto", "-c", source, "-o", object})
    local oracle = disassembly(os.iorunv("xcrun", {"llvm-objdump", "-d", "--no-show-raw-insn", object}))
    if #oracle ~= #words then
        corpus.fail("llvm-objdump listed %d instructions for %d words", #oracle, #words)
    end
    local driver = path.join(out, "decode")
    os.execv("cc", {"-O1", "-w", "-I", path.join(e.farmdec, "include"), path.join(os.scriptdir(), "decode.c"),
                    path.join(e.farmdec, "lib", "libfarmdec.a"), "-o", driver})
    local input, output = path.join(out, "words.txt"), path.join(out, "decoded.txt")
    io.writefile(input, table.concat(words, "\n") .. "\n")
    os.execv(driver, {}, {stdin = input, stdout = output})
    local seen, wrong, total, reserved = {}, 0, 0, 0
    local index = 0
    for line in io.lines(output) do
        index = index + 1
        local word, name, rd, rn, rm, va, immediate = line:match("^(%x+) (%S+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
        local want = oracle[index]
        local base = want.mnemonic == "pmull2" and "pmull" or want.mnemonic
        if base == "fcvt" then
            base = "fcvt_" .. (want.letters[1] or "")
        end
        local expected = decoded[base] and base or "other"
        local ok = word == words[index] and name == expected
        if not ok and word == words[index] and expected == "other" and lenient[name] then
            ok = true
            reserved = reserved + 1
        end
        if ok and expected ~= "other" then
            local number = tonumber(word, 16)
            ok = tonumber(rd) == want.registers[1] and tonumber(rn) == want.registers[2]
            if three_operands[expected] then
                ok = ok and tonumber(rm) == want.registers[3]
            end
            local shape = expected == "pmull" and ((number >> 22 & 3) * 2 + (number >> 30 & 1)) or (arrangement[expected] or 5)
            if expected == "sli" or expected == "sri" then
                shape = want.suffix ~= "" and arrangement_of[want.suffix] or SCALAR + arrangement_of["2d"]
                ok = ok and tonumber(immediate) == want.immediate
            elseif expected == "saddlv" or expected == "uaddlv" then
                shape = arrangement_of[want.suffix]
            elseif expected:find("^fcvt_") then
                shape = precision_of[want.letters[2]]
            end
            ok = ok and tonumber(va) == shape
            seen[expected] = (seen[expected] or 0) + 1
            total = total + 1
        end
        if not ok then
            wrong = wrong + 1
            if wrong <= 10 then
                print("FAIL: %s decoded as '%s'; llvm-objdump says %s", words[index], line, want.mnemonic)
            end
        end
    end
    if index ~= #words then
        corpus.fail("farmdec decoded %d of %d words", index, #words)
    end
    for _, name in ipairs(decoded_names) do
        if not seen[name] then
            corpus.fail("no word of the sweep is %s for llvm-objdump", name)
        end
    end
    if wrong > 0 then
        corpus.fail("farmdec disagrees with llvm-objdump on %d of %d words", wrong, #words)
    end
    print("ok: farmdec and llvm-objdump agree on %d words, %d of them an instruction of the Crypto extension, PMULL, SLI, SRI, SADDLV, UADDLV or FCVT (farmdec also decodes %d reserved encodings of the last five that llvm-objdump rejects, which no code holds)", #words, total, reserved)
end

local function listing_of(text)
    local bodies, current = {}, nil
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
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

local function parameters(signature)
    local types = {}
    for parameter in signature:gmatch("[^,]+") do
        table.insert(types, parameter:match("^%s*([%w<>]+)"))
    end
    return table.concat(types, ",")
end

local function lifted_oracle(corpus, e, out, cases)
    local declarations = {}
    for _, case in ipairs(cases) do
        table.insert(declarations, format("void sub_%s(void *state);", case.guest))
        table.insert(declarations, format("#define SUB_%s sub_%s", case.symbol:sub(2), case.guest))
    end
    io.writefile(path.join(out, "lifted.h"), table.concat(declarations, "\n") .. "\n")
    local object, driver = path.join(out, "lifted-host.o"), path.join(out, "lifted")
    os.execv(path.join(e.llvmbin, "clang"), {"-target", "arm64-apple-macos", "-Wno-override-module", "-O2", "-c", path.join(out, "out.bc"), "-o", object})
    os.execv("cc", {"-O2", "-march=armv8-a+crypto", "-w", "-I", out, path.join(os.scriptdir(), "lifted.c"), object,
                    path.join(e.root, "recompiler", "src", "runtime", "crypto.c"), path.join(e.root, "recompiler", "src", "runtime", "half.c"),
                    "-o", driver})
    local result = os.iorunv(driver, {})
    io.write(result)
    local functions, comparisons, failures = result:match("(%d+) functions, (%d+) comparisons, (%d+) failures")
    if not comparisons or failures ~= "0" or tonumber(functions) ~= #cases then
        corpus.fail("the lifted functions run natively disagree with the hardware instructions they were lifted from")
    end
    print("ok: the %s lifted functions, run natively against the helpers, agree with the hardware instructions in %s comparisons", functions, comparisons)
end

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("crypto", out)
    local function o(file)
        return path.join(out, file)
    end
    for _, name in ipairs({"crypto-arm64", "out.bc", "out.ll", "xlate.log", "coverage.log", "coverage.txt", "lifted.h", "lifted-host.o", "lifted", "lifted-armv7.o", "runtime-crypto-armv7.o", "runtime-crypto-armv7.ll", "runtime-half-armv7.o", "runtime-half-armv7.ll", "linked-armv7.o"}) do
        os.tryrm(o(name))
    end

    native_oracle(corpus, out)
    decoder_oracle(corpus, e, out)

    local binary = o("crypto-arm64")
    corpus.ios(e, {"-march=armv8-a+crypto", "-O2", "-w", "-fno-stack-protector", "-o", binary, path.join(os.scriptdir(), "main.c")})
    local disassembled = listing_of(os.iorunv("xcrun", {"otool", "-tV", binary}))
    local cases = {}
    for line in os.iorunv("xcrun", {"nm", binary}):gmatch("[^\n]+") do
        local address, symbol = line:match("^(%x+) T (_crypto_[%w_]+)$")
        if symbol and functions[symbol:sub(2)] then
            local case = functions[symbol:sub(2)]
            case.symbol = symbol
            case.guest = format("%x", tonumber(address, 16) - 0x100000000 + 0x10000000)
            table.insert(cases, case)
        end
    end
    table.sort(cases, function (a, b) return a.symbol < b.symbol end)
    for name, case in pairs(functions) do
        if not case.symbol then
            corpus.fail("%s is missing from %s", name, binary)
        end
        local found = false
        for _, line in ipairs(disassembled[case.symbol]) do
            if line:match("^%x+\t" .. case.mnemonic:gsub("%.", "%%.") .. "\t") then
                found = true
            end
        end
        if not found then
            corpus.fail("%s does not carry %s: clang did not emit the instruction this case is for", case.symbol, case.mnemonic)
        end
    end

    io.writefile(o("passthrough.txt"), "")
    local ok, log = corpus.run(e.xlate, {"--base", "0x10000000", "--output", o("out.bc"), "--layout", o("layout.txt"),
                                         "--state-header", o("xl_state.h"), "--passthrough", o("passthrough.txt"), binary}, o("xlate.log"))
    io.write(log)
    if not ok or not log:find(", 0 failures", 1, true) then
        corpus.fail("xlate did not lift every function of %s (see %s)", binary, o("xlate.log"))
    end
    local covered, coverage = corpus.run(e.xlate, {"--base", "0x10000000", "--coverage", o("coverage.txt"), binary}, o("coverage.log"))
    if not covered or not coverage:find("coverage: 0 of ", 1, true) then
        corpus.fail("xlate left an instruction of %s unlifted (see %s)", binary, o("coverage.txt"))
    end
    os.execv(path.join(e.llvmbin, "llvm-dis"), {o("out.bc"), "-o", o("out.ll")})
    local ir = io.readfile(o("out.ll"))
    for _, case in ipairs(cases) do
        local body = lifted(ir, case.guest)
        if not body then
            corpus.fail("no lifted function sub_%s for %s", case.guest, case.symbol)
        end
        local expected = #case.calls
        if count(body, "call [^\n]*@rellume_aarch64_") ~= expected then
            io.write(body, "\n")
            corpus.fail("%s (sub_%s) does not call the %d helpers %s", case.symbol, case.guest, expected, table.concat(case.calls, ", "))
        end
        for _, helper in ipairs(case.calls) do
            if count(body, "call [^\n]*@rellume_aarch64_" .. helper .. "%(") ~= 1 then
                io.write(body, "\n")
                corpus.fail("%s (sub_%s) does not call rellume_aarch64_%s once", case.symbol, case.guest, helper)
            end
        end
        if case.funnel and count(body, "@llvm%.fshl%.i32") ~= 1 then
            io.write(body, "\n")
            corpus.fail("%s (sub_%s) is not lifted to one funnel shift", case.symbol, case.guest)
        end
    end
    local loop = lifted(ir, (function ()
        for line in os.iorunv("xcrun", {"nm", binary}):gmatch("[^\n]+") do
            local address = line:match("^(%x+) T _crypto_rounds$")
            if address then
                return format("%x", tonumber(address, 16) - 0x100000000 + 0x10000000)
            end
        end
    end)())
    if not loop then
        corpus.fail("no lifted function for _crypto_rounds")
    end
    local entry_end = loop:find("\n[%w_.]+:", 1)
    if count(loop, "call [^\n]*@rellume_aarch64_aese%(") ~= 1 or count(loop, "call [^\n]*@rellume_aarch64_aesmc%(") ~= 1 then
        io.write(loop, "\n")
        corpus.fail("the loop of _crypto_rounds does not call each helper once")
    end
    if not entry_end or count(loop:sub(entry_end), "= alloca ") ~= 0 or count(loop:sub(1, entry_end), "= alloca ") > 3 then
        io.write(loop, "\n")
        corpus.fail("the helper buffers of _crypto_rounds are not static allocas of its entry block")
    end
    print("ok: %d functions, each lifted to the helper calls of its instruction, with the buffers in the entry block", #cases + 1)
    lifted_oracle(corpus, e, out, cases)

    os.execv(path.join(e.llvmbin, "clang"), {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-w",
                                                 "-c", o("out.bc"), "-o", o("lifted-armv7.o")})
    local provided, objects = {}, {o("lifted-armv7.o")}
    for _, name in ipairs({"crypto", "half"}) do
        local runtime = path.join(e.root, "recompiler", "src", "runtime", name .. ".c")
        os.execv(path.join(e.llvmbin, "clang"), {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O2", "-Wall", "-Wextra",
                                                     "-c", runtime, "-o", o("runtime-" .. name .. "-armv7.o")})
        os.execv(path.join(e.llvmbin, "clang"), {"-target", "armv7-apple-ios6.0", "-marm", "-isysroot", e.sdk, "-O0", "-w",
                                                     "-S", "-emit-llvm", runtime, "-o", o("runtime-" .. name .. "-armv7.ll")})
        for line in io.readfile(o("runtime-" .. name .. "-armv7.ll")):gmatch("[^\n]+") do
            local symbol, signature = line:match("^define [^@]*@(rellume_aarch64_[%w_]+)%((.-)%) ")
            if symbol then
                provided[symbol] = parameters(signature)
            end
        end
        table.insert(objects, o("runtime-" .. name .. "-armv7.o"))
    end
    local declared = 0
    for line in ir:gmatch("[^\n]+") do
        local name, signature = line:match("^declare [^@]*@(rellume_aarch64_[%w_]+)%((.-)%)")
        if name then
            declared = declared + 1
            if provided[name] ~= parameters(signature) then
                corpus.fail("the lifted code declares %s(%s) and src/runtime defines it as (%s)", name, parameters(signature), tostring(provided[name]))
            end
        end
    end
    if declared == 0 then
        corpus.fail("the lifted code declares no rellume_aarch64_ helper")
    end
    local undefined = os.iorunv("xcrun", {"nm", "-u", o("lifted-armv7.o")})
    local defined = os.iorunv("xcrun", {"nm", "-g", "--defined-only", o("runtime-crypto-armv7.o"), o("runtime-half-armv7.o")})
    for symbol in undefined:gmatch("_rellume_aarch64_[%w_]+") do
        if not defined:find(symbol .. "\n", 1, true) then
            corpus.fail("%s is undefined in the lifted code and defined by no helper", symbol)
        end
    end
    os.execv(e.ld, table.join({"-r", "-arch", "armv7"}, objects, {"-o", o("linked-armv7.o")}))
    if os.iorunv("xcrun", {"nm", "-u", o("linked-armv7.o")}):find("rellume_aarch64_", 1, true) then
        corpus.fail("the lifted code and the helpers still leave a rellume_aarch64_ symbol undefined")
    end
    print("ok: the %d declared helpers match the prototypes of src/runtime/crypto.c and half.c, and the lifted code links against them for armv7", declared)
end

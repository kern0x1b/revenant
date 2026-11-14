local function lifted_size(e, bitcode, wanted)
    local functions, lines, chosen = 0, 0, 0
    local inside, counted = false, false
    for line in os.iorunv(path.join(e.llvmbin, "llvm-dis"), {bitcode, "-o", "-"}):gmatch("[^\n]+") do
        local name = line:match("^define .-@(sub_%x+)%(")
        if name then
            inside = true
            counted = wanted[name] or false
            functions = functions + 1
        end
        if inside then
            lines = lines + 1
            if counted then
                chosen = chosen + 1
            end
            if line == "}" then
                inside = false
            end
        end
    end
    return functions, lines, chosen
end

local function chain_names(binary)
    local base = tonumber(os.getenv("XL_BASE") or "0x10000000")
    local header, names, count = nil, {}, 0
    for line in os.iorunv("xcrun", {"nm", "-n", binary}):gmatch("[^\n]+") do
        local address, name = line:match("^(%x+) %a (%S+)$")
        if address and name == "__mh_execute_header" then
            header = tonumber(address, 16)
        elseif address and name:match("^_link%d+$") then
            names[address] = name
        end
    end
    local wanted = {}
    for address in pairs(names) do
        wanted[string.format("sub_%x", base + tonumber(address, 16) - header)] = true
        count = count + 1
    end
    return wanted, count
end

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("tailcalls", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local source = path.join(here, "main.c")

    os.execv("xcrun", {"clang", "-arch", "arm64", "-O2", "-w", source, "-o", o("tailcalls-mac")})
    os.execv(o("tailcalls-mac"), {}, {stdout = o("run-mac.txt")})

    corpus.ios(e, {"-O2", "-w", source, "-o", o("tailcalls-arm64")})
    local branches = 0
    for _ in os.iorunv("xcrun", {"objdump", "--arch=arm64", "-d", o("tailcalls-arm64")}):gmatch("\n%s*%x+:%s+%x+%s+b%s+0x%x+%s+<_?link%d+>") do
        branches = branches + 1
    end
    if branches < 40 then
        corpus.fail("the arm64 program has %d branches from one link of the chain to the next, the check needs at least 40: the compiler did not emit the tail calls", branches)
    end
    local wanted, links = chain_names(o("tailcalls-arm64"))
    if links ~= 51 then
        corpus.fail("the arm64 program has %d functions link<N>, there must be 51", links)
    end

    translate.translate(o("tailcalls-arm64"), path.join(here, "includes.h"), o("tail"), {}, {})
    translate.translate(o("tailcalls-arm64"), path.join(here, "includes.h"), o("inline"), {}, {XL_TAIL_CALLS = "0"})
    local tail, _, tail_chain = lifted_size(e, o("tail/lifted.bc"), wanted)
    local inline, _, inline_chain = lifted_size(e, o("inline/lifted.bc"), wanted)
    if tail_chain == 0 then
        corpus.fail("none of the 51 functions of the chain is a lifted function of its own with tail calls: the names of the lifted functions do not match the symbols")
    end
    if tail ~= inline then
        corpus.fail("tail calls lift %d functions and the old lift %d: both lift every function start once", tail, inline)
    end
    if tail_chain * 4 > inline_chain then
        corpus.fail("the 51 functions of the chain are %d lines of IR with tail calls and %d lines without: a function that ends in a branch to the next still carries it", tail_chain, inline_chain)
    end
    print("ok: a chain of 51 functions that branch to the next is %d lines of IR with tail calls, %d without", tail_chain, inline_chain)
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.copy(o("tail/tailcalls"), "/var/tmp/tailcalls")
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/tailcalls && /var/tmp/tailcalls 2>/dev/null; rm -f /var/tmp/tailcalls"))
    corpus.same(o("run-mac.txt"), o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end

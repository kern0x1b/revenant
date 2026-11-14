local MOST_CHAIN_LINES = 9000

local function lifted_size(e, bitcode, wanted)
    local functions, chosen, dispatches = 0, 0, 0
    local inside, counted = false, false
    for line in os.iorunv(path.join(e.llvmbin, "llvm-dis"), {bitcode, "-o", "-"}):gmatch("[^\n]+") do
        local name = line:match("^define .-@(sub_%x+)%(")
        if name then
            inside = true
            counted = wanted[name] or false
            functions = functions + 1
        end
        if inside and counted then
            chosen = chosen + 1
            if line:find("@xl_tail(", 1, true) then
                dispatches = dispatches + 1
            end
        end
        if inside and line == "}" then
            inside = false
        end
    end
    return functions, chosen, dispatches
end

local function chain_names(binary)
    local base = tonumber(os.getenv("XL_BASE") or "0x10000000")
    local header, names, count = nil, {}, 0
    for line in os.iorunv("xcrun", {"nm", "-n", binary}):gmatch("[^\n]+") do
        local address, name = line:match("^(%x+) %a (%S+)$")
        if address and name == "__mh_execute_header" then
            header = tonumber(address, 16)
        elseif address and name:match("^_link%d+$") and name ~= "_link50" then
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
    if links ~= 50 then
        corpus.fail("the arm64 program has %d functions link0 to link49 that end in a tail call, there must be 50", links)
    end

    translate.translate(o("tailcalls-arm64"), path.join(here, "includes.h"), o("xl"), {}, {})
    local _, chain_lines, dispatches = lifted_size(e, o("xl/lifted.bc"), wanted)
    if chain_lines == 0 then
        corpus.fail("none of the 50 functions of the chain is a lifted function of its own: the names of the lifted functions do not match the symbols")
    end
    if dispatches > 0 then
        corpus.fail("%d jumps from one link of the chain to the next go through xl_tail and its search of the function table, not to the function", dispatches)
    end
    if chain_lines > MOST_CHAIN_LINES then
        corpus.fail("the 50 functions of the chain are %d lines of IR, at most %d are expected: a function that ends in a branch to the next carries it again", chain_lines, MOST_CHAIN_LINES)
    end
    print("ok: a chain of 50 functions that branch to the next is %d lines of IR and calls each next function directly", chain_lines)
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/tailcalls"
    device.copy(o("xl/tailcalls"), remote)
    io.writefile(o("run.txt"), device.run(string.format("chmod +x %s && %s 2>/dev/null; rm -f %s", remote, remote, remote)))
    corpus.same(o("run-mac.txt"), o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end

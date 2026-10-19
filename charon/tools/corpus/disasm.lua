local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local USAGE = "usage: xmake l tools/corpus/disasm.lua <cache> <image> <lo> <hi> [armv7|arm64e]"
local CONDITIONS = {eq = true, ne = true, cs = true, hs = true, cc = true, lo = true, mi = true, pl = true, vs = true,
                    vc = true, hi = true, ls = true, ge = true, lt = true, gt = true, le = true, al = true, nv = true}

local function fail(code, message)
    io.stderr:write(message .. "\n")
    os.exit(code)
end

local function hex_value(text, name)
    if not text:match("^%x+$") then
        fail(2, string.format("disasm.lua: %s must be hex digits, not %s", name, text))
    end
    return math.tointeger(tonumber(text, 16))
end

local function on_path(name)
    for folder in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        local candidate = path.join(folder, name)
        if os.isfile(candidate) and os.isexec(candidate) then
            return candidate
        end
    end
    return ""
end

local function resolve_mc()
    local found = try {function () return os.iorunv("xcrun", {"-f", "llvm-mc"}) end}
    found = found and found:gsub("%s+$", "") or ""
    if found == "" then
        found = on_path("llvm-mc")
    end
    if found == "" or not os.isexec(found) then
        found = "/opt/homebrew/opt/llvm/bin/llvm-mc"
    end
    if not os.isexec(found) then
        fail(1, "disasm.lua: no llvm-mc found (xcrun -f, PATH and /opt/homebrew/opt/llvm/bin all came up empty)")
    end
    return found
end

local function is_branch(mnemonic)
    local core = mnemonic:match("^(.-)%.w$") or mnemonic
    for _, stem in ipairs({"b", "bl", "blx"}) do
        if core:sub(1, #stem) == stem then
            local rest = core:sub(#stem + 1)
            if rest == "" or CONDITIONS[rest] then
                return true
            end
        end
    end
    return false
end

local function width(text)
    local at = text:find("encoding: [", 1, true)
    if not at then
        return 0
    end
    local count = 1
    for _ in text:sub(at + 11):gmatch(",") do
        count = count + 1
    end
    return count
end

function main(cache, image, lo, hi, arch, ...)
    if not hi or #{...} > 0 then
        fail(2, USAGE)
    end
    arch = arch or "armv7"
    if arch ~= "armv7" and arch ~= "arm64e" then
        fail(2, "disasm.lua: arch must be armv7 or arm64e, not " .. arch)
    end
    local low = hex_value(lo, "lo")
    local high = hex_value(hi, "hi")
    local last = low % 2
    local mode, triple, bias, base
    if arch == "arm64e" then
        if last ~= 0 then
            fail(2, "disasm.lua: " .. lo .. " has its low bit set, which is Thumb's marker; an arm64e cache has no Thumb")
        end
        mode, triple, bias, base = "arm64e", "arm64e-apple-ios", 0, low
    elseif last == 1 then
        mode, triple, bias, base = "thumb", "thumbv7-apple-ios", 4, low - 1
    else
        mode, triple, bias, base = "arm", "armv7-apple-ios", 8, low
    end
    local finish = high - last
    local size = finish - base
    if size <= 0 then
        fail(2, "disasm.lua: the window must be non-empty, got " .. lo .. " .. " .. hi)
    end
    local scratch = workspace.run("disasm")
    local tag = string.format("%x", base)
    local mc = resolve_mc()
    local raw = path.join(scratch, "bytes-" .. mode .. "-" .. tag .. ".txt")
    if cache:sub(1, 1) == "@" then
        os.cp(cache:sub(2), raw)
    else
        os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "skeleton-table.lua"), cache, image, "bytes", tag, tostring(size)},
                 {stdout = raw, envs = {CHARON_ROOT = os.getenv("CHARON_ROOT") or workspace.root()}})
    end
    local lines = {}
    for line in io.lines(raw) do
        if line:sub(1, 1) ~= "#" then
            table.insert(lines, line)
        end
    end
    local digits = table.concat(lines)
    if #digits == 0 then
        fail(1, string.format("disasm.lua: the reader returned no bytes for %#x in %s", base, image))
    end
    if #digits ~= size * 2 then
        fail(1, string.format("disasm.lua: asked for %d bytes, the reader returned %d", size, #digits // 2))
    end
    local hex = digits:gsub("[ \n]", "")
    local stream = {}
    for i = 1, #hex, 2 do
        table.insert(stream, " 0x" .. hex:sub(i, i + 1))
    end
    io.write(string.format("#%#x .. %#x   mode %s   triple %s   llvm-mc %s   branch target = address + %d + offset\n",
                           base, finish, mode, triple, mc, bias))
    io.flush()
    local input = path.join(scratch, "stream-" .. mode .. "-" .. tag .. ".txt")
    io.writefile(input, table.concat(stream) .. "\n")
    local listing = path.join(scratch, "mc-" .. mode .. "-" .. tag .. ".txt")
    local out = io.open(listing, "w")
    local status = os.execv(mc, {"--disassemble", "-triple=" .. triple, "--show-encoding"},
                            {stdin = input, stdout = out, stderr = out, try = true})
    out:close()
    if status ~= 0 then
        io.stderr:write("disasm.lua: llvm-mc (" .. mc .. ") refused the window:\n")
        io.stderr:write(io.readfile(listing))
        os.exit(1)
    end
    local offset = 0
    for line in io.lines(listing) do
        if line:find("encoding: [", 1, true) then
            local here = base + offset
            local text = line:gsub("[ \t]*[@;] encoding: %[.*$", "", 1)
            io.write(string.format("%#x:\t%s\n", here, text))
            local mnemonic = line:match("^%s*(%S+)")
            local delta = text:match("#(%-?%d+)")
            if mnemonic and is_branch(mnemonic) and delta then
                io.write(string.format("\t; branch target %#x\n", here + bias + math.tointeger(tonumber(delta))))
            end
            offset = offset + width(line)
        end
    end
end

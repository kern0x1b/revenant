import("core.base.option")

local modules = path.join(assert(os.getenv("REVENANT_ROOT") or ".", "REVENANT_ROOT must name the worktree"), "modules")
local objc = import("apple.objc", {rootdir = modules, anonymous = true})
local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local OBJDUMP = "/Library/Developer/CommandLineTools/usr/bin/llvm-objdump"
local RUN = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true}).run("objc-method-imps")

local function hex_of(bytes)
    return (bytes:gsub(".", function (c) return string.format("%02x", c:byte()) end))
end

local function quoted(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function page_of(address, printed)
    local value = tonumber(printed) or 0
    if value >= 0x80000000 then
        value = value - 0x100000000
    end
    return (address & ~0xFFF) + value
end

local function disassemble(code)
    local source, object, listing = path.join(RUN, "body.s"), path.join(RUN, "body.o"), path.join(RUN, "body.txt")
    local listed = {}
    for index = 1, #code do
        listed[index] = string.format("0x%02x", code:byte(index))
    end
    io.writefile(source, string.format(".text\n.p2align 2\n.byte %s\n", table.concat(listed, ",")))
    os.execv("/bin/sh", {"-c", string.format("clang -c -arch arm64e %s -o %s > %s 2>&1 && %s -d --no-show-raw-insn --print-imm-hex %s > %s 2>&1",
        quoted(source), quoted(object), quoted(listing), quoted(OBJDUMP), quoted(object), quoted(listing))})
    local kept = {}
    for line in (io.readfile(listing) or ""):gmatch("[^\r\n]+") do
        local offset = line:match("^%s*(%x+):")
        if offset and tonumber("0x" .. offset) then
            table.insert(kept, line)
            if line:match("^\t(retab|ret)") then
                break
            end
        end
    end
    return kept
end

local function handed_to(lines, address)
    local page, register, slot
    for _, line in ipairs(lines) do
        local rest = line:match("^%s*%x+:%s+(.+)$")
        local width, target, loaded, immediate, added, kept, offset, branched, loaded_from, signed
        if rest then
            width, target = rest:match("^b(l?)%s+(0x%x+)")
            loaded, immediate = rest:match("^adrp%s+(%w+),%s*(0x%x+)")
            added, kept, offset = rest:match("^add%s+(%w+),%s*(%w+),%s*#(0x%x+)")
            branched = rest:match("^br%s+(%w+)")
            loaded_from = rest:match("^ldr%s+%w+,%s*%[(%w+)%]")
            signed = rest:match("^braa%s+%w+,%s*(%w+)")
        end
        if target then
            return {kind = width == "" and "branch" or "call", address = address + tonumber(target)}
        elseif loaded then
            page, register = page_of(address, immediate), loaded
        elseif page and added and register == kept then
            page = page + tonumber(offset)
        elseif page and loaded_from and loaded_from == register then
            slot = page
        elseif (page or slot) and ((branched and branched == register) or (signed and signed == register)) then
            return {kind = slot and "slot" or "branch", address = slot or page}
        else
            page, register, slot = nil, nil, nil
        end
    end
    return nil
end

local function literal_at(cache, address)
    if not cache.mapped(address, 32) then
        return nil
    end
    local held = cache.read_address(address, 32)
    if not held or #held < 32 then
        return nil
    end
    local _, _, pointer, length = string.unpack("<I8I8I8I8", held, 1)
    local target = pointer & 0x7FFFFFFFFFF
    if target == 0 or not cache.mapped(target, 1) then
        return nil
    end
    local text = cache.read_address(target, 256)
    if not text then
        return nil
    end
    local sentence = text:match("^[^%z]+")
    if not sentence or not sentence:match("^[%g %p]+$") then
        return nil
    end
    return {address = address, target = target, text = sentence, length = length,
        exact = #sentence == length}
end

local function name_of(cache, address)
    local symbol = dyld.symbol_at(cache, address)
    if symbol and symbol.name then
        return {address = address, name = symbol.name, image = symbol.image, kind = symbol.kind, at = symbol.at}
    end
    local held = cache.read_address(address, 32)
    local inside = held and #held >= 12 and handed_to(disassemble(held), address) or nil
    local reached
    if inside and inside.kind == "slot" then
        local slot = cache.mapped(inside.address, 8) and cache.read_address(inside.address, 8) or nil
        reached = slot and (string.unpack("<I8", slot, 1) & 0x7FFFFFFFFFF) or nil
    elseif inside and inside.kind == "branch" then
        reached = inside.address
    end
    if reached and not cache.mapped(reached, 1) then
        reached = nil
    end
    if reached then
        local target = dyld.symbol_at(cache, reached)
        return {address = address, name = target and target.name, image = target and target.image,
            kind = inside.kind == "slot" and "thunk" or "stub", at = reached, reached = reached}
    end
    return {address = address, name = nil, image = symbol and symbol.image, kind = symbol and "own code"}
end

local function show(cache, address)
    local named = name_of(cache, address)
    print(string.format("%#x  %-8s %-40s %s%s", address, named.kind, named.name or "no symbol in the cache",
        named.image or "", named.kind == "local" and named.at ~= address and
        string.format(" +%d", address - named.at) or ""))
    if not named.name then
        local held = cache.read_address(named.reached or address, 96)
        if held then
            for _, line in ipairs(disassemble(held)) do
                print("    " .. line)
            end
        end
    end
end

function main(cachefile, ...)
    local names, wanted, addresses = {}, {}, {}
    for _, argument in ipairs({...}) do
        local class, selector = argument:match("^([%a][%w_]*)@(.+)$")
        local address = argument:match("^0x%x+$")
        if class then
            names[#names + 1] = class
            wanted[#wanted + 1] = {class = class, selector = selector}
        elseif address then
            addresses[#addresses + 1] = tonumber(address)
        else
            names[#names + 1] = argument
            wanted[#wanted + 1] = {class = argument}
        end
    end
    assert(cachefile, "usage: objc-method-imps.lua <cache> <class>... [<Class>@<selector>...] [<0xaddress>...]")
    local cache = dyld.open_cache(cachefile)
    for _, address in ipairs(addresses) do
        show(cache, address)
    end
    local found = #names > 0 and objc.method_imps(cachefile, names, 512) or {}
    for _, ask in ipairs(wanted) do
        local entry = found[ask.class]
        if not entry then
            print(string.format("%s ABSENT from the cache", ask.class))
        else
            local listed = {}
            for selector in pairs(entry.bytes) do
                if not ask.selector or selector == ask.selector then
                    listed[#listed + 1] = selector
                end
            end
            byteorder.sort(listed)
            if #listed == 0 then
                print(string.format("%s -%s ABSENT from the cache", ask.class, tostring(ask.selector)))
            end
            for _, selector in ipairs(listed) do
                local address, code = entry.methods[selector], entry.bytes[selector]
                if #code == 0 then
                    print(string.format("%s %s %#x UNREADABLE", ask.class, selector, address))
                else
                    print(string.format("%s %s %#x %d %s", ask.class, selector, address, #code, hex_of(code)))
                    if ask.selector then
                        print(string.format("--- %s -%s at %#x, %s", ask.class, selector, address, entry.image))
                        local register, page
                        for _, line in ipairs(disassemble(code)) do
                            print(line)
                            local rest = line:match("^%s*%x+:%s+(.+)$")
                            local width, target, loaded, immediate, added, kept, offset
                            if rest then
                                width, target = rest:match("^b(l?)%s+(0x%x+)")
                                loaded, immediate = rest:match("^adrp%s+(%w+),%s*(0x%x+)")
                                added, kept, offset = rest:match("^add%s+(%w+),%s*(%w+),%s*#(0x%x+)")
                            end
                            if target then
                                show(cache, address + tonumber(target))
                            elseif loaded then
                                register, page = loaded, page_of(address, immediate)
                            elseif page and added and register == kept then
                                local at = page + tonumber(offset)
                                local literal = literal_at(cache, at)
                                print(string.format("    literal %#x  %s", at, literal and string.format(
                                    "%q%s", literal.text, literal.exact and "" or
                                    string.format(" (the record's own length is %d)", literal.length)) or "not text"))
                                register, page = nil, nil
                            else
                                register, page = nil, nil
                            end
                        end
                    end
                end
            end
        end
    end
    cache.close()
end

-- objc-method-imps.lua - what a release's own Objective-C methods DO, read out of a held dyld cache.
--
--   xmake l tools/objc-method-imps.lua <cache> <class>... [<Class>@<selector>...] [<0xaddress>...]
--
-- No switch of any kind: `xmake l` reads every argument that starts with a dash as its own and fails
-- on it (measured), so what the caller asks for is spelled in the argument itself - a class name reads
-- every method the class defines itself, Class@selector reads one of them down to the disassembly and
-- what that body names, and an address names the code sitting there.
--
-- apple.objc.inventory() answers which selectors a class carries and drops the address, because a
-- corpus row asks that. A row that asks what a method DOES needs the code, and a dyld shared cache
-- carries the code beside the metadata: method_imps() reads, in one pass, every method the named
-- classes define themselves with its unslid address and the bytes sitting there. This tool prints
-- them, and with a selector named it puts that body through clang and llvm-objdump and resolves what
-- the body names:
--
--   * a branch is pc-relative, and the object is assembled at 0, so what llvm-objdump prints plus the
--     body's own unslid address is the address in the cache;
--   * a cross-image call in a cache goes through a 12-byte stub no image owns - adrp x16, a page; add
--     x16, x16, an offset; br x16 - so the name of such a call is the name of what the stub branches
--     to, and the stub is read and asked about again. One level is all a cache stub has;
--   * a literal is an adrp page plus an add, and the cache is asked what is at the sum: a __cstring is
--     printed as the text it is, a __cfstring is followed to the bytes its pointer field holds.
--
-- Read-only: the cache is opened and closed and nothing under the cache folder is written. The object
-- files and listings go under .agent-work/runs/objc-method-imps, named from the directory above this
-- script so a rerun leaves its own evidence and nothing is read from /tmp.
--
-- One pass for the whole set of classes, because a pass costs minutes: measured 2026-10-03, 157s over
-- the cache of iOS 18.0 and 525s over the arm64e cache of iOS 16.0.
import("core.base.option")

local modules = path.join(assert(os.getenv("CHARON_ROOT") or ".", "CHARON_ROOT must name the worktree"), "modules")
local objc = import("apple.objc", {rootdir = modules, anonymous = true})
local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local OBJDUMP = "/Library/Developer/CommandLineTools/usr/bin/llvm-objdump"
local RUN = path.join(path.directory(os.scriptdir()), ".agent-work/runs/objc-method-imps")

local function hex_of(bytes)
    return (bytes:gsub(".", function (c) return string.format("%02x", c:byte()) end))
end

local function quoted(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- A page of the cache. llvm-objdump prints an adrp's target as an address in the object's own space -
-- measured: an adrp at object 0x4000 with a page displacement of 0x2000 prints 0x2004000 - and a page
-- below zero as the 32-bit two's complement (0xffffffff...). The object's own zero is its first page,
-- so the cache's page is the body's own page plus what was printed.
--
-- tonumber is called without a base throughout: this tree's lua reads "0x10" and returns 16 that way
-- and returns nil for tonumber("0x10", 16) (measured), and every number here is printed with a prefix.
local function page_of(address, printed)
    local value = tonumber(printed) or 0
    if value >= 0x80000000 then
        value = value - 0x100000000
    end
    return (address & ~0xFFF) + value
end

-- `code` as an arm64e object, and llvm-objdump's reading of it: the lines up to the instruction that
-- ends the function, because a body read further would take in the next one's bytes.
local function disassemble(code)
    local source, object, listing = path.join(RUN, "body.s"), path.join(RUN, "body.o"), path.join(RUN, "body.txt")
    local listed = {}
    for index = 1, #code do
        listed[index] = string.format("0x%02x", code:byte(index))
    end
    io.writefile(source, string.format(".text\n.p2align 2\n.byte %s\n", table.concat(listed, ",")))
    os.execv("/bin/sh", {"-c", string.format("clang -c -arch arm64e %s -o %s > %s 2>&1 && %s -d --no-show-raw-insn --print-imm-hex %s > %s 2>&1",
        quoted(source), quoted(object), quoted(listing), quoted(OBJDUMP), quoted(object), quoted(listing))})
    -- io.readfile hands back the file as one string here, not as lines (measured), so it is split.
    -- The offset is read with an explicit 0x: tonumber("c") is nil in this tree's lua (measured), and a
    -- filter that drops the lines it cannot read does not drop one line - it drops every instruction
    -- whose offset is spelled with letters only (c, d, e, f, 1a, 2b) and leaves the listing looking
    -- whole while every address after one of them belongs to the wrong instruction. Measured: -[HMZone
    -- init] read as a body that calls nothing, because its one call sat at offset c.
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

-- The address a body hands to the next thing it names. Two shapes reach an address and branch to it:
--   * a branch, whose target llvm-objdump prints as an address in the object's own space;
--   * a thunk, which reaches its address through a slot in two forms - a cache stub's adrp, add and br,
--     and the arm64e one that loads the slot and signs the branch (adrp, add, ldr, braa).
-- The second form reports the SLOT and kind "slot", because what is in the slot is a chained fixup and
-- only the caller, which reads the cache, can say what it points at.
-- nil for a body that names none, so a caller never resolves an instruction it did not read.
local function handed_to(lines, address)
    local page, register, slot
    for _, line in ipairs(lines) do
        local rest = line:match("^%s*%x+:%s+(.+)$")
        -- One match per line, and each on a line of its own: a Lua binary operator keeps only the
        -- first value of its right-hand side, so `rest and rest:match(p1, p2)` reads one capture of
        -- two and the second is nil (measured - it is why the first version of this resolved no stub).
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
            -- the slot holds the address; the branch that follows says this is where it is called
            slot = page
        elseif (page or slot) and ((branched and branched == register) or (signed and signed == register)) then
            return {kind = slot and "slot" or "branch", address = slot or page}
        else
            page, register, slot = nil, nil, nil
        end
    end
    return nil
end

-- What the cache holds at an address, as text. A cache does not store a data pointer as an address:
-- it stores a chained fixup, whose target is the low 43 bits (measured 2026-10-03: the record at
-- %#x of HomeKit's __AUTH_CONST holds %#x and the text at the address those bits name is the string
-- the record carries). A __cfstring is {isa, flags, that pointer, length}, so the length is read too
-- and printed when the text is not exactly that long - a sentence shorter or longer than the record
-- claims is not the literal, and saying so beats printing it as if it were.
--
-- nil when the address does not hold text, so a caller never prints a sentence it did not read.
local function literal_at(cache, address)
    -- Whether the cache can be read here is asked before it is read: read_address raises on an address
    -- outside every mapping rather than answering nil, and an adrp+add of a body can name one (measured).
    -- cache.mapped is the cache's own predicate for that, and a mapping is not an image: the text a
    -- __cfstring names can sit in a mapping no single image's segments cover.
    if not cache.mapped(address, 32) then
        return nil
    end
    local held = cache.read_address(address, 32)
    if not held or #held < 32 then
        return nil
    end
    local _, _, pointer, length = string.unpack("<I8I8I8I8", held, 1)
    local target = pointer & 0x7FFFFFFFFFF
    -- The same question of the text the record names, for the same reason. Nothing here asks whether the
    -- text sits above or below its record: in a cache it sits BELOW, because a framework's text comes
    -- before its data, and a guard that reads "backwards" as "not a pointer" rejects every literal in
    -- the cache (measured: the guard was in the first version and all ten bodies read "not text").
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

-- The name of the code at an address, and where it sits. Where the cache names it, that is the answer.
-- Where it does not, the address is still read, because two of the three reasons it carries no name are
-- answerable: a thunk (an address no image owns, or a release's own stub) says which address it holds,
-- and only a static helper of the release's own image has nothing left to ask.
local function name_of(cache, address)
    local symbol = dyld.symbol_at(cache, address)
    if symbol and symbol.name then
        return {address = address, name = symbol.name, image = symbol.image, kind = symbol.kind, at = symbol.at}
    end
    -- 32 bytes, not 16: the plain stub is 12 bytes (adrp, add, br) and the arm64e one that loads the
    -- slot and signs the branch is 24 (adrp, ldr, adrp, add, ldr, braa), and reading half of the second
    -- leaves a body that names nothing (measured).
    local held = cache.read_address(address, 32)
    local inside = held and #held >= 12 and handed_to(disassemble(held), address) or nil
    local reached
    if inside and inside.kind == "slot" then
        -- The slot's address comes out of the thunk's adrp and add, and one that lands outside every
        -- mapping ends the run otherwise (measured).
        local slot = cache.mapped(inside.address, 8) and cache.read_address(inside.address, 8) or nil
        reached = slot and (string.unpack("<I8", slot, 1) & 0x7FFFFFFFFFF) or nil
    elseif inside and inside.kind == "branch" then
        reached = inside.address
    end
    -- What a slot holds is followed only where the cache is mapped: the slot a HomeKit thunk reads is
    -- tagged 0x80090000 and its low half is not an address any mapping holds (measured), and the call is
    -- then reported as what it is - one whose callee this cache does not name.
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
    -- Code no symbol names is still worth reading: a release's own helpers are static and carry no name
    -- at all (measured: HomeKit's exception helpers and the thunks that reach them), and what they do
    -- is part of what the method that calls them does. A thunk is read through to what it reaches.
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
    os.mkdir(RUN)
    local cache = dyld.open_cache(cachefile)
    for _, address in ipairs(addresses) do
        show(cache, address)
    end
    -- One pass for the whole set of class names, read once and asked per class: a pass over an arm64e
    -- cache costs minutes, so asking inside the loop would pay it once per class.
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
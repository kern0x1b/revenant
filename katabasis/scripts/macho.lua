local MH_MAGIC = 0xfeedface
local MH_MAGIC_64 = 0xfeedfacf
local LC_SEGMENT = 0x1
local LC_SEGMENT_64 = 0x19
local LC_SYMTAB = 0x2
local LC_DYLD_INFO = 0x22
local LC_DYLD_INFO_ONLY = 0x80000022
local N_WEAK_REF = 0x0040
local BIND_SYMBOL_FLAGS_WEAK_IMPORT = 0x1

local FORWARD = {__objc_classlist = "__xlcls", __objc_catlist = "__xlcat", __objc_protolist = "__xlproto"}

local function u32(data, offset)
    return (string.unpack("<I4", data, offset + 1))
end

local function cstring(data, offset)
    local finish = data:find("\0", offset + 1, true)
    return data:sub(offset + 1, finish - 1), finish
end

local function uleb(data, p)
    local result, shift = 0, 0
    while true do
        local b = data:byte(p + 1)
        p = p + 1
        result = result | ((b & 0x7f) << shift)
        if b & 0x80 == 0 then
            return result, p
        end
        shift = shift + 7
    end
end

local function apply(data, edits)
    table.sort(edits, function (a, b) return a[1] < b[1] end)
    local pieces, at = {}, 0
    for _, edit in ipairs(edits) do
        table.insert(pieces, data:sub(at + 1, edit[1]))
        table.insert(pieces, edit[2])
        at = edit[1] + #edit[2]
    end
    table.insert(pieces, data:sub(at + 1))
    return table.concat(pieces)
end

local function commands(data, first)
    local ncmds = u32(data, 16)
    local offset = first
    local index = 0
    return function ()
        if index >= ncmds then
            return nil
        end
        index = index + 1
        local at = offset
        local cmd, cmdsize = string.unpack("<I4I4", data, at + 1)
        offset = offset + cmdsize
        return at, cmd, cmdsize
    end
end

function rename_sections(file, toxl)
    local rename = FORWARD
    if not toxl then
        rename = {}
        for name, renamed in pairs(FORWARD) do
            rename[renamed] = name
        end
    end
    local data = io.readfile(file, {encoding = "binary"})
    local magic = u32(data, 0)
    assert(magic == MH_MAGIC or magic == MH_MAGIC_64, string.format("0x%x", magic))
    local is64 = magic == MH_MAGIC_64
    local segment = is64 and LC_SEGMENT_64 or LC_SEGMENT
    local header = is64 and 72 or 56
    local size = is64 and 80 or 68
    local edits = {}
    for offset, cmd in commands(data, is64 and 32 or 28) do
        if cmd == segment then
            local nsects = u32(data, offset + (is64 and 64 or 48))
            local section = offset + header
            for _ = 1, nsects do
                local name = data:sub(section + 1, section + 16):gsub("\0+$", "")
                local renamed = rename[name]
                if renamed then
                    table.insert(edits, {section, renamed .. string.rep("\0", 16 - #renamed)})
                end
                section = section + size
            end
        end
    end
    io.writefile(file, apply(data, edits), {encoding = "binary"})
    return #edits
end

function weaken_classrefs(file, symbols)
    local want = {}
    for _, line in ipairs(symbols) do
        line = line:trim()
        if #line > 0 then
            want[line] = true
        end
    end
    local data = io.readfile(file, {encoding = "binary"})
    local magic = u32(data, 0)
    assert(magic == MH_MAGIC, string.format("expected a 32-bit (armv7) Mach-O, got 0x%x", magic))
    local symoff, nsyms, stroff = 0, 0, 0
    local info
    for offset, cmd in commands(data, 28) do
        if cmd == LC_SYMTAB then
            symoff, nsyms, stroff = string.unpack("<I4I4I4", data, offset + 8 + 1)
        elseif cmd == LC_DYLD_INFO or cmd == LC_DYLD_INFO_ONLY then
            info = {string.unpack("<I4I4I4I4I4I4I4I4I4I4", data, offset + 8 + 1)}
        end
    end
    local edits = {}
    local symbols_weakened = 0
    for index = 0, nsyms - 1 do
        local entry = symoff + index * 12
        local strx, kind, _, desc = string.unpack("<I4BBI2", data, entry + 1)
        if kind & 0x0e == 0 then
            local name = cstring(data, stroff + strx)
            if want[name] and desc & N_WEAK_REF == 0 then
                table.insert(edits, {entry + 6, string.pack("<I2", desc | N_WEAK_REF)})
                symbols_weakened = symbols_weakened + 1
            end
        end
    end
    local binds_weakened = 0
    if info then
        for _, stream in ipairs({{info[3], info[4]}, {info[5], info[6]}, {info[7], info[8]}}) do
            local p, finish = stream[1], stream[1] + stream[2]
            while p < finish do
                local b = data:byte(p + 1)
                local op, imm = b & 0xf0, b & 0x0f
                local at = p
                p = p + 1
                if op == 0x20 or op == 0x80 or op == 0xa0 or op == 0x60 or op == 0x70 then
                    local _
                    _, p = uleb(data, p)
                elseif op == 0xc0 then
                    local _
                    _, p = uleb(data, p)
                    _, p = uleb(data, p)
                elseif op == 0x40 then
                    local name, nul = cstring(data, p)
                    if want[name] and imm & BIND_SYMBOL_FLAGS_WEAK_IMPORT == 0 then
                        table.insert(edits, {at, string.char(0x40 | imm | BIND_SYMBOL_FLAGS_WEAK_IMPORT)})
                        binds_weakened = binds_weakened + 1
                    end
                    p = nul
                end
            end
        end
    end
    io.writefile(file, apply(data, edits), {encoding = "binary"})
    return symbols_weakened, binds_weakened
end

function unbind(input, output)
    local data = io.readfile(input, {encoding = "binary"})
    assert(u32(data, 0) == MH_MAGIC_64, "a thin arm64 image is expected")
    for offset, cmd in commands(data, 32) do
        if cmd == LC_DYLD_INFO or cmd == LC_DYLD_INFO_ONLY then
            io.writefile(output, apply(data, {{offset + 16, string.rep("\0", 24)}}), {encoding = "binary"})
            return
        end
    end
    raise("unbind: no LC_DYLD_INFO in %s", input)
end

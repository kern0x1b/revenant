import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local MAGIC32 = "\xce\xfa\xed\xfe"
local MAGIC64 = "\xcf\xfa\xed\xfe"
local FAT = "\xca\xfe\xba\xbe"
local FAT64 = "\xca\xfe\xba\xbf"

local ARM = 12
local ARM64 = 0x0100000C
local OBJECT = 1
local EXECUTABLE = 2
local CODE = 0x80000000 | 0x400
local THUMB_DEFINITION = 0x0008
local SECTION_TYPE = 0xFF
local LAZY_POINTERS = {[0x07] = true, [0x10] = true}
local SMALLEST_ARM64_PAGEZERO = 1 << 32

local LC_SEGMENT = 0x1
local LC_SYMTAB = 0x2
local LC_DYSYMTAB = 0xB
local LC_LOAD_DYLIB = 0xC
local LC_ID_DYLIB = 0xD
local LC_SUB_FRAMEWORK = 0x12
local LC_SUB_UMBRELLA = 0x13
local LC_SUB_LIBRARY = 0x15
local LC_LOAD_WEAK_DYLIB = 0x80000018
local LC_SEGMENT_64 = 0x19
local LC_REEXPORT_DYLIB = 0x8000001F
local LC_LINKER_OPTION = 0x2D
local LC_ENCRYPTION_INFO = 0x21
local LC_DYLD_INFO = 0x22
local LC_DYLD_INFO_ONLY = 0x80000022
local LC_DYLD_EXPORTS_TRIE = 0x80000033
local LC_DYLD_CHAINED_FIXUPS = 0x80000034
local LC_LAZY_LOAD_DYLIB = 0x20
local LC_UPWARD_DYLIB = 0x80000023
local LC_VERSION_MIN_IPHONEOS = 0x25
local LC_ENCRYPTION_INFO_64 = 0x2C
local LC_BUILD_VERSION = 0x32
local LC_FUNCTION_STARTS = 0x26
local LC_MAIN = 0x80000028

local LIBRARY_COMMANDS = {
    [LC_LOAD_DYLIB] = true, [LC_LOAD_WEAK_DYLIB] = true, [LC_REEXPORT_DYLIB] = true,
    [LC_LAZY_LOAD_DYLIB] = true, [LC_UPWARD_DYLIB] = true
}

local ARCHITECTURES = {[ARM] = {[6] = "armv6", [9] = "armv7", [11] = "armv7s"}, [ARM64] = {[0] = "arm64", [2] = "arm64e"}}

function waivable()
    return {"thumb-interworking", "pagezero", "entitlements", "weak-imports"}
end

function read(path)
    return io.readfile(path, {encoding = "binary"})
end

function is_macho(path)
    if os.islink(path) or not os.isfile(path) then
        return false
    end
    local file = io.open(path, "rb")
    local magic = file:read(4)
    file:close()
    return magic == MAGIC32 or magic == MAGIC64 or magic == FAT
end

function binaries_under(root)
    local found = {}
    for _, path in ipairs(os.files(path.join(root, "**"))) do
        if is_macho(path) then
            table.insert(found, path)
        end
    end
    byteorder.sort(found)
    return found
end

local function cstring(data, at)
    local finish = data:find("\0", at + 1, true)
    return data:sub(at + 1, finish - 1)
end

function image(data, base)
    local magic = data:sub(base + 1, base + 4)
    if magic ~= MAGIC32 and magic ~= MAGIC64 then
        raise("there is no Mach-O image at offset %d", base)
    end
    local wide = magic == MAGIC64
    local cputype, cpusubtype, filetype, ncmds, _, flags = string.unpack("<i4i4I4I4I4I4", data, base + 5)
    local found = {base = base, cputype = cputype, cpusubtype = cpusubtype & 0xFFFFFF, filetype = filetype, flags = flags,
                   wide = wide, segments = {}, sections = {}, libraries = {}, library_strength = {}, reexports = {},
                   sub_names = {}, commands = {}, linker_options = {}}
    local at = base + (wide and 32 or 28)
    for _ = 1, ncmds do
        local command, size = string.unpack("<I4I4", data, at + 1)
        table.insert(found.commands, command)
        if command == LC_SEGMENT or command == LC_SEGMENT_64 then
            local name, vmaddr, vmsize, fileoff, nsects, first, entry, layout
            if command == LC_SEGMENT_64 then
                name, vmaddr, vmsize, fileoff = string.unpack("<c16I8I8I8", data, at + 9)
                nsects = string.unpack("<I4", data, at + 9 + 56)
                first, entry, layout = at + 72, 80, "<c16c16I8I8I4I4I4I4I4I4I4"
            else
                name, vmaddr, vmsize, fileoff = string.unpack("<c16I4I4I4", data, at + 9)
                nsects = string.unpack("<I4", data, at + 9 + 40)
                first, entry, layout = at + 56, 68, "<c16c16I4I4I4I4I4I4I4I4I4"
            end
            table.insert(found.segments, {name = name:gsub("%z+$", ""), vmaddr = vmaddr, vmsize = vmsize, fileoff = fileoff})
            for index = 0, nsects - 1 do
                local sectname, segname, addr, sectsize, _, _, reloff, nreloc, flags, reserved1, reserved2 = string.unpack(layout, data, first + index * entry + 1)
                table.insert(found.sections, {name = sectname:gsub("%z+$", ""), segment = segname:gsub("%z+$", ""), addr = addr, size = sectsize, flags = flags, reserved1 = reserved1, reserved2 = reserved2,
                                              reloff = reloff, nreloc = nreloc})
            end
        elseif command == LC_SYMTAB then
            found.symtab = {string.unpack("<I4I4I4I4", data, at + 9)}
        elseif command == LC_DYLD_INFO or command == LC_DYLD_INFO_ONLY then
            found.rebase = {string.unpack("<I4I4", data, at + 9)}
            found.bind = {string.unpack("<I4I4", data, at + 17)}
            found.weak_bind = {string.unpack("<I4I4", data, at + 25)}
            found.lazy_bind = {string.unpack("<I4I4", data, at + 33)}
            found.export_trie = found.export_trie or {string.unpack("<I4I4", data, at + 41)}
        elseif command == LC_DYLD_CHAINED_FIXUPS then
            found.chained_fixups = true
        elseif command == LC_DYLD_EXPORTS_TRIE then
            found.export_trie = {string.unpack("<I4I4", data, at + 9)}
        elseif command == LC_DYSYMTAB then
            found["local"] = {string.unpack("<I4I4", data, at + 73)}
            found.external = {string.unpack("<I4I4", data, at + 17)}
            found.indirect = {string.unpack("<I4I4", data, at + 57)}
        elseif command == LC_FUNCTION_STARTS then
            found.function_starts = {string.unpack("<I4I4", data, at + 9)}
        elseif command == LC_MAIN then
            found.entryoff = string.unpack("<I8", data, at + 9)
            found.entryoff_at = at + 8
        elseif command == LC_SUB_FRAMEWORK then
            found.umbrella = cstring(data, at + string.unpack("<I4", data, at + 9))
        elseif command == LC_SUB_UMBRELLA or command == LC_SUB_LIBRARY then
            table.insert(found.sub_names, cstring(data, at + string.unpack("<I4", data, at + 9)))
        elseif command == LC_LINKER_OPTION then
            local count, arguments, cursor = string.unpack("<I4", data, at + 9), {}, at + 12
            for _ = 1, count do
                local text = cstring(data, cursor)
                table.insert(arguments, text)
                cursor = cursor + #text + 1
            end
            table.insert(found.linker_options, arguments)
        elseif command == LC_ID_DYLIB then
            found.identity = cstring(data, at + string.unpack("<I4", data, at + 9))
        elseif LIBRARY_COMMANDS[command] then
            table.insert(found.libraries, cstring(data, at + string.unpack("<I4", data, at + 9)))
            table.insert(found.library_strength, command == LC_LOAD_DYLIB or command == LC_REEXPORT_DYLIB)
            if command == LC_REEXPORT_DYLIB then
                table.insert(found.reexports, found.libraries[#found.libraries])
            end
        elseif command == LC_VERSION_MIN_IPHONEOS then
            found.minimum = string.unpack("<I4", data, at + 9)
        elseif command == LC_BUILD_VERSION then
            found.minimum = string.unpack("<I4", data, at + 13)
        end
        at = at + size
    end
    found.architecture = (ARCHITECTURES[cputype] or {})[found.cpusubtype] or tostring(cputype)
    return found
end

function archive_members(data)
    local members = {}
    local at = 8
    while at + 60 <= #data do
        local header = data:sub(at + 1, at + 60)
        local name = header:sub(1, 16):trim()
        local size = tonumber(header:sub(49, 58):trim())
        local body = at + 60
        local start = body
        if name:startswith("#1/") then
            local length = tonumber(name:sub(4))
            name = data:sub(body + 1, body + length):gsub("%z+$", "")
            start = body + length
        end
        if not name:startswith("__.SYMDEF") then
            table.insert(members, {name = name, offset = start})
        end
        at = body + size + (size % 2)
    end
    return members
end

function recorded_minimums(file, architecture)
    local data = read(file)
    local found = {}
    local function collect(label, base)
        local magic = data:sub(base + 1, base + 4)
        if magic == FAT then
            local count = string.unpack(">I4", data, base + 5)
            for index = 0, count - 1 do
                local _, _, offset = string.unpack(">i4i4I4", data, base + 9 + index * 20)
                collect(label, base + offset)
            end
        elseif magic == MAGIC32 or magic == MAGIC64 then
            local described = image(data, base)
            if described.architecture == architecture then
                table.insert(found, {member = label, minimum = described.minimum})
            end
        end
    end
    if data:startswith("!<arch>\n") then
        for _, member in ipairs(archive_members(data)) do
            collect(member.name, member.offset)
        end
    else
        collect(nil, 0)
    end
    return found
end

function images(data)
    local magic = data:sub(1, 4)
    if magic == FAT or magic == FAT64 then
        local count = string.unpack(">I4", data, 5)
        local found = {}
        for index = 0, count - 1 do
            local _, _, offset
            if magic == FAT64 then
                _, _, offset = string.unpack(">i4i4I8", data, 9 + index * 32)
            else
                _, _, offset = string.unpack(">i4i4I4", data, 9 + index * 20)
            end
            if data:sub(offset + 1, offset + 8) ~= "!<arch>\n" then
                table.insert(found, image(data, offset))
            end
        end
        return found
    end
    return {image(data, 0)}
end

local function uleb(data, at)
    local value, shift = 0, 0
    while true do
        local byte = data:byte(at + 1)
        at = at + 1
        value = value | ((byte & 0x7F) << shift)
        shift = shift + 7
        if byte < 0x80 then
            return value, at
        end
    end
end

function weak_bindings(data, found)
    local bindings, order = {}, {}
    if not found.weak_bind or found.weak_bind[2] == 0 then
        return order
    end
    local at = found.base + found.weak_bind[1]
    local finish = at + found.weak_bind[2]
    local current
    while at < finish do
        local byte = data:byte(at + 1)
        at = at + 1
        local opcode, immediate = byte & 0xF0, byte & 0x0F
        if opcode == 0x40 then
            local name = cstring(data, at)
            at = at + #name + 1
            current = bindings[name]
            if not current then
                current = {name = name, overrides = false, bound = false}
                bindings[name] = current
                table.insert(order, current)
            end
            current.overrides = current.overrides or (immediate & 0x8) ~= 0
        elseif opcode == 0x60 then
            repeat
                byte = data:byte(at + 1)
                at = at + 1
            until byte < 0x80
        elseif opcode == 0x70 or opcode == 0x80 then
            _, at = uleb(data, at)
        elseif opcode == 0x90 or opcode == 0xB0 then
            if current then
                current.bound = true
            end
        elseif opcode == 0xA0 then
            _, at = uleb(data, at)
            if current then
                current.bound = true
            end
        elseif opcode == 0xC0 then
            _, at = uleb(data, at)
            _, at = uleb(data, at)
            if current then
                current.bound = true
            end
        end
    end
    return order
end

function bound_slots(data, found)
    local slots = {}
    local pointer = found.wide and 8 or 4
    for _, stream in ipairs({found.bind, found.lazy_bind, found.weak_bind}) do
        if stream and stream[2] > 0 then
            local at, finish = found.base + stream[1], found.base + stream[1] + stream[2]
            local name, address = nil, nil
            local function bind()
                if name and address then
                    slots[address] = name
                    address = address + pointer
                end
            end
            while at < finish do
                local byte = data:byte(at + 1)
                at = at + 1
                local opcode, immediate = byte & 0xF0, byte & 0x0F
                if opcode == 0x00 then
                    name, address = nil, nil
                elseif opcode == 0x20 or opcode == 0x50 or opcode == 0x60 then
                    if opcode ~= 0x50 then
                        _, at = uleb(data, at)
                    end
                elseif opcode == 0x40 then
                    name = cstring(data, at)
                    at = at + #name + 1
                elseif opcode == 0x70 then
                    local offset
                    offset, at = uleb(data, at)
                    local segment = found.segments[immediate + 1]
                    address = segment and (segment.vmaddr + offset) or nil
                elseif opcode == 0x80 then
                    local delta
                    delta, at = uleb(data, at)
                    address = address and (address + delta) or nil
                elseif opcode == 0x90 then
                    bind()
                elseif opcode == 0xA0 then
                    local delta
                    delta, at = uleb(data, at)
                    bind()
                    address = address and (address + delta) or nil
                elseif opcode == 0xB0 then
                    bind()
                    address = address and (address + immediate * pointer) or nil
                elseif opcode == 0xC0 then
                    local count, skip
                    count, at = uleb(data, at)
                    skip, at = uleb(data, at)
                    for _ = 1, count do
                        bind()
                        address = address and (address + skip) or nil
                    end
                end
            end
        end
    end
    if found.filetype == OBJECT and found.symtab then
        local symoff, stroff = found.symtab[1], found.symtab[3]
        local entry = found.wide and 16 or 12
        for _, section in ipairs(found.sections) do
            for index = 0, (section.nreloc or 0) - 1 do
                local address, info = string.unpack("<i4I4", data, found.base + section.reloff + index * 8 + 1)
                local external, length, pcrel, kind = (info >> 27) & 1, (info >> 25) & 3, (info >> 24) & 1, info >> 28
                if address >= 0 and external == 1 and pcrel == 0 and kind == 0 and (1 << length) == pointer then
                    local strx = string.unpack("<I4", data, found.base + symoff + (info & 0xFFFFFF) * entry + 1)
                    slots[section.addr + address] = cstring(data, found.base + stroff + strx)
                end
            end
        end
    end
    return slots
end

function rebased_slots(data, found)
    local segments = found.segments
    local slots = {}
    if found.rebase and found.rebase[2] ~= 0 then
        local offset, size = found.rebase[1], found.rebase[2]
        local at, finish = found.base + offset, found.base + offset + size
        local kind, segment, address, width = 1, 0, 0, found.wide and 8 or 4
        while at < finish do
            local byte = data:byte(at + 1)
            at = at + 1
            local opcode, immediate = byte & 0xF0, byte & 0x0F
            if opcode == 0x00 then
                break
            elseif opcode == 0x10 then
                kind = immediate
            elseif opcode == 0x20 then
                segment = immediate
                address, at = uleb(data, at)
            elseif opcode == 0x30 then
                local step
                step, at = uleb(data, at)
                address = address + step
            elseif opcode == 0x40 then
                address = address + immediate * width
            elseif opcode >= 0x50 and opcode <= 0x80 then
                local times, skip = 1, 0
                if opcode == 0x50 then
                    times = immediate
                elseif opcode == 0x60 then
                    times, at = uleb(data, at)
                elseif opcode == 0x70 then
                    skip, at = uleb(data, at)
                else
                    times, at = uleb(data, at)
                    skip, at = uleb(data, at)
                end
                for _ = 1, times do
                    if kind == 1 or kind == 2 then
                        local described = segments[segment + 1]
                        table.insert(slots, {described.vmaddr + address, found.base + described.fileoff + address})
                    end
                    address = address + width + skip
                end
            else
                raise("rebase opcode %#x is not one this toolchain reads", byte)
            end
        end
    elseif found["local"] and found["local"][2] ~= 0 and not found.wide then
        local offset, count = found["local"][1], found["local"][2]
        local relocated = segments[1].vmaddr
        for index = 0, count - 1 do
            local address, info = string.unpack("<I4I4", data, found.base + offset + index * 8 + 1)
            local kind, length
            if address & 0x80000000 ~= 0 then
                kind, length, address = (address >> 24) & 0xF, (address >> 28) & 0x3, address & 0xFFFFFF
            else
                kind, length = (info >> 28) & 0xF, (info >> 25) & 0x3
            end
            if kind == 0 and length == 2 then
                local vmaddr = relocated + address
                for _, described in ipairs(segments) do
                    if described.vmaddr <= vmaddr and vmaddr < described.vmaddr + described.vmsize then
                        table.insert(slots, {vmaddr, found.base + described.fileoff + vmaddr - described.vmaddr})
                    end
                end
            end
        end
    end
    return slots
end

local function each_symbol(data, found, callback)
    if not found.symtab then
        return
    end
    local symoff, nsyms, stroff = found.symtab[1], found.symtab[2], found.symtab[3]
    local entry = found.wide and 16 or 12
    local layout = found.wide and "<I4BBI2I8" or "<I4BBI2I4"
    for index = 0, nsyms - 1 do
        local strx, kind, section, desc, value = string.unpack(layout, data, found.base + symoff + index * entry + 1)
        callback(cstring(data, found.base + stroff + strx), kind, section, desc, value)
    end
end

function symbol(data, found, wanted)
    local address
    each_symbol(data, found, function (name, kind, section, desc, value)
        if name == wanted and kind & 0xE0 == 0 and kind & 0x0E ~= 0 then
            address = address or value
        end
    end)
    return address
end

function code_symbols(data, found)
    local code = {}
    for index, section in ipairs(found.sections) do
        if section.flags & CODE ~= 0 then
            code[index] = true
        end
    end
    local symbols = {}
    each_symbol(data, found, function (name, kind, section, desc, value)
        if kind & 0xE0 == 0 and kind & 0x0E == 0x0E and code[section] then
            local key = value & ~1
            symbols[key] = symbols[key] or {}
            table.insert(symbols[key], {thumb = desc & THUMB_DEFINITION ~= 0, name = name})
        end
    end)
    return symbols
end

local function within(ranges, address)
    for _, range in ipairs(ranges) do
        if range[1] <= address and address < range[2] then
            return true
        end
    end
    return false
end

function interworking_problems(binary)
    local data = read(binary)
    local problems, checked, into_code = {}, 0, 0
    for _, found in ipairs(images(data)) do
        if found.cputype == ARM then
            local symbols = code_symbols(data, found)
            local code, lazy = {}, {}
            for _, section in ipairs(found.sections) do
                local range = {section.addr, section.addr + section.size}
                if section.flags & CODE ~= 0 then
                    table.insert(code, range)
                end
                if LAZY_POINTERS[section.flags & SECTION_TYPE] then
                    table.insert(lazy, range)
                end
            end
            for _, slot in ipairs(rebased_slots(data, found)) do
                if not within(lazy, slot[1]) then
                    local pointer = string.unpack("<I4", data, slot[2] + 1)
                    if within(code, pointer & ~1) then
                        into_code = into_code + 1
                        local described = symbols[pointer & ~1]
                        local modes = {}
                        for _, symbol in ipairs(described or {}) do
                            modes[symbol.thumb] = true
                        end
                        if described and not (modes[true] and modes[false]) then
                            checked = checked + 1
                            local thumb = described[1].thumb
                            local names = {}
                            for _, symbol in ipairs(described) do
                                table.insert(names, symbol.name)
                            end
                            byteorder.sort(names)
                            if thumb and pointer & 1 == 0 then
                                table.insert(problems, string.format("the pointer at %#x to Thumb function %s lacks bit 0, so a call through it enters Thumb code in ARM state; the linker dropped it", slot[1], names[1]))
                            elseif not thumb and pointer & 1 ~= 0 then
                                table.insert(problems, string.format("the pointer at %#x to ARM function %s has bit 0 set, so a call through it enters ARM code in Thumb state; something rewrote it after the link", slot[1], names[1]))
                            end
                        end
                    end
                end
            end
        end
    end
    return problems, checked, into_code
end

function pagezero_problems(binary)
    local problems = {}
    for _, found in ipairs(images(read(binary))) do
        if found.filetype == EXECUTABLE and (found.cputype == ARM or found.cputype == ARM64) then
            local named = {}
            for _, segment in ipairs(found.segments) do
                named[segment.name] = segment
            end
            local zero, text = named.__PAGEZERO, named.__TEXT
            if not zero or not text then
                table.insert(problems, "an executable without __PAGEZERO and __TEXT does not map the way iOS expects")
            elseif found.cputype == ARM64 and zero.vmsize < SMALLEST_ARM64_PAGEZERO then
                table.insert(problems, string.format("the arm64 __PAGEZERO is %#x, and a 64-bit iOS executable needs at least %#x; nothing should pass -pagezero_size", zero.vmsize, SMALLEST_ARM64_PAGEZERO))
            elseif found.cputype == ARM and text.vmaddr ~= zero.vmaddr + zero.vmsize then
                table.insert(problems, string.format("__PAGEZERO ends at %#x and __TEXT starts at %#x; the gap is what a post-link edit of the segment leaves", zero.vmaddr + zero.vmsize, text.vmaddr))
            end
        end
    end
    return problems
end

function entry_problems(binary)
    local problems = {}
    local data = read(binary)
    for _, found in ipairs(images(data)) do
        if found.entryoff and found.cputype == ARM then
            local text
            for _, segment in ipairs(found.segments) do
                if segment.name == "__TEXT" then
                    text = segment
                end
            end
            local entry = text and text.vmaddr - text.fileoff + found.entryoff
            local named, thumb, arm = nil, false, false
            for _, symbol in ipairs(entry and code_symbols(data, found)[entry & ~1] or {}) do
                named = named or symbol.name
                thumb = thumb or symbol.thumb
                arm = arm or not symbol.thumb
            end
            if thumb and not arm and entry & 1 == 0 then
                table.insert(problems, string.format("the LC_MAIN entry %#x lands on Thumb function %s without bit 0, so dyld calls it in ARM state, where its first halfword is undefined; the linker dropped the Thumb bit", entry, named))
            end
        end
    end
    return problems
end

local LOADED = {[6] = true, [8] = true}

function encrypted(binary)
    for _, found in ipairs(images(read(binary))) do
        for _, command in ipairs((found.cputype == ARM and LOADED[found.filetype]) and found.commands or {}) do
            if command == LC_ENCRYPTION_INFO or command == LC_ENCRYPTION_INFO_64 then
                return true
            end
        end
    end
    return false
end

function version_text(encoded)
    if not encoded then
        return "none"
    end
    local text = string.format("%d.%d", encoded >> 16, (encoded >> 8) & 0xFF)
    if encoded & 0xFF ~= 0 then
        text = text .. "." .. (encoded & 0xFF)
    end
    return text
end

function encoded_version(text)
    local parts = {}
    for part in tostring(text):gmatch("%d+") do
        table.insert(parts, tonumber(part))
    end
    return ((parts[1] or 0) << 16) | ((parts[2] or 0) << 8) | (parts[3] or 0)
end

function system_imports(data, found)
    local imported = {}
    each_symbol(data, found, function (name, kind, section, desc)
        if kind & 0xE0 == 0 and kind & 0x0E == 0 and kind & 0x01 ~= 0 then
            local ordinal = (desc >> 8) & 0xFF
            local library = found.libraries[ordinal]
            if library and path.filename(library):startswith("libSystem.") and name:startswith("_") then
                imported[name:sub(2)] = {weak = desc & 0x40 ~= 0}
            end
        end
    end)
    return imported
end

function late_imports(binary, arrived, process_wide)
    local data = read(binary)
    local strong, weak = {}, {}
    for _, found in ipairs(images(data)) do
        if not found.minimum then
            raise("the %s slice of %s records no minimum release, so nothing says which system calls it may import", found.architecture, binary)
        end
        local imported = system_imports(data, found)
        local names = table.orderkeys(imported)
        for _, symbol in ipairs(names) do
            local release = arrived[symbol]
            if release and found.minimum < encoded_version(release) then
                local remedy = (process_wide or {})[symbol] and "link revenant@libcxx, whose libc++abi exports it once for the process" or ("link apple-compat::" .. symbol)
                local described = string.format("%s: %s arrived in %s, after %s; %s", found.architecture, symbol, release, version_text(found.minimum), remedy)
                table.insert(imported[symbol].weak and weak or strong, described)
            end
        end
    end
    return strong, weak
end

function verify(binary, opt)
    opt = opt or {}
    local waived = opt.waived or {}
    local problems = {}
    if waived["thumb-interworking"] then
        wprint("%s: thumb-interworking not checked: %s", binary, waived["thumb-interworking"])
    else
        local found, checked, into_code = interworking_problems(binary)
        table.join2(problems, found)
        if into_code > 0 and checked == 0 and not opt.stripped then
            table.insert(problems, string.format("none of its %d rebased code pointers names a function in its symbol table, so no pointer's mode could be checked; it arrived stripped, and the check has to see it before strip", into_code))
        end
        vprint("%s: %d of %d rebased code pointers name a function in the symbol table and match its mode", path.filename(binary), checked, into_code)
    end
    if waived.pagezero then
        wprint("%s: pagezero not checked: %s", binary, waived.pagezero)
    else
        table.join2(problems, pagezero_problems(binary))
    end
    table.join2(problems, entry_problems(binary))
    if encrypted(binary) then
        table.insert(problems, "a linker stamped LC_ENCRYPTION_INFO on a 32-bit ARM library, and only an executable carries that command: ld64 makes a library or a bundle encryptable from iOS 7.0 on (rdar://16293398, ld64/src/ld/Options.cpp), so link it with -Wl,-no_encryption")
    end
    if opt.arrived then
        local strong, weak = late_imports(binary, opt.arrived, opt.process_wide)
        if #strong > 0 then
            table.insert(problems, "it imports what its minimum release does not have, so dyld refuses to load it there: " .. table.concat(strong, "; "))
        end
        if waived["weak-imports"] then
            wprint("%s: weak-imports not checked: %s", binary, waived["weak-imports"])
        elseif #weak > 0 then
            table.insert(problems, "it weakly imports what its minimum release does not have, so a call jumps to NULL there: " .. table.concat(weak, "; "))
        end
    end
    if #problems > 0 then
        local shown = table.slice(problems, 1, 5)
        local more = #problems > 5 and string.format("; and %d more", #problems - 5) or ""
        raise("%s is not what the platform runs: %s%s", binary, table.concat(shown, "; "), more)
    end
end

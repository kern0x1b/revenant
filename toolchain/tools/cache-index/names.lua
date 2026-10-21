local dyld = import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local macho = import("apple.macho", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local WANTED = {__objc_methname = true, __objc_classname = true, __objc_methtype = true, __cstring = true}

function main(source, architecture)
    assert(source, "usage: ./xmakew l toolchain/tools/cache-index/names.lua SOURCE [ARCHITECTURE]")

    local CONTROL = "[%z\1-\31\127]"

    local names, counted, rejected, whitespace = {}, 0, 0, 0

    local function keep(name)
        if #name > 0 then
            if name:find(CONTROL) then
                rejected = rejected + 1
            elseif name:find("^ +$") then
                whitespace = whitespace + 1
            elseif not names[name] then
                names[name] = true
                counted = counted + 1
            end
        end
    end

    local function take_runs(bytes)
        for run in bytes:gmatch("([^%z]+)") do
            keep(run)
        end
    end

    local function take_class_runs(bytes)
        for run in bytes:gmatch("([^%z]+)") do
            keep(run)
            keep("_OBJC_CLASS_$_" .. run)
            keep("_OBJC_METACLASS_$_" .. run)
        end
    end

    local function fetch_string(fetch, offset)
        local pieces, at = {}, offset
        while true do
            local byte = fetch(at, 1):byte(1)
            if not byte or byte == 0 then
                break
            end
            pieces[#pieces + 1] = string.char(byte)
            at = at + 1
        end
        return table.concat(pieces)
    end

    local function take_symtab(fetch, image)
        if not image.symtab then
            return
        end
        local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
        if not nsyms or nsyms <= 0 or not stroff or not symoff then
            return
        end
        local linkedit
        for _, segment in ipairs(image.segments) do
            if segment.name == "__LINKEDIT" then
                linkedit = segment
            end
        end
        if not linkedit then
            return
        end
        local at = function (offset) return linkedit.vmaddr + (offset - linkedit.fileoff) end
        local entry = image.wide and 16 or 12
        local table_bytes = fetch(at(symoff), nsyms * entry)
        for index = 0, nsyms - 1 do
            local strx, kind = string.unpack("<I4B", table_bytes, index * entry + 1)
            if strx ~= 0 and kind & 0xE0 == 0 and kind & 0x01 ~= 0 and kind & 0x0E ~= 0 then
                keep(fetch_string(fetch, at(stroff + strx)))
            end
        end
    end


    local function sections_of(image, fetch)
        for _, section in ipairs(image.sections) do
            if WANTED[section.name] then
                local bytes = fetch(section.addr, section.size)
                if section.name == "__objc_classname" then
                    take_class_runs(bytes)
                else
                    take_runs(bytes)
                end
            end
        end
    end

    if os.isdir(source) then
        for _, binary in ipairs(macho.binaries_under(source)) do
            local data = macho.read(binary)
            for _, found in ipairs(macho.images(data)) do
                if not architecture or found.architecture == architecture then
                    local function fetch(address, size)
                        for _, segment in ipairs(found.segments) do
                            if segment.vmaddr <= address and address + size <= segment.vmaddr + segment.vmsize then
                                local at = found.base + segment.fileoff + (address - segment.vmaddr)
                                return data:sub(at + 1, at + size)
                            end
                        end
                    end
                    sections_of(found, fetch)
                    take_symtab(fetch, found)
                end
            end
        end
    else
        local cache = dyld.open_cache(source)
        local function fetch(address, size)
            return cache.read_address(address, size)
        end
        for _, entry in ipairs(cache.images) do
            sections_of(entry.image, fetch)
            take_symtab(fetch, entry.image)
        end
        cache.close()
    end

    for name in pairs(dyld.load(source).exports) do
        keep(name)
    end

    local sorted = table.keys(names)
    byteorder.sort(sorted)
    for _, name in ipairs(sorted) do
        io.write(name, "\n")
    end
    io.stderr:write(string.format("names.lua: %d names (%d runs with a control byte, %d runs of spaces, neither a name) from %s\n",
                                  counted, rejected, whitespace, source))
end

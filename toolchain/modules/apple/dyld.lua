import("core.base.option")
import("macho")
import("compat")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local caches = {}

local function cstring(data, at)
    local finish = data:find("\0", at + 1, true)
    return data:sub(at + 1, finish - 1)
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

function root()
    return path.join(os.getenv("REVENANT_HOME") or path.join(os.getenv("HOME"), ".revenant"), "dyld")
end

local function parts(version)
    local found = {}
    for part in tostring(version):gmatch("%d+") do
        table.insert(found, tonumber(part))
    end
    return found
end

local function compare(a, b)
    local left, right = parts(a), parts(b)
    for index = 1, math.max(#left, #right) do
        local x, y = left[index] or 0, right[index] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

function compare_versions(a, b)
    return compare(a, b)
end

function outside_source(folder, architecture)
    return path.join(folder, "outside_" .. architecture)
end

function held_source(folder, architecture)
    local cache = path.join(folder, "dyld_shared_cache_" .. architecture)
    if os.isfile(cache) then
        return cache
    end
    local libraries = path.join(folder, "libraries_" .. architecture)
    if os.isdir(libraries) then
        return libraries
    end
end

function held_releases(architecture)
    local releases = {}
    for _, folder in ipairs(os.dirs(path.join(root(), "*"))) do
        local release = path.filename(folder)
        if release:match("^%d+[%.%d]*$") and held_source(folder, architecture) then
            table.insert(releases, release)
        end
    end
    table.sort(releases, function (a, b) return compare(a, b) < 0 end)
    return releases
end

function held_ladder(preferred)
    local candidates = table.join(preferred, {"arm64", "arm64e"})
    local ladder = {}
    for _, folder in ipairs(os.dirs(path.join(root(), "*"))) do
        local release = path.filename(folder)
        if release:match("^%d+[%.%d]*$") then
            for _, architecture in ipairs(candidates) do
                local source = held_source(folder, architecture)
                if source then
                    table.insert(ladder, {release = release, architecture = architecture, source = source})
                    break
                end
            end
        end
    end
    table.sort(ladder, function (a, b) return compare(a.release, b.release) < 0 end)
    return ladder
end

local function loaded_image(found, architecture)
    local wanted = architecture == "armv7s" and {"armv7s", "armv7"} or {architecture}
    for _, candidate in ipairs(wanted) do
        for _, image in ipairs(found) do
            if image.architecture == candidate then
                return image
            end
        end
    end
end

local function defined_exports(data, image, linkedit)
    local defined = {}
    if not image.symtab then
        return defined
    end
    local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
    local first, last = 0, nsyms - 1
    if image.external and image.external[2] > 0 then
        first, last = image.external[1], image.external[1] + image.external[2] - 1
    end
    local entry = image.wide and 16 or 12
    for index = first, last do
        local strx, kind = string.unpack("<I4B", data, linkedit + symoff + index * entry + 1)
        if kind & 0xE0 == 0 and kind & 0x01 ~= 0 and kind & 0x0E ~= 0 then
            defined[cstring(data, linkedit + stroff + strx)] = true
        end
    end
    return defined
end

local function trie_payloads(data)
    local payloads = {}
    local stack = {{0, ""}}
    while #stack > 0 do
        local node = table.remove(stack)
        local cursor = node[1]
        local terminal
        terminal, cursor = uleb(data, cursor)
        if terminal ~= 0 then
            payloads[node[2]] = cursor
        end
        cursor = cursor + terminal
        local children = data:byte(cursor + 1)
        cursor = cursor + 1
        for _ = 1, children do
            local finish = data:find("\0", cursor + 1, true)
            local label = data:sub(cursor + 1, finish - 1)
            local child
            child, cursor = uleb(data, finish)
            table.insert(stack, {child, node[2] .. label})
        end
    end
    return payloads
end

local function trie_exports(data, offset, size)
    local exports = {}
    if size > 0 then
        for name in pairs(trie_payloads(data:sub(offset + 1, offset + size))) do
            exports[name] = true
        end
    end
    return exports
end

local function single_reexports(data, image)
    local found = {}
    if not image.export_trie or image.export_trie[2] == 0 then
        return found
    end
    local trie = data:sub(image.base + image.export_trie[1] + 1, image.base + image.export_trie[1] + image.export_trie[2])
    for name, cursor in pairs(trie_payloads(trie)) do
        local flags
        flags, cursor = uleb(trie, cursor)
        if flags & 0x08 ~= 0 then
            local ordinal
            ordinal, cursor = uleb(trie, cursor)
            local imported = cstring(trie, cursor)
            table.insert(found, {name = name, ordinal = ordinal, imported = imported ~= "" and imported or name})
        end
    end
    table.sort(found, function (a, b) return byteorder.less(a.name, b.name) end)
    return found
end

local function library_of(data, image, linkedit)
    local exports
    if image.export_trie and image.export_trie[2] ~= 0 then
        exports = trie_exports(data, linkedit + image.export_trie[1], image.export_trie[2])
    else
        exports = defined_exports(data, image, linkedit)
    end
    return {exports = exports, dependents = image.libraries, reexports = image.reexports, umbrella = image.umbrella, sub_names = image.sub_names}
end

local function leaf(install)
    local name = path.filename(install)
    return name:match("^([^%.]+)") or name
end

local function assemble(architecture, libraries)
    local exports, images, count = {}, {}, 0
    for install, library in pairs(libraries) do
        images[install] = true
        for name in pairs(library.exports) do
            if not exports[name] then
                exports[name] = true
                count = count + 1
            end
        end
    end
    for install, library in pairs(libraries) do
        local reexported = table.copy(library.reexports)
        local subs = {}
        for _, name in ipairs(library.sub_names) do
            subs[name] = true
        end
        local umbrella = leaf(install):gsub("^lib", "")
        for _, dependent in ipairs(library.dependents) do
            local other = libraries[dependent]
            if other and (other.umbrella == umbrella or subs[leaf(dependent)]) then
                table.insert(reexported, dependent)
            end
        end
        library.reexports = reexported
    end
    return {architecture = architecture, exports = exports, images = images, libraries = libraries, count = count}
end

local function read_libraries(folder, architecture, libraries, keep, by_path)
    for _, binary in ipairs(macho.binaries_under(folder)) do
        local data = macho.read(binary)
        local image = loaded_image(macho.images(data), architecture)
        local name = image and image.identity and (by_path and ("/" .. path.relative(binary, folder)) or image.identity)
        if name and not (keep and keep[name]) then
            libraries[name] = library_of(data, image, image.base)
        end
    end
end

local function load_libraries(folder)
    local architecture = path.filename(folder):match("^libraries_(.+)$")
    local libraries = {}
    read_libraries(folder, architecture, libraries)
    local loaded = assemble(architecture, libraries)
    if loaded.count == 0 then
        raise("%s holds no %s library exporting anything", folder, architecture)
    end
    return loaded
end

local function cache_files(mainfile)
    local files, mappings = {}, {}
    local function open(filename)
        local handle = io.open(filename, "rb")
        if not handle then
            raise("%s is missing: the shared cache %s names it as one of its files", filename, mainfile)
        end
        local file = {path = filename, handle = handle, size = handle:seek("end")}
        table.insert(files, file)
        return file
    end
    local block_size = 65536
    local function read_direct(file, offset, size)
        file.handle:seek("set", offset)
        local bytes = size > 0 and file.handle:read(size) or ""
        if not bytes or #bytes ~= size then
            raise("%s ends before offset %#x + %#x", file.path, offset, size)
        end
        return bytes
    end
    local function read(file, offset, size)
        if size > block_size // 4 then
            return read_direct(file, offset, size)
        end
        file.blocks = file.blocks or {}
        local pieces = {}
        local remaining, at = size, offset
        while remaining > 0 do
            local index = at // block_size
            local block = file.blocks[index]
            if not block then
                local start = index * block_size
                if start >= file.size then
                    raise("%s ends before offset %#x + %#x", file.path, offset, size)
                end
                file.handle:seek("set", start)
                block = file.handle:read(math.min(block_size, file.size - start)) or ""
                file.block_count = (file.block_count or 0) + 1
                if file.block_count > 1024 then
                    file.blocks, file.block_count = {}, 1
                end
                file.blocks[index] = block
            end
            local inner = at - index * block_size
            local piece = block:sub(inner + 1, math.min(#block, inner + remaining))
            if #piece == 0 then
                raise("%s ends before offset %#x + %#x", file.path, offset, size)
            end
            table.insert(pieces, piece)
            remaining = remaining - #piece
            at = at + #piece
        end
        return #pieces == 1 and pieces[1] or table.concat(pieces)
    end
    local function add_mappings(file)
        local header = read(file, 0, 32)
        if not header:startswith("dyld_v1") then
            raise("%s is not a dyld shared cache", file.path)
        end
        local mapping_offset, mapping_count = string.unpack("<I4I4", header, 17)
        file.mapping_offset = mapping_offset
        file.header = read(file, 0, mapping_offset)
        local table_bytes = read(file, mapping_offset, mapping_count * 32)
        for index = 0, mapping_count - 1 do
            local address, size, offset = string.unpack("<I8I8I8", table_bytes, index * 32 + 1)
            table.insert(mappings, {address = address, size = size, offset = offset, file = file})
        end
    end
    local main = open(mainfile)
    add_mappings(main)
    local function field(file, offset, format)
        if file.mapping_offset >= offset + string.packsize(format) then
            return string.unpack(format, file.header, offset + 1)
        end
    end
    local subcache_offset, subcache_count = field(main, 0x188, "<I4"), field(main, 0x18c, "<I4")
    if subcache_count and subcache_count > 0 then
        local wide = main.mapping_offset > 0x1c8
        local entry_size = wide and 56 or 24
        local entries = read(main, subcache_offset, subcache_count * entry_size)
        local base = mainfile:gsub("%.development$", "")
        for index = 0, subcache_count - 1 do
            local entry = entries:sub(index * entry_size + 1, (index + 1) * entry_size)
            local suffix = wide and entry:sub(25, 56):gsub("%z.*$", "") or ("." .. (index + 1))
            local file = open(base .. suffix)
            add_mappings(file)
            if file.header:sub(0x58 + 1, 0x68) ~= entry:sub(1, 16) then
                raise("%s is not the subcache %s expects: its UUID differs", file.path, mainfile)
            end
        end
    end
    local function locate(address, size)
        for _, mapping in ipairs(mappings) do
            if mapping.address <= address and address + size <= mapping.address + mapping.size then
                return mapping.file, address - mapping.address + mapping.offset
            end
        end
        raise("address %#x is outside every mapping of %s", address, mainfile)
    end
    local function read_address(address, size)
        local file, offset = locate(address, size)
        return read(file, offset, size)
    end
    local function string_at(address)
        local collected = {}
        while true do
            local file, offset = locate(address, 1)
            local mapping_end
            for _, mapping in ipairs(mappings) do
                if mapping.address <= address and address < mapping.address + mapping.size then
                    mapping_end = mapping.address + mapping.size
                end
            end
            local chunk = read(file, offset, math.min(256, mapping_end - address))
            local finish = chunk:find("\0", 1, true)
            if finish then
                table.insert(collected, chunk:sub(1, finish - 1))
                return table.concat(collected)
            end
            table.insert(collected, chunk)
            address = address + #chunk
        end
    end
    local function close()
        for _, file in ipairs(files) do
            file.handle:close()
        end
    end
    local slides = {}
    local function slide_of(file)
        if slides[file] ~= nil then
            return slides[file]
        end
        local found = false
        local with_slide_offset, with_slide_count = nil, nil
        if file.mapping_offset >= 0x140 then
            with_slide_offset, with_slide_count = string.unpack("<I4I4", file.header, 0x138 + 1)
        end
        local ranges = {}
        local function describe(slide_offset, slide_size, address, size)
            if slide_size == 0 then
                return
            end
            local head = read(file, slide_offset, math.min(slide_size, 64))
            local version = string.unpack("<I4", head, 1)
            local info = {version = version, address = address, size = size}
            if version == 2 then
                info.delta_mask, info.value_add = string.unpack("<I8I8", head, 25)
            elseif version == 3 then
                info.value_add = string.unpack("<I8", head, 17)
            elseif version == 5 then
                info.value_add = string.unpack("<I8", head, 17)
            elseif version == 1 then
                info.slide_offset = slide_offset
                info.toc_offset, info.toc_count, info.entries_offset, _, info.entries_size = string.unpack("<I4I4I4I4I4", head, 5)
            end
            table.insert(ranges, info)
        end
        if with_slide_offset and with_slide_count and with_slide_count > 0 then
            local entries = read(file, with_slide_offset, with_slide_count * 56)
            for index = 0, with_slide_count - 1 do
                local address, size, _, slide_offset, slide_size = string.unpack("<I8I8I8I8I8", entries, index * 56 + 1)
                describe(slide_offset, slide_size, address, size)
            end
        elseif file.mapping_offset >= 0x48 then
            local slide_offset, slide_size = string.unpack("<I8I8", file.header, 0x38 + 1)
            local own = {}
            for _, mapping in ipairs(mappings) do
                if mapping.file == file then
                    table.insert(own, mapping)
                end
            end
            if own[2] then
                describe(slide_offset, slide_size, own[2].address, own[2].size)
            end
        end
        found = ranges
        slides[file] = found
        return found
    end
    local function mapped(address, size)
        for _, mapping in ipairs(mappings) do
            if mapping.address <= address and address + (size or 1) <= mapping.address + mapping.size then
                return true
            end
        end
        return false
    end
    local function slide_bits(file, info, page)
        local entry = string.unpack("<I2", read(file, info.slide_offset + info.toc_offset + page * 2, 2))
        return read(file, info.slide_offset + info.entries_offset + entry * info.entries_size, info.entries_size)
    end
    local function slid_pages(file, info, wide)
        local page_size = info.entries_size * 32
        local pages, first = 0, nil
        for page = 0, info.toc_count - 1 do
            local bits = slide_bits(file, info, page)
            local slid = false
            for index = 0, info.entries_size * 8 - 1 do
                if bits:byte(index // 8 + 1) & (1 << (index % 8)) ~= 0 then
                    local slot = info.address + page * page_size + index * 4
                    local value = string.unpack(wide and "<I8" or "<I4", read_address(slot, wide and 8 or 4))
                    if value ~= 0 and not mapped(value) then
                        first = first or {slot, value}
                        slid = true
                        break
                    end
                end
            end
            if slid then
                pages = pages + 1
            end
        end
        return pages, first
    end
    local function marked(file, info, address)
        local page_size = info.entries_size * 32
        local page = (address - info.address) // page_size
        if page >= info.toc_count then
            return false
        end
        local index = (address - info.address - page * page_size) // 4
        return slide_bits(file, info, page):byte(index // 8 + 1) & (1 << (index % 8)) ~= 0
    end
    local function pointer_at(address, wide)
        local file = locate(address, wide and 8 or 4)
        local value = string.unpack(wide and "<I8" or "<I4", read_address(address, wide and 8 or 4))
        if value == 0 then
            return 0
        end
        for _, info in ipairs(slide_of(file)) do
            if info.address <= address and address < info.address + info.size then
                if info.version == 1 and not mapped(value) and marked(file, info, address) then
                    local pages, first = slid_pages(file, info, wide)
                    raise("%s was copied from a running device: %d of its pages hold pointers the device slid, such as %#x at %#x outside every mapping, so its Objective-C metadata cannot be read; delete it and run xmake firmware --arch=%s fetch %s to take the release's cache from Apple's firmware",
                          mainfile, pages, first[2], first[1], main.header:sub(8, 16):gsub("[ %z]", ""), path.filename(path.directory(mainfile)))
                elseif info.version == 2 then
                    local target = value & ~info.delta_mask
                    return target ~= 0 and ((target + info.value_add) & (wide and -1 or 0xFFFFFFFF)) or 0
                elseif not wide then
                    return value
                elseif info.version == 3 then
                    if value >> 63 ~= 0 then
                        return info.value_add + (value & 0xFFFFFFFF)
                    end
                    return (value & 0x7FFFFFFFFFF) | (((value >> 43) & 0xFF) << 56)
                elseif info.version == 5 then
                    return info.value_add + (value & 0x3FFFFFFFF)
                end
            end
        end
        return value
    end
    return {main = main, field = field, read = read, read_address = read_address, string_at = string_at, pointer_at = pointer_at, mapped = mapped, close = close}
end

function open_cache(cachefile)
    local cache = cache_files(cachefile)
    local images_offset, images_count
    if cache.main.mapping_offset >= 0x1c4 then
        images_offset, images_count = cache.field(cache.main, 0x1c0, "<I4"), cache.field(cache.main, 0x1c4, "<I4")
    else
        images_offset, images_count = cache.field(cache.main, 0x18, "<I4"), cache.field(cache.main, 0x1c, "<I4")
    end
    local entries = cache.read(cache.main, images_offset, images_count * 32)
    local images, seen = {}, {}
    for index = 0, images_count - 1 do
        local address, _, _, path_offset = string.unpack("<I8I8I8I4", entries, index * 32 + 1)
        if not seen[address] then
            seen[address] = true
            local install = cache.read(cache.main, path_offset, math.min(1024, cache.main.size - path_offset)):match("^([^%z]*)")
            local magic = string.unpack("<I4", cache.read_address(address, 4))
            local header_size = magic == 0xFEEDFACF and 32 or 28
            local sizeofcmds = string.unpack("<I4", cache.read_address(address + 20, 4))
            table.insert(images, {install = install, address = address, image = macho.image(cache.read_address(address, header_size + sizeofcmds), 0)})
        end
    end
    cache.architecture = cache.main.header:sub(8, 16):gsub("[ %z]", "")
    cache.images = images
    return cache
end

local function cached_library(cache, address)
    local magic = string.unpack("<I4", cache.read_address(address, 4))
    local wide = magic == 0xFEEDFACF
    if magic ~= 0xFEEDFACE and not wide then
        raise("no Mach-O header at %#x in the shared cache", address)
    end
    local header_size = wide and 32 or 28
    local sizeofcmds = string.unpack("<I4", cache.read_address(address + 20, 4))
    local image = macho.image(cache.read_address(address, header_size + sizeofcmds), 0)
    local linkedit
    for _, segment in ipairs(image.segments) do
        if segment.name == "__LINKEDIT" then
            linkedit = segment
        end
    end
    local function linkedit_address(offset)
        return linkedit.vmaddr + (offset - linkedit.fileoff)
    end
    local exports = {}
    if image.export_trie and image.export_trie[2] ~= 0 and linkedit then
        exports = trie_exports(cache.read_address(linkedit_address(image.export_trie[1]), image.export_trie[2]), 0, image.export_trie[2])
    elseif image.symtab and linkedit then
        local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
        local first, count = 0, nsyms
        if image.external and image.external[2] > 0 then
            first, count = image.external[1], image.external[2]
        end
        local entry = image.wide and 16 or 12
        local symbols = cache.read_address(linkedit_address(symoff + first * entry), count * entry)
        for index = 0, count - 1 do
            local strx, kind = string.unpack("<I4B", symbols, index * entry + 1)
            if kind & 0xE0 == 0 and kind & 0x01 ~= 0 and kind & 0x0E ~= 0 then
                exports[cache.string_at(linkedit_address(stroff + strx))] = true
            end
        end
    end
    return {exports = exports, dependents = image.libraries, reexports = image.reexports, umbrella = image.umbrella, sub_names = image.sub_names}
end

local function load_cache(cachefile)
    local cache = cache_files(cachefile)
    local architecture = cache.main.header:sub(8, 16):gsub("[ %z]", "")
    local images_offset, images_count
    if cache.main.mapping_offset >= 0x1c4 then
        images_offset, images_count = cache.field(cache.main, 0x1c0, "<I4"), cache.field(cache.main, 0x1c4, "<I4")
    else
        images_offset, images_count = cache.field(cache.main, 0x18, "<I4"), cache.field(cache.main, 0x1c, "<I4")
    end
    local entries = cache.read(cache.main, images_offset, images_count * 32)
    local by_address, by_index, libraries = {}, {}, {}
    for index = 0, images_count - 1 do
        local address, _, _, path_offset = string.unpack("<I8I8I8I4", entries, index * 32 + 1)
        local library = by_address[address]
        if not library then
            library = cached_library(cache, address)
            by_address[address] = library
        end
        by_index[index] = library
        local install = cache.read(cache.main, path_offset, math.min(1024, cache.main.size - path_offset)):match("^([^%z]*)")
        libraries[install] = library
    end
    local trie_address, trie_size = cache.field(cache.main, 0x108, "<I8"), cache.field(cache.main, 0x110, "<I8")
    if trie_address and trie_size and trie_size > 0 then
        local trie = cache.read_address(trie_address, trie_size)
        for install, value in pairs(trie_payloads(trie)) do
            local index = uleb(trie, value)
            if by_index[index] then
                libraries[install] = libraries[install] or by_index[index]
            end
        end
    end
    cache.close()
    local outside = outside_source(path.directory(cachefile), architecture)
    if os.isdir(outside) then
        read_libraries(outside, architecture, libraries, libraries, true)
    end
    return assemble(architecture, libraries)
end

function load(cachefile)
    if not caches[cachefile] then
        caches[cachefile] = os.isdir(cachefile) and load_libraries(cachefile) or load_cache(cachefile)
    end
    return caches[cachefile]
end

local function exports_symbol(lookup, install, symbol, seen)
    local library = lookup(install)
    if not library or seen[install] then
        return false
    end
    seen[install] = true
    if library.exports[symbol] then
        return true
    end
    for _, other in ipairs(library.reexports) do
        if exports_symbol(lookup, other, symbol, seen) then
            return true
        end
    end
    return false
end

function exported_by(cache, install, symbol)
    return exports_symbol(function (name) return cache.libraries[name] end, install, symbol, {})
end

local OWNERS = {}
local LISTED_KEYS = {["symbols"] = "", ["weak-symbols"] = "", ["objc-classes"] = "class", ["objc-eh-types"] = "_OBJC_EHTYPE_$_", ["objc-ivars"] = "_OBJC_IVAR_$_"}
local SCRIPTDIR = os.scriptdir()

local function stored(name, under)
    return path.join(under or path.directory(root()), "cache", name)
end

local function kept_text(file)
    if not os.isfile(file) then
        return nil
    end
    return try {
        function ()
            return io.readfile(file)
        end,
        catch {
            function (errors)
                if os.isfile(file) then
                    raise(errors)
                end
            end
        }
    }
end

local function store(file, text)
    local partial = file .. "." .. hash.uuid4()
    io.writefile(partial, text)
    os.mv(partial, file)
end

local function sdk_tbds(sdkdir)
    return table.join(os.files(path.join(sdkdir, "System", "Library", "Frameworks", "**.tbd")), os.files(path.join(sdkdir, "usr", "lib", "*.tbd")))
end

local SDK_KEYS = {}

local function code_lines(name, lines)
    local file = path.join(SCRIPTDIR, name .. ".lua")
    if lines[name] or not os.isfile(file) then
        return lines
    end
    lines[name] = name .. " " .. hash.sha256(file)
    for imported in io.readfile(file):gmatch('import%("([%w_]+)"') do
        code_lines(imported, lines)
    end
    return lines
end

local CODE_KEY

local function code_key()
    if not CODE_KEY then
        local lines = table.values(code_lines("dyld", {}))
        byteorder.sort(lines)
        CODE_KEY = hash.strhash128(table.concat(lines, "\n"))
    end
    return CODE_KEY
end

local function kept_file(family, key, under)
    return stored(family .. "-" .. code_key() .. "-" .. key .. ".tsv", under)
end

local function sdk_key(sdkdir)
    if not SDK_KEYS[sdkdir] then
        local lines = {}
        for _, file in ipairs(sdk_tbds(sdkdir)) do
            table.insert(lines, path.relative(file, sdkdir) .. " " .. hash.sha256(file))
        end
        byteorder.sort(lines)
        SDK_KEYS[sdkdir] = hash.strhash128(table.concat(lines, "\n"))
    end
    return SDK_KEYS[sdkdir]
end

local function owners_file(sdkdir, under)
    return kept_file("sdk-owners", sdk_key(sdkdir), under)
end

local function write_owners(file, owners)
    local installs, index, lines = {}, {}, {}
    for symbol, found in pairs(owners) do
        local ids = {}
        for _, install in ipairs(found) do
            if not index[install] then
                table.insert(installs, install)
                index[install] = #installs
            end
            table.insert(ids, index[install])
        end
        table.insert(lines, symbol .. "\t" .. table.concat(ids, ","))
    end
    store(file, table.concat(installs, "\n") .. "\n\n" .. table.concat(lines, "\n") .. "\n")
end

local function read_owners(text)
    local installs, body = text:match("^(.-)\n\n(.*)$")
    installs = installs:split("\n")
    local owners = {}
    for symbol, ids in body:gmatch("([^\t\n]+)\t([^\n]+)") do
        local found = {}
        for id in ids:gmatch("%d+") do
            table.insert(found, installs[tonumber(id)])
        end
        owners[symbol] = found
    end
    return owners
end

function sdk_owners(sdkdir)
    if not OWNERS[sdkdir] then
        local kept = owners_file(sdkdir)
        local text = kept_text(kept)
        if text then
            OWNERS[sdkdir] = read_owners(text)
            return OWNERS[sdkdir]
        end
        local owners = {}
        for _, file in ipairs(sdk_tbds(sdkdir)) do
            local text = io.readfile(file)
            local umbrella = text:match("install%-name:%s*'([^']+)'") or text:match("install%-name:%s*(%S+)")
            local exporting, prefix, buffer = false, nil, nil
            local function take(list)
                for item in list:gmatch("[^,%[%]]+") do
                    local name = item:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^'", ""):gsub("'$", "")
                    if #name > 0 then
                        local names = prefix == "class" and {"_OBJC_CLASS_$_" .. name, "_OBJC_METACLASS_$_" .. name} or {prefix .. name}
                        for _, symbol in ipairs(names) do
                            owners[symbol] = owners[symbol] or {}
                            if not table.contains(owners[symbol], umbrella) then
                                table.insert(owners[symbol], umbrella)
                            end
                        end
                    end
                end
            end
            for line in text:gmatch("[^\n]+") do
                if buffer then
                    buffer = buffer .. line
                    if line:find("]", 1, true) then
                        take(buffer)
                        buffer = nil
                    end
                elseif line:startswith("---") then
                    exporting = false
                elseif line:match("^[%w%-]+:") then
                    local key = line:match("^([%w%-]+):")
                    exporting = key == "exports" or key == "reexports"
                elseif exporting and umbrella then
                    local key, rest = line:match("^%s+%-?%s*([%w%-]+):%s*(.*)$")
                    prefix = key and LISTED_KEYS[key]
                    if prefix and rest:find("[", 1, true) then
                        if rest:find("]", 1, true) then
                            take(rest)
                        else
                            buffer = rest
                        end
                    end
                end
            end
        end
        for symbol, found in pairs(owners) do
            local frameworks = {}
            for _, install in ipairs(found) do
                if install:startswith("/System/Library/Frameworks/") then
                    table.insert(frameworks, install)
                end
            end
            if #frameworks > 0 then
                owners[symbol] = frameworks
            end
        end
        write_owners(kept, owners)
        OWNERS[sdkdir] = owners
    end
    return OWNERS[sdkdir]
end

function exported_at(cache, symbol, owners)
    if not owners then
        return cache.exports[symbol] ~= nil
    end
    for _, install in ipairs(owners) do
        if exported_by(cache, install, symbol) then
            return true
        end
    end
    return false
end

local SIGNATURES = {}

local function ladder_signature(ladder)
    local rungs = {}
    for _, entry in ipairs(ladder) do
        table.insert(rungs, entry.release .. " " .. entry.architecture .. " " .. entry.source)
    end
    local named = table.concat(rungs, "\n")
    if not SIGNATURES[named] then
        local lines = {}
        for index, entry in ipairs(ladder) do
            table.insert(lines, rungs[index])
            local files = os.isdir(entry.source) and os.files(path.join(entry.source, "**")) or table.join(entry.source, os.files(entry.source .. ".*"))
            byteorder.sort(files)
            for _, file in ipairs(files) do
                table.insert(lines, file .. " " .. os.filesize(file) .. " " .. os.mtime(file))
            end
        end
        SIGNATURES[named] = hash.strhash128(table.concat(lines, "\n"))
    end
    return SIGNATURES[named]
end

local function first_release_file(ladder, sdkdir, under)
    return kept_file("first-release", hash.strhash128(sdk_key(sdkdir) .. " " .. ladder_signature(ladder)), under)
end

function first_release_key(ladder, sdkdir)
    return code_key() .. "-" .. sdk_key(sdkdir) .. "-" .. ladder_signature(ladder)
end

function kept_files(sdkdirs, ladders, under)
    local files = {}
    for _, sdkdir in ipairs(sdkdirs) do
        table.insert(files, owners_file(sdkdir, under))
        for _, ladder in ipairs(ladders) do
            table.insert(files, first_release_file(ladder, sdkdir, under))
        end
    end
    return files
end

local FIRST = {}

function first_releases(ladder, sdkdir, symbols)
    local kept = first_release_file(ladder, sdkdir)
    local function read()
        local known = {}
        for symbol, release in (kept_text(kept) or ""):gmatch("([^\t\n]+)\t([^\n]+)") do
            known[symbol] = release ~= "-" and release or false
        end
        return known
    end
    FIRST[kept] = FIRST[kept] or read()
    local known = FIRST[kept]
    local missing, seen = {}, {}
    for _, symbol in ipairs(symbols) do
        if known[symbol] == nil and not seen[symbol] then
            seen[symbol] = true
            table.insert(missing, symbol)
        end
    end
    if #missing > 0 then
        local owners = sdk_owners(sdkdir)
        local running = {}
        for _, entry in ipairs(ladder) do
            local cache = load(entry.source)
            for _, symbol in ipairs(missing) do
                if not exported_at(cache, symbol, owners[symbol]) then
                    running[symbol] = nil
                elseif not running[symbol] then
                    running[symbol] = true
                    known[symbol] = entry.release
                end
            end
        end
        for _, symbol in ipairs(missing) do
            known[symbol] = known[symbol] or false
        end
        for symbol, release in pairs(read()) do
            if known[symbol] == nil then
                known[symbol] = release
            end
        end
        local lines = {}
        for symbol, release in pairs(known) do
            table.insert(lines, symbol .. "\t" .. (release or "-"))
        end
        byteorder.sort(lines)
        store(kept, table.concat(lines, "\n") .. "\n")
    end
    local found = {}
    for _, symbol in ipairs(symbols) do
        found[symbol] = known[symbol] or nil
    end
    return found
end

local function undefined_imports(data, image)
    local imported = {}
    if not image.symtab then
        return imported
    end
    local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
    local entry = image.wide and 16 or 12
    for index = 0, nsyms - 1 do
        local strx, kind, _, desc = string.unpack("<I4BBI2", data, image.base + symoff + index * entry + 1)
        if kind & 0xE0 == 0 and kind & 0x0E == 0 and kind & 0x01 ~= 0 then
            table.insert(imported, {name = cstring(data, image.base + stroff + strx), weak = desc & 0x40 ~= 0, ordinal = (desc >> 8) & 0xFF})
        end
    end
    return imported
end

function image_imports(binaries, others, architecture)
    local loaded, exported = {}, {}
    for _, binary in ipairs(table.join(binaries, others or {})) do
        local data = macho.read(binary)
        local image = loaded_image(macho.images(data), architecture)
        if not image then
            raise("%s has no slice a %s device loads", binary, architecture)
        end
        table.join2(exported, defined_exports(data, image, image.base))
        loaded[binary] = {data = data, image = image}
    end
    local imports = {}
    for _, binary in ipairs(binaries) do
        local names = {}
        for _, symbol in ipairs(undefined_imports(loaded[binary].data, loaded[binary].image)) do
            names[symbol.name] = symbol.weak
        end
        imports[path.filename(binary)] = names
    end
    return {imports = imports, exported = exported}
end

function unexported_weak_imports(binaries, others, architecture)
    local read = image_imports(binaries, others, architecture)
    local found = {}
    for _, library in ipairs(table.orderkeys(read.imports)) do
        local names = {}
        for symbol, weak in pairs(read.imports[library]) do
            if weak and not read.exported[symbol] then
                names[symbol] = true
            end
        end
        found[library] = table.orderkeys(names)
    end
    return found
end

function missing_imports(cachefile, binaries, root)
    local cache = load(cachefile)
    local missing, dangling, ordering = {}, {}, {}
    local found = {}
    local function named(binary)
        return root and path.relative(binary, root) or binary
    end
    for _, binary in ipairs(binaries) do
        local data = macho.read(binary)
        local image = loaded_image(macho.images(data), cache.architecture)
        if image then
            table.insert(found, {binary = binary, data = data, image = image})
        else
            table.insert(missing, {named(binary), string.format("(no slice a %s device loads)", cache.architecture)})
        end
    end
    local own, provided, provided_names = {}, {}, {}
    for _, entry in ipairs(found) do
        table.join2(own, defined_exports(entry.data, entry.image, entry.image.base))
        if entry.image.identity then
            local library = library_of(entry.data, entry.image, entry.image.base)
            provided[entry.image.identity] = library
            provided_names[path.filename(entry.image.identity)] = library
        end
    end
    local function lookup(install)
        return provided[install] or (install:startswith("@") and provided_names[path.filename(install)]) or cache.libraries[install]
    end
    for _, entry in ipairs(found) do
        local absent = {}
        for index, library in ipairs(entry.image.libraries) do
            local relative = library:startswith("@")
            if not (cache.images[library] or provided[library] or (relative and provided_names[path.filename(library)])) then
                absent[index] = true
                if entry.image.library_strength[index] then
                    table.insert(missing, {named(entry.binary), string.format("(loads %s, which neither the device nor this build provides)", library)})
                end
            end
        end
        local twolevel = entry.image.flags & 0x80 ~= 0
        local reexported = {}
        for _, reexport in ipairs(single_reexports(entry.data, entry.image)) do
            reexported[reexport.imported] = true
            local library = entry.image.libraries[reexport.ordinal]
            if library and lookup(library) and not exports_symbol(lookup, library, reexport.imported, {}) then
                table.insert(missing, {named(entry.binary), string.format("%s (re-exported from %s, which does not export %s)", reexport.name, library, reexport.imported)})
            end
        end
        for _, symbol in ipairs(undefined_imports(entry.data, entry.image)) do
            local bound = twolevel and entry.image.libraries[symbol.ordinal]
            if symbol.weak and bound and cache.libraries[bound] and not exports_symbol(lookup, bound, symbol.name, {}) then
                for _, install in ipairs(table.orderkeys(provided)) do
                    if install ~= bound and provided[install].exports[symbol.name] then
                        table.insert(ordering, {named(entry.binary), string.format("%s (weakly bound to %s, which does not export it, while %s does; link %s before %s)",
                                                                                  symbol.name, bound, install, path.filename(install), path.filename(bound)), symbol.name})
                        break
                    end
                end
            end
            if symbol.weak and symbol.name:startswith("_") and not reexported[symbol.name] and not own[symbol.name] then
                local resolved = bound and exports_symbol(lookup, bound, symbol.name, {}) or (not bound and cache.exports[symbol.name] ~= nil)
                if not resolved then
                    table.insert(dangling, {named(entry.binary), symbol.name, bound})
                end
            end
            if symbol.name:startswith("_") and not symbol.weak and not reexported[symbol.name] and not (twolevel and absent[symbol.ordinal]) then
                local library = twolevel and entry.image.libraries[symbol.ordinal]
                if library and lookup(library) then
                    if not exports_symbol(lookup, library, symbol.name, {}) then
                        local elsewhere = (cache.exports[symbol.name] or own[symbol.name]) and ", which only another library exports" or ""
                        table.insert(missing, {named(entry.binary), string.format("%s (bound to %s%s)", symbol.name, library, elsewhere)})
                    end
                elseif not own[symbol.name] and not cache.exports[symbol.name] then
                    table.insert(missing, {named(entry.binary), symbol.name})
                end
            end
        end
    end
    table.sort(missing, function (a, b)
        return a[1] == b[1] and byteorder.less(a[2], b[2]) or byteorder.less(a[1], b[1])
    end)
    table.sort(dangling, function (a, b)
        return a[1] == b[1] and byteorder.less(a[2], b[2]) or byteorder.less(a[1], b[1])
    end)
    table.sort(ordering, function (a, b)
        return a[1] == b[1] and byteorder.less(a[2], b[2]) or byteorder.less(a[1], b[1])
    end)
    return missing, #found, cache, dangling, ordering
end

function check(cachefile, binaries, folder, opt)
    opt = opt or {}
    if not os.exists(cachefile) then
        raise("there is no shared cache or library folder at %s to check imports against; a check that reports success having looked at nothing is worse than no check", cachefile)
    end
    local missing, count, cache, dangling, ordering = missing_imports(cachefile, binaries, folder)
    local emitted = compat.emitted()
    local tested = compat.guarded()
    local guarded = {}
    local exempt = {}
    local warnings = {}
    for _, binary in ipairs(opt.exempt or {}) do
        exempt[folder and path.relative(binary, folder) or binary] = true
    end
    local runtime = {}
    for _, binary in ipairs(opt.runtime or {}) do
        runtime[folder and path.relative(binary, folder) or binary] = (opt.guards or {})[path.filename(binary)] or {}
    end
    local unguarded = 0
    for _, entry in ipairs(ordering) do
        local guard = (runtime[entry[1]] or {})[entry[3]]
        if exempt[entry[1]] then
            table.insert(warnings, entry[1] .. " " .. entry[2])
        elseif guard then
            unguarded = unguarded + 1
            table.insert(warnings, string.format("%s %s; the runtime's guard table records the guard it is called behind (%s), so the release that lacks it never reaches the NULL",
                                                 entry[1], entry[2], guard))
        else
            table.insert(missing, entry)
        end
    end
    for _, entry in ipairs(dangling) do
        local by = emitted[entry[2]:sub(2)]
        local guard = tested[entry[2]:sub(2)]
        if guard then
            unguarded = unguarded + 1
            table.insert(warnings, string.format("%s weakly imports %s from %s, which the %s release it is checked against (%s) does not export; it is called only behind a test for it, in %s",
                                                 entry[1], entry[2], entry[3] or "the flat namespace", cache.architecture, cachefile, guard))
        elseif by then
            table.insert(missing, {entry[1], string.format("%s (weakly imported from %s, which this release does not export; the compiler emits this, so no version check stands in front of it and it reaches NULL; the image should carry it from %s)",
                                                           entry[2], entry[3] or "the flat namespace", by)})
        else
            guarded[entry[1]] = guarded[entry[1]] or {}
            table.insert(guarded[entry[1]], entry[2])
        end
    end
    for _, binary in ipairs(table.orderkeys(guarded)) do
        local names = guarded[binary]
        local guards = runtime[binary]
        if guards then
            local recorded, unrecorded = {}, {}
            for _, name in ipairs(names) do
                table.insert(guards[name] and recorded or unrecorded, name)
            end
            if #recorded > 0 then
                unguarded = unguarded + #recorded
                table.insert(warnings, string.format("%s weakly imports %d symbol%s the %s release it is checked against (%s) does not export, each guarded in the runtime's source as its guard table records: %s",
                                                     binary, #recorded, #recorded == 1 and "" or "s", cache.architecture, cachefile, table.concat(recorded, " ")))
            end
            names = unrecorded
        end
        if #names > 0 then
            local shown = table.concat(names, " ")
            local text = string.format("weakly imports %d symbol%s the %s release it is checked against (%s) does not export, each of which is NULL there and must be called only behind a check for it%s: %s",
                                       #names, #names == 1 and "" or "s", cache.architecture, cachefile,
                                       guards and ", and the runtime's guard table records no guard for it" or "", shown)
            if opt.release and not opt.waived and not exempt[binary] then
                table.insert(missing, {binary, text .. "; a released image is refused these unless the target waives the check with revenant.waive.weak-imports and says why every call is guarded"})
            else
                unguarded = unguarded + #names
                table.insert(warnings, binary .. " " .. text)
            end
        end
    end
    for _, warning in ipairs(warnings) do
        cprint("${color.warning}warning:${clear} %s", warning)
    end
    if #missing > 0 then
        table.sort(missing, function (a, b)
            return a[1] == b[1] and byteorder.less(a[2], b[2]) or byteorder.less(a[1], b[1])
        end)
        local lines = {"these imports are not exported by the device's iOS:"}
        for _, entry in ipairs(missing) do
            table.insert(lines, "  " .. entry[1] .. "  " .. entry[2])
        end
        raise(table.concat(lines, "\n"))
    end
    cprint("imports: every non-weak import of the %s slices of %d binaries resolves against %d exports%s", cache.architecture, count, cache.count,
           unguarded > 0 and string.format("; %d weak import%s it does not export, each named in a warning above", unguarded, unguarded == 1 and "" or "s") or "")
    return warnings
end

function image_symbols(cache, loaded)
    local image = loaded.image
    local linkedit
    for _, segment in ipairs(image.segments) do
        if segment.name == "__LINKEDIT" then
            linkedit = segment
        end
    end
    local found = {exports = {}, reexports = {}, indirect = {}, function_starts = {}}
    if not linkedit then
        return found
    end
    local function at(offset, size)
        return cache.read_address(linkedit.vmaddr + (offset - linkedit.fileoff), size)
    end
    if image.export_trie and image.export_trie[2] ~= 0 then
        local trie = at(image.export_trie[1], image.export_trie[2])
        for name, cursor in pairs(trie_payloads(trie)) do
            local flags
            flags, cursor = uleb(trie, cursor)
            if flags & 0x08 == 0 then
                table.insert(found.exports, {uleb(trie, cursor) + loaded.address, name})
            else
                table.insert(found.reexports, name)
            end
        end
    end
    if image.symtab and image.indirect and image.indirect[2] > 0 then
        local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
        local entry = image.wide and 16 or 12
        local indirect = at(image.indirect[1], image.indirect[2] * 4)
        for _, section in ipairs(image.sections) do
            local kind = section.flags & 0xFF
            if kind == 6 or kind == 7 or kind == 8 then
                local slot = kind == 8 and section.reserved2 or (image.wide and 8 or 4)
                for index = 0, (slot > 0 and section.size // slot or 0) - 1 do
                    local position = section.reserved1 + index
                    if position < image.indirect[2] then
                        local symbol = string.unpack("<I4", indirect, position * 4 + 1)
                        if symbol & 0xC0000000 == 0 and symbol < nsyms then
                            local strx = string.unpack("<I4", at(symoff + symbol * entry, 4))
                            table.insert(found.indirect, {section.addr + index * slot, cache.string_at(linkedit.vmaddr + (stroff + strx - linkedit.fileoff))})
                        end
                    end
                end
            end
        end
    end
    if image.function_starts and image.function_starts[2] > 0 then
        local data = at(image.function_starts[1], image.function_starts[2])
        local cursor, address = 0, loaded.address
        while cursor < #data do
            local delta
            delta, cursor = uleb(data, cursor)
            if delta == 0 then
                break
            end
            address = address + delta
            table.insert(found.function_starts, address)
        end
    end
    return found
end

local function encoded_uleb(value)
    local bytes = {}
    repeat
        local byte = value & 0x7F
        value = value >> 7
        table.insert(bytes, string.char(value ~= 0 and (byte | 0x80) or byte))
    until value == 0
    return table.concat(bytes)
end

local function slid_slots(cache, segments)
    local file = cache.main
    if file.mapping_offset < 0x48 then
        return {}
    end
    local slide_offset, slide_size = string.unpack("<I8I8", file.header, 0x38 + 1)
    if slide_size == 0 then
        return {}
    end
    local head = cache.read(file, slide_offset, 64)
    local version = string.unpack("<I4", head, 1)
    if version ~= 1 then
        return {}, version
    end
    local toc_offset, toc_count, entries_offset, _, entries_size = string.unpack("<I4I4I4I4I4", head, 5)
    local page_size = entries_size * 32
    local mapping_bytes = cache.read(file, file.mapping_offset, 32 * 2)
    local region_address, region_size = string.unpack("<I8I8", mapping_bytes, 32 + 1)
    local toc = cache.read(file, slide_offset + toc_offset, toc_count * 2)
    local entries = cache.read(file, slide_offset + entries_offset, slide_size - entries_offset)
    local found = {}
    for _, segment in ipairs(segments) do
        local slots = {}
        local first = math.max(segment.vmaddr, region_address)
        local last = math.min(segment.vmaddr + segment.vmsize, region_address + region_size)
        local page = (first - region_address) // page_size
        while page < toc_count and region_address + page * page_size < last do
            local entry = string.unpack("<I2", toc, page * 2 + 1)
            local bits = entries:sub(entry * entries_size + 1, (entry + 1) * entries_size)
            for index = 0, entries_size * 8 - 1 do
                if bits:byte(index // 8 + 1) & (1 << (index % 8)) ~= 0 then
                    local address = region_address + page * page_size + index * 4
                    if segment.vmaddr <= address and address < segment.vmaddr + segment.vmsize then
                        table.insert(slots, address - segment.vmaddr)
                    end
                end
            end
            page = page + 1
        end
        table.sort(slots)
        found[segment.name] = slots
    end
    return found
end

local function rebase_stream(segments, slots, wide)
    local pointer = wide and 8 or 4
    local stream = {string.char(0x10 | 1)}
    for index, segment in ipairs(segments) do
        local held = slots[segment.name] or {}
        if #held > 0 then
            table.insert(stream, string.char(0x70 | (index - 1)) .. encoded_uleb(held[1]))
            local at, run = held[1], 0
            for position = 1, #held do
                if held[position] == at + run * pointer then
                    run = run + 1
                else
                    table.insert(stream, string.char(0x50) .. encoded_uleb(run))
                    table.insert(stream, string.char(0x20) .. encoded_uleb(held[position] - (at + run * pointer)))
                    at, run = held[position], 1
                end
            end
            table.insert(stream, string.char(0x50) .. encoded_uleb(run))
        end
    end
    table.insert(stream, string.char(0))
    local bytes = table.concat(stream)
    return bytes .. string.rep("\0", (8 - #bytes % 8) % 8)
end

local function symbol_file(cache)
    local file = cache.main
    if file.mapping_offset < 0x58 then
        return nil
    end
    local _, region_size = string.unpack("<I8I8", file.header, 0x48 + 1)
    if region_size > 0 then
        return file
    end
    if file.mapping_offset < 0x1a0 then
        return nil
    end
    local wanted = file.header:sub(0x190 + 1, 0x190 + 16)
    if wanted == string.rep("\0", 16) then
        return nil
    end
    for _, candidate in ipairs(os.files(path.join(path.directory(file.path), path.filename(file.path) .. "*"))) do
        local handle = io.open(candidate, "rb")
        local header = handle and handle:read(0x200)
        if handle then
            handle:close()
        end
        if header and header:startswith("dyld_v1") and header:sub(0x58 + 1, 0x58 + 16) == wanted then
            local mapping_offset = string.unpack("<I4", header, 17)
            local offset, size = string.unpack("<I8I8", header, 0x48 + 1)
            if size > 0 then
                return {path = candidate, header = header, mapping_offset = mapping_offset, separate = true}
            end
        end
    end
    return nil
end

local function local_symbols(cache, address, wide)
    local file = symbol_file(cache)
    if not file then
        return {}
    end
    local region_offset, region_size = string.unpack("<I8I8", file.header, 0x48 + 1)
    local function read(offset, size)
        if not file.separate then
            return cache.read(file, offset, size)
        end
        local handle = assert(io.open(file.path, "rb"), "cannot read " .. file.path)
        handle:seek("set", offset)
        local bytes = handle:read(size)
        handle:close()
        return bytes
    end
    local head = read(region_offset, 24)
    local nlist_offset, nlist_count, strings_offset, strings_size, entries_offset, entries_count = string.unpack("<I4I4I4I4I4I4", head, 1)
    local base = string.unpack("<I8", cache.read(cache.main, cache.main.mapping_offset, 8), 1)
    local entry_width = region_size >= entries_offset + entries_count * 16 and #read(region_offset + entries_offset, math.min(16, region_size - entries_offset)) == 16 and 16 or 12
    local entries = read(region_offset + entries_offset, entries_count * entry_width)
    local start, count
    for index = 0, entries_count - 1 do
        local dylib_offset, first, held
        if entry_width == 16 then
            dylib_offset, first, held = string.unpack("<I8I4I4", entries, index * 16 + 1)
        else
            dylib_offset, first, held = string.unpack("<I4I4I4", entries, index * 12 + 1)
        end
        if dylib_offset == address - base then
            start, count = first, held
        end
    end
    if not start or count == 0 then
        return {}
    end
    local entry_size = wide and 16 or 12
    local nlists = read(region_offset + nlist_offset + start * entry_size, count * entry_size)
    local strings = read(region_offset + strings_offset, strings_size)
    local found = {}
    for index = 0, count - 1 do
        local strx, kind, section, desc = string.unpack("<I4BBI2", nlists, index * entry_size + 1)
        local value = wide and string.unpack("<I8", nlists, index * entry_size + 9) or string.unpack("<I4", nlists, index * entry_size + 9)
        local name = strings:sub(strx + 1, (strings:find("\0", strx + 1, true) or strx + 1) - 1)
        if #name > 0 then
            table.insert(found, {name = name, kind = kind, section = section, desc = desc, value = value})
        end
    end
    return found
end

function image_at(cache, address)
    for _, loaded in ipairs(cache.images) do
        for _, segment in ipairs(loaded.image.segments) do
            if segment.name ~= "__LINKEDIT" and address >= segment.vmaddr
                and address < segment.vmaddr + segment.vmsize then
                return loaded
            end
        end
    end
    return nil
end

function symbol_at(cache, address)
    local loaded = image_at(cache, address)
    if not loaded then
        return nil
    end
    cache.named = cache.named or {}
    local names = cache.named[loaded.address]
    if not names then
        names = {}
        for _, entry in ipairs(image_symbols(cache, loaded).exports) do
            names[entry[1]] = names[entry[1]] or {}
            table.insert(names[entry[1]], entry[2])
        end
        cache.named[loaded.address] = names
    end
    if names[address] then
        return {name = table.concat(names[address], " | "), image = loaded.install, at = address, kind = "export"}
    end
    local below
    for _, entry in ipairs(local_symbols(cache, loaded.address, loaded.image.wide)) do
        if entry.value <= address and entry.value > 0 and (not below or entry.value > below.value) then
            below = entry
        end
    end
    if below then
        return {name = below.name, image = loaded.install, at = below.value, kind = "local"}
    end
    return {name = nil, image = loaded.install}
end

local function symbol_table(cache, linkedit, symoff, nsyms, stroff, locals, wide)
    local entry_size = wide and 16 or 12
    local at = function (offset, size)
        return cache.read_address(linkedit.vmaddr + (offset - linkedit.fileoff), size)
    end
    local nlists, names, strings = {}, {}, {"\0"}
    local length = 1
    local function add(name, kind, section, desc, value)
        local strx = names[name]
        if not strx then
            strx = length
            names[name] = strx
            table.insert(strings, name .. "\0")
            length = length + #name + 1
        end
        table.insert(nlists, wide and string.pack("<I4BBI2I8", strx, kind, section, desc, value)
                                  or string.pack("<I4BBI2I4", strx, kind, section, desc, value))
    end
    for _, symbol in ipairs(locals) do
        add(symbol.name, symbol.kind, symbol.section, symbol.desc, symbol.value)
    end
    local held = nsyms > 0 and at(symoff, nsyms * entry_size) or ""
    for index = 0, nsyms - 1 do
        local strx, kind, section, desc = string.unpack("<I4BBI2", held, index * entry_size + 1)
        local value = wide and string.unpack("<I8", held, index * entry_size + 9) or string.unpack("<I4", held, index * entry_size + 9)
        local name = cache.string_at(linkedit.vmaddr + (stroff + strx - linkedit.fileoff))
        add(name, kind, section, desc, value)
    end
    local table_bytes = table.concat(nlists)
    local string_bytes = table.concat(strings)
    string_bytes = string_bytes .. string.rep("\0", (8 - #string_bytes % 8) % 8)
    return table_bytes, string_bytes, #nlists
end

function extract(cachefile, install, outputfile)
    local cache = open_cache(cachefile)
    local chosen
    for _, entry in ipairs(cache.images) do
        if entry.install == install or entry.install:endswith("/" .. install) or path.filename(entry.install) == install then
            chosen = chosen or entry
        end
    end
    if not chosen then
        raise("%s holds no image named %s", cachefile, install)
    end
    local magic = string.unpack("<I4", cache.read_address(chosen.address, 4))
    local wide = magic == 0xFEEDFACF
    local header_size = wide and 32 or 28
    local header = cache.read_address(chosen.address, header_size)
    local ncmds, sizeofcmds = string.unpack("<I4I4", header, 17)
    local commands = cache.read_address(chosen.address + header_size, sizeofcmds)

    local segments, linkedit_commands, at = {}, {}, 1
    for _ = 1, ncmds do
        local command, size = string.unpack("<I4I4", commands, at)
        if command == 0x1 or command == 0x19 then
            local layout = wide and "<c16I8I8I8I8I4I4I4" or "<c16I4I4I4I4I4I4I4"
            local name, vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects = string.unpack(layout, commands, at + 8)
            table.insert(segments, {name = name:gsub("%z+$", ""), vmaddr = vmaddr, vmsize = vmsize, fileoff = fileoff,
                                    filesize = filesize, maxprot = maxprot, initprot = initprot, nsects = nsects, at = at, size = size})
        elseif command == 0x2 then
            local symoff, nsyms, stroff, strsize = string.unpack("<I4I4I4I4", commands, at + 8)
            table.insert(linkedit_commands, {at = at, kind = "symtab", symoff = symoff, nsyms = nsyms, stroff = stroff, strsize = strsize,
                                             fields = {{8, symoff, nsyms * (wide and 16 or 12)}, {16, stroff, strsize}}})
        elseif command == 0xb then
            local units = {8, wide and 56 or 52, 4, 4, 8, 8}
            local fields = {}
            for index = 0, #units - 1 do
                local offset, count = string.unpack("<I4I4", commands, at + 32 + index * 8)
                table.insert(fields, {32 + index * 8, offset, count * units[index + 1]})
            end
            local indirect_offset, indirect_count = string.unpack("<I4I4", commands, at + 56)
            local ilocal, nlocal, iextdef, nextdef, iundef, nundef = string.unpack("<I4I4I4I4I4I4", commands, at + 8)
            table.insert(linkedit_commands, {at = at, kind = "dysymtab", indirect_offset = indirect_offset, indirect_count = indirect_count,
                                             ilocal = ilocal, nlocal = nlocal, iextdef = iextdef, nextdef = nextdef, iundef = iundef, nundef = nundef,
                                             fields = fields})
        elseif command == 0x22 or command == 0x80000022 then
            local fields = {}
            for index = 0, 4 do
                local offset, size_of = string.unpack("<I4I4", commands, at + 8 + index * 8)
                table.insert(fields, {8 + index * 8, offset, size_of})
            end
            table.insert(linkedit_commands, {at = at, fields = fields, dyld_info = true})
        elseif command == 0x26 or command == 0x29 or command == 0x2B or command == 0x2C or command == 0x33 then
            local offset, size_of = string.unpack("<I4I4", commands, at + 8)
            table.insert(linkedit_commands, {at = at, fields = {{8, offset, size_of}}})
        end
        at = at + size
    end

    local linkedit
    for _, segment in ipairs(segments) do
        if segment.name == "__LINKEDIT" then
            linkedit = segment
        end
    end
    if not linkedit then
        raise("%s holds no __LINKEDIT segment in %s", install, cachefile)
    end
    local first, last
    for _, command in ipairs(linkedit_commands) do
        for _, field in ipairs(command.fields) do
            local offset, length = field[2], field[3]
            if offset > 0 and length > 0 then
                first = math.min(first or offset, offset)
                last = math.max(last or (offset + length), offset + length)
            end
        end
    end
    first = math.tointeger(first or linkedit.fileoff)
    last = math.tointeger(last or linkedit.fileoff)
    if first < linkedit.fileoff or last > linkedit.fileoff + linkedit.vmsize then
        raise("%s names link edit data between %#x and %#x, outside its own __LINKEDIT at %#x", install, first, last, linkedit.fileoff)
    end
    local slots, unread = slid_slots(cache, segments)
    local rebase = rebase_stream(segments, slots, wide)
    local symtab, dysymtab
    for _, command in ipairs(linkedit_commands) do
        symtab = command.kind == "symtab" and command or symtab
        dysymtab = command.kind == "dysymtab" and command or dysymtab
    end
    local locals = symtab and local_symbols(cache, chosen.address, wide) or {}
    local symbols, strings, symbol_count = "", "", 0
    if symtab then
        symbols, strings, symbol_count = symbol_table(cache, linkedit, symtab.symoff, symtab.nsyms, symtab.stroff, locals, wide)
    end
    local indirect = ""
    if dysymtab and dysymtab.indirect_count > 0 then
        local held = cache.read_address(linkedit.vmaddr + (dysymtab.indirect_offset - linkedit.fileoff), dysymtab.indirect_count * 4)
        local rebuilt = {}
        for index = 0, dysymtab.indirect_count - 1 do
            local value = string.unpack("<I4", held, index * 4 + 1)
            if value & 0xC0000000 == 0 then
                value = value + #locals
            end
            table.insert(rebuilt, string.pack("<I4", value))
        end
        indirect = table.concat(rebuilt)
    end

    local page = wide and 0x4000 or 0x1000
    local layout, offset = {}, 0
    for _, segment in ipairs(segments) do
        if segment.name ~= "__LINKEDIT" then
            layout[segment.name] = offset
            offset = offset + ((segment.filesize + page - 1) // page) * page
        end
    end
    local linkedit_offset = offset
    layout["__LINKEDIT"] = linkedit_offset
    local shift = linkedit_offset - first
    local appended = linkedit_offset + (last - first)
    local rebase_at = appended
    local symbols_at = rebase_at + #rebase
    local strings_at = symbols_at + #symbols
    local indirect_at = strings_at + #strings
    local linkedit_size = (last - first) + #rebase + #symbols + #strings + #indirect

    local pieces, count = {}, 0
    at = 1
    for _ = 1, ncmds do
        local command, size = string.unpack("<I4I4", commands, at)
        local body = commands:sub(at, at + size - 1)
        if command == 0x1d or command == 0x1e then
            body = nil
        elseif command == 0x1 or command == 0x19 then
            local segment
            for _, described in ipairs(segments) do
                if described.at == at then
                    segment = described
                end
            end
            local fileoff = layout[segment.name]
            local filesize = segment.name == "__LINKEDIT" and linkedit_size or segment.filesize
            local vmsize = segment.name == "__LINKEDIT" and ((linkedit_size + page - 1) // page) * page or segment.vmsize
            body = body:sub(1, 8 + 16) .. (wide and string.pack("<I8I8I8I8", segment.vmaddr, vmsize, fileoff, filesize)
                                                or string.pack("<I4I4I4I4", segment.vmaddr, vmsize, fileoff, filesize))
                       .. body:sub(8 + 16 + (wide and 33 or 17))
            local sections = body:sub(wide and 73 or 57)
            local rebuilt = {}
            for index = 0, segment.nsects - 1 do
                local entry_size = wide and 80 or 68
                local section = sections:sub(index * entry_size + 1, (index + 1) * entry_size)
                local addr = wide and string.unpack("<I8", section, 33) or string.unpack("<I4", section, 33)
                local kind = string.unpack("<I4", section, wide and 65 or 57)
                local zero_fill = kind & 0xFF == 1 or kind & 0xFF == 0xC or kind & 0xFF == 0xD
                local position = zero_fill and 0 or (fileoff + (addr - segment.vmaddr))
                local head = wide and 32 + 16 or 32 + 8
                section = section:sub(1, head) .. string.pack("<I4", position) .. section:sub(head + 5)
                section = section:sub(1, head + 8) .. string.pack("<I4I4", 0, 0) .. section:sub(head + 17)
                table.insert(rebuilt, section)
            end
            body = body:sub(1, wide and 72 or 56) .. table.concat(rebuilt)
        else
            for _, described in ipairs(linkedit_commands) do
                if described.at == at then
                    for _, field in ipairs(described.fields) do
                        local position, value, length = field[1], field[2], field[3]
                        if value > 0 and length > 0 then
                            body = body:sub(1, position) .. string.pack("<I4", value + shift) .. body:sub(position + 5)
                        elseif value > 0 then
                            body = body:sub(1, position) .. string.pack("<I4", 0) .. body:sub(position + 5)
                        end
                    end
                    if described.dyld_info then
                        body = body:sub(1, 8) .. string.pack("<I4I4", rebase_at, #rebase) .. body:sub(17)
                    elseif described.kind == "symtab" and symbol_count > 0 then
                        body = body:sub(1, 8) .. string.pack("<I4I4I4I4", symbols_at, symbol_count, strings_at, #strings)
                    elseif described.kind == "dysymtab" then
                        body = body:sub(1, 8) .. string.pack("<I4I4I4I4I4I4", 0, #locals + described.nlocal, #locals + described.iextdef,
                                                             described.nextdef, #locals + described.iundef, described.nundef) .. body:sub(33)
                        if #indirect > 0 then
                            body = body:sub(1, 56) .. string.pack("<I4I4", indirect_at, described.indirect_count) .. body:sub(65)
                        end
                    end
                end
            end
        end
        if body then
            table.insert(pieces, body)
            count = count + 1
        end
        at = at + size
    end
    local rebuilt_commands = table.concat(pieces)
    local new_header = header:sub(1, 16) .. string.pack("<I4I4", count, #rebuilt_commands) .. header:sub(25)

    os.mkdir(path.directory(path.absolute(outputfile)))
    local output = assert(io.open(outputfile, "wb"), "cannot write " .. outputfile)
    for _, segment in ipairs(segments) do
        if segment.name ~= "__LINKEDIT" then
            local bytes = segment.filesize > 0 and cache.read_address(segment.vmaddr, segment.filesize) or ""
            if segment.name == "__TEXT" then
                bytes = new_header .. rebuilt_commands .. string.rep("\0", header_size + sizeofcmds - #new_header - #rebuilt_commands) .. bytes:sub(header_size + sizeofcmds + 1)
            end
            output:write(bytes)
            output:write(string.rep("\0", ((segment.filesize + page - 1) // page) * page - segment.filesize))
        end
    end
    local remaining, cursor = last - first, first
    while remaining > 0 do
        local length = math.min(1 << 22, remaining)
        output:write(cache.read_address(linkedit.vmaddr + (cursor - linkedit.fileoff), length))
        cursor = cursor + length
        remaining = remaining - length
    end
    output:write(rebase)
    output:write(symbols)
    output:write(strings)
    output:write(indirect)
    output:close()
    cache.close()
    local pointers = 0
    for _, held in pairs(slots) do
        pointers = pointers + #held
    end
    return {install = chosen.install, address = chosen.address, segments = segments, linkedit = last - first, pointers = pointers,
            symbols = symbol_count, locals = #locals, size = linkedit_offset + linkedit_size, slide_info = unread}
end

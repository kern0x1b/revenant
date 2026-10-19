import("core.base.json")
import("dyld")
import("macho")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local RELATIVE_METHODS = 0x80000000

local function merge(into, from)
    for key in pairs(from) do
        into[key] = true
    end
end
local SELECTOR_OFFSETS = 0x40000000

local function reader(cache)
    local wide = cache.architecture:startswith("arm64")
    local size = wide and 8 or 4
    local strings = {}
    local selector_base
    local objc_offset, objc_size = cache.field(cache.main, 0x1d0, "<I8"), cache.field(cache.main, 0x1d8, "<I8")
    if objc_offset and objc_size and objc_size >= 56 then
        local base_address = string.unpack("<I8", cache.read(cache.main, cache.main.mapping_offset, 8))
        local header = cache.read_address(base_address + objc_offset, 56)
        selector_base = base_address + string.unpack("<I8", header, 48 + 1)
    else
        for _, loaded in ipairs(cache.images) do
            if loaded.install == "/usr/lib/libobjc.A.dylib" then
                for _, section in ipairs(loaded.image.sections) do
                    if section.name == "__objc_opt_ro" and section.size >= 48 then
                        local opt = cache.read_address(section.addr, 48)
                        if string.unpack("<I4", opt, 1) >= 16 then
                            selector_base = section.addr + string.unpack("<i8", opt, 40 + 1)
                        end
                    end
                end
            end
        end
    end
    local self = {wide = wide, size = size, mapped = cache.mapped, relative_lists = cache.file or cache.main.mapping_offset >= 0x138}
    function self.pointer(address)
        if not cache.mapped(address, size) then
            return 0
        end
        return cache.pointer_at(address, wide)
    end
    function self.u32(address)
        return string.unpack("<I4", cache.read_address(address, 4))
    end
    function self.i32(address)
        return string.unpack("<i4", cache.read_address(address, 4))
    end
    function self.string(address)
        if address == 0 or not cache.mapped(address) then
            return nil
        end
        local found = strings[address]
        if not found then
            found = cache.string_at(address)
            strings[address] = found
        end
        return found
    end
    function self.selector_base()
        if not selector_base then
            raise("%s lists methods by selector offsets but names no Objective-C optimization header", cache.main.path)
        end
        return selector_base
    end
    return self
end

local function method_list(read, address, names)
    local flags, count = read.u32(address), read.u32(address + 4)
    local entry_size = flags & 0xFFFC
    if entry_size == 0 or not read.mapped(address + 8, count * entry_size) then
        return names
    end
    for index = 0, count - 1 do
        local entry = address + 8 + index * entry_size
        local name
        if read.relative_lists and flags & RELATIVE_METHODS ~= 0 then
            local offset = read.i32(entry)
            if flags & SELECTOR_OFFSETS ~= 0 then
                name = read.string(read.selector_base() + offset)
            else
                name = read.string(read.pointer(entry + offset))
            end
        else
            name = read.string(read.pointer(entry))
        end
        if name then
            names["-" .. name] = true
        end
    end
end

local function lists(read, address, each)
    if address == 0 then
        return
    end
    if read.wide and address & 1 ~= 0 then
        local list = address & ~1
        if not read.mapped(list, 8) then
            return
        end
        local entry_size, count = read.u32(list), read.u32(list + 4)
        if entry_size ~= 8 or not read.mapped(list + 8, count * 8) then
            return
        end
        for index = 0, count - 1 do
            local entry = list + 8 + index * 8
            local packed = string.unpack("<i8", read.raw(entry, 8))
            local offset = packed >> 16
            if offset >= 0x800000000000 then
                offset = offset - 0x1000000000000
            end
            each(entry + offset)
        end
        return
    end
    each(address)
end

local function method_names(read, address)
    local names = {}
    lists(read, address, function (list)
        if read.mapped(list, 8) then
            method_list(read, list, names)
        end
    end)
    return names
end

local function protocol_list(read, address, names)
    if not read.mapped(address, read.size) then
        return
    end
    local count = read.wide and string.unpack("<I8", read.raw(address, 8)) or read.u32(address)
    if not read.mapped(address, (count + 1) * read.size) then
        return
    end
    for index = 0, count - 1 do
        local protocol = read.pointer(address + read.size * (index + 1))
        local name = protocol ~= 0 and read.mapped(protocol, 2 * read.size) and read.string(read.pointer(protocol + read.size))
        if name then
            names[name] = true
        end
    end
end

local function protocol_names(read, address)
    local names = {}
    lists(read, address, function (list)
        protocol_list(read, list, names)
    end)
    return names
end

local function class_data(read, class)
    if class == 0 or not read.mapped(class, 5 * read.size) then
        return {methods = 0, protocols = 0}
    end
    local data = read.pointer(class + 4 * read.size) & (read.wide and ~7 or ~3)
    if not read.mapped(data, 7 * read.size) then
        return {methods = 0, protocols = 0}
    end
    local offsets = read.wide and {name = 24, methods = 32, protocols = 40} or {name = 16, methods = 20, protocols = 24}
    return {
        name = read.string(read.pointer(data + offsets.name)),
        methods = read.pointer(data + offsets.methods),
        protocols = read.pointer(data + offsets.protocols)
    }
end

local function section_entries(read, image, wanted)
    local entries = {}
    for _, section in ipairs(image.sections) do
        if section.name == wanted then
            for index = 0, section.size // read.size - 1 do
                table.insert(entries, read.pointer(section.addr + index * read.size))
            end
        end
    end
    return entries
end

-- The classes, protocols and categories every image of a source carries, one entry per class: its own method
-- lists, the class methods of its metaclass, the protocols it adopts, and the selectors every category in
-- every image adds to it. Both category sections are read, and they answer two different questions, so the
-- caller decides what to do with the answer: `__objc_catlist` is a category Apple's or the port's own image
-- carries, and `__charon_catlist` is the same section renamed by the link in backports.lua, so it holds
-- nothing but this repository's own categories. A class of a release is read by inventory(), which refuses an
-- image carrying the second (release_only below); a class of a band is read by binary_inventory and
-- binary_categories, where the port's own categories are the answer the caller asked for.
local function collect(cache)
    local read = reader(cache)
    function read.raw(address, count)
        return cache.read_address(address, count)
    end
    local classes, protocols = {}, {}
    local extensions = {instance = {}, class = {}, protocols = {}}
    local port = {}
    local function entry(name)
        local found = classes[name]
        if not found then
            found = {instance = {}, class = {}, protocols = {}}
            classes[name] = found
        end
        return found
    end
    for _, loaded in ipairs(cache.images) do
        for _, class in ipairs(section_entries(read, loaded.image, "__objc_classlist")) do
            local data = class_data(read, class)
            if data.name then
                local found = entry(data.name)
                found.image = loaded.install
                local superclass = read.pointer(class + read.size)
                found.superclass = superclass ~= 0 and class_data(read, superclass).name or nil
                merge(found.instance, method_names(read, data.methods))
                merge(found.protocols, protocol_names(read, data.protocols))
                local metaclass = read.pointer(class)
                if metaclass ~= 0 then
                    merge(found.class, method_names(read, class_data(read, metaclass).methods))
                end
            end
        end
        local charon = section_entries(read, loaded.image, "__charon_catlist")
        if #charon > 0 then
            table.insert(port, loaded.install)
        end
        for _, category in ipairs(table.join(section_entries(read, loaded.image, "__objc_catlist"), charon)) do
            local class = read.pointer(category + read.size)
            local bound = cache.bound and cache.bound[category + read.size]
            local name = class ~= 0 and class_data(read, class).name or (bound and bound:match("^_OBJC_CLASS_%$_(.+)$"))
            local found = name and entry(name) or extensions
            merge(found.instance, method_names(read, read.pointer(category + 2 * read.size)))
            merge(found.class, method_names(read, read.pointer(category + 3 * read.size)))
            merge(found.protocols, protocol_names(read, read.pointer(category + 4 * read.size)))
        end
        for _, protocol in ipairs(section_entries(read, loaded.image, "__objc_protolist")) do
            local name = read.string(read.pointer(protocol + read.size))
            if name then
                local found = protocols[name] or {instance = {}, class = {}}
                merge(found.instance, method_names(read, read.pointer(protocol + 3 * read.size)))
                merge(found.class, method_names(read, read.pointer(protocol + 4 * read.size)))
                merge(found.instance, method_names(read, read.pointer(protocol + 5 * read.size)))
                merge(found.class, method_names(read, read.pointer(protocol + 6 * read.size)))
                protocols[name] = found
            end
        end
    end
    return {architecture = cache.architecture, classes = classes, protocols = protocols, extensions = extensions, port = port, read = read}
end

local function file_source(binary, architecture)
    local data = macho.read(binary)
    local image
    for _, candidate in ipairs(macho.images(data)) do
        if candidate.architecture == architecture then
            image = candidate
        end
    end
    if not image then
        return nil
    end
    local wide = image.wide
    local text_address = 0
    for _, segment in ipairs(image.segments) do
        if segment.name == "__TEXT" then
            text_address = segment.vmaddr
        end
    end
    local function locate(address, size)
        for _, segment in ipairs(image.segments) do
            if segment.vmaddr <= address and address + size <= segment.vmaddr + segment.vmsize and segment.fileoff + (address - segment.vmaddr) + size <= #data then
                return image.base + segment.fileoff + (address - segment.vmaddr)
            end
        end
    end
    local source = {file = true, architecture = architecture, main = {mapping_offset = 0}, images = {{install = image.identity or binary, image = image}},
                    bound = macho.bound_slots(data, image)}
    function source.field()
        return nil
    end
    function source.mapped(address, size)
        return locate(address, size or 1) ~= nil
    end
    function source.read_address(address, size)
        local at = locate(address, size) or raise("address %#x is outside the segments of %s", address, binary)
        return data:sub(at + 1, at + size)
    end
    function source.pointer_at(address, pointer_wide)
        local value = string.unpack(pointer_wide and "<I8" or "<I4", source.read_address(address, pointer_wide and 8 or 4))
        if pointer_wide and image.chained_fixups and value ~= 0 then
            if value >> 63 ~= 0 then
                return 0
            end
            local target = value & 0xFFFFFFFFF
            if target < text_address then
                target = target + text_address
            end
            return target | (((value >> 36) & 0xFF) << 56)
        end
        return value
    end
    function source.string_at(address)
        local at = locate(address, 1)
        if not at then
            return nil
        end
        local finish = data:find("\0", at + 1, true)
        return data:sub(at + 1, (finish or #data + 1) - 1)
    end
    function source.close()
    end
    return source, image
end

local function gather(into, found)
    for name, class in pairs(found.classes) do
        local kept = into.classes[name]
        if not kept then
            kept = {instance = {}, class = {}, protocols = {}}
            into.classes[name] = kept
        end
        kept.image = kept.image or class.image
        kept.superclass = kept.superclass or class.superclass
        merge(kept.instance, class.instance)
        merge(kept.class, class.class)
        merge(kept.protocols, class.protocols)
    end
    for name, protocol in pairs(found.protocols) do
        local kept = into.protocols[name]
        if not kept then
            kept = {instance = {}, class = {}}
            into.protocols[name] = kept
        end
        merge(kept.instance, protocol.instance)
        merge(kept.class, protocol.class)
    end
    merge(into.extensions.instance, found.extensions.instance)
    merge(into.extensions.class, found.extensions.class)
    merge(into.extensions.protocols, found.extensions.protocols)
    table.join2(into.port, found.port)
end

-- A release's own Objective-C metadata, or the reading is not one. An image this repository built renames its
-- category section to __charon_catlist (backports.lua links every library that way), and collect() reads that
-- section beside __objc_catlist because a built object is the port's own code: every caller of binary_inventory
-- and binary_categories reads an object of a band and wants both. Fed a folder that holds such a library,
-- inventory() would answer "the release and the port" for every class the port extends, and a registry row
-- written from that claims of the release a method only the backport defines - which is the reading
-- modules/apple/backports.lua keeps and the tests/addon/objc_test.lua cases object_failures and
-- selector_failures require. Measured 2026-10-03: none of the 354 images of the held 4.3 armv7 cache carries
-- the section, so this refuses nothing the tree reads today. Read a built library with binary_inventory, or
-- take it out of the folder that holds the release's own libraries.
local function release_only(source, found)
    if #found.port > 0 then
        raise("%s holds %d image%s this repository built, whose category section is renamed to __charon_catlist: a release's own metadata is what inventory() reads, and the port's categories merged into it would make every class the port extends look like the release's own. Read such a library with binary_inventory, or take it out of the folder that holds the release's libraries",
              source, #found.port, #found.port == 1 and "" or "s")
    end
end

function inventory(source)
    local architecture = path.filename(source):match("^libraries_([%w_]+)$")
    if not architecture then
        local cache = dyld.open_cache(source)
        local found = collect(cache)
        cache.close()
        found.read = nil
        release_only(source, found)
        return found
    end
    local found = {architecture = architecture, classes = {}, protocols = {}, port = {},
                   extensions = {instance = {}, class = {}, protocols = {}}}
    local read = 0
    for _, binary in ipairs(macho.binaries_under(source)) do
        local file = file_source(binary, architecture)
        if file then
            gather(found, collect(file))
            read = read + 1
        end
    end
    if read == 0 then
        raise("%s holds no %s library to read Objective-C metadata from", source, architecture)
    end
    release_only(source, found)
    return found
end

local function add_selectors(into, found)
    for _, class in pairs(found.classes) do
        merge(into, class.instance)
        merge(into, class.class)
    end
    merge(into, found.extensions.instance)
    merge(into, found.extensions.class)
    for _, protocol in pairs(found.protocols or {}) do
        merge(into, protocol.instance)
        merge(into, protocol.class)
    end
end

function binary_selectors(binary, architecture)
    local source, image = file_source(binary, architecture)
    if not source then
        return nil
    end
    local found = collect(source)
    local implemented = {}
    add_selectors(implemented, found)
    for _, selector in ipairs(section_entries(found.read, image, "__charon_addsel")) do
        local name = found.read.string(selector)
        if name then
            implemented["-" .. name] = true
        end
    end
    local used = {}
    for _, selector in ipairs(section_entries(found.read, image, "__objc_selrefs")) do
        local name = found.read.string(selector)
        if name then
            used["-" .. name] = true
        end
    end
    return {used = used, implemented = implemented}
end


function binary_inventory(binary, architecture)
    local source = file_source(binary, architecture)
    if not source then
        return nil
    end
    local found = collect(source)
    found.read = nil
    return found
end

-- The categories of a binary with the class each one names: `class` when the binary
-- defines the class itself, `bound` (the symbol) when dyld binds the reference. A
-- reference under chained fixups is neither: this reads classic bind opcodes only.
-- `instance` and `class_methods` hold the selectors each adds, keyed as the inventory keys them.
-- A binary here is an object of a band, so its own renamed categories are part of the answer: the check in
-- backports.lua that reads this asks whether each of them is attached at all, which is a question about the
-- port's own code and not about the release.
function binary_categories(binary, architecture)
    local source, image = file_source(binary, architecture)
    if not source then
        return nil
    end
    local read = reader(source)
    local found = {}
    for _, category in ipairs(table.join(section_entries(read, image, "__objc_catlist"), section_entries(read, image, "__charon_catlist"))) do
        local class = read.pointer(category + read.size)
        table.insert(found, {name = read.string(read.pointer(category)), class = class ~= 0 and class_data(read, class).name or nil,
                             bound = source.bound[category + read.size],
                             instance = method_names(read, read.pointer(category + 2 * read.size)),
                             class_methods = method_names(read, read.pointer(category + 3 * read.size))})
    end
    return found
end

-- The aliases of charon_alias.h a binary records: the release's class name each of its
-- own classes stands in for.
function binary_aliases(binary, architecture)
    local source, image = file_source(binary, architecture)
    if not source then
        return nil
    end
    local read = reader(source)
    local found = {}
    for _, section in ipairs(image.sections) do
        if section.segment == "__DATA" and section.name == "__charon_alias" then
            for index = 0, section.size // (2 * read.size) - 1 do
                local entry = section.addr + index * 2 * read.size
                local proxy = class_data(read, read.pointer(entry)).name
                local name = read.string(read.pointer(entry + read.size))
                if proxy and name then
                    found[proxy] = name
                end
            end
        end
    end
    return found
end

-- What the reader itself is, as a short key: the three files whose code decides which name a byte pattern is
-- read as. Memoised, because known_selectors() is on the path of every binary the platform checks.
local READER_KEY
local function reader_key()
    if not READER_KEY then
        local parts = {}
        for _, name in ipairs({"objc.lua", "dyld.lua", "macho.lua"}) do
            table.insert(parts, hash.strhash128(io.readfile(path.join(os.scriptdir(), name))))
        end
        READER_KEY = hash.strhash32(table.concat(parts, "\n"))
    end
    return READER_KEY
end

-- Every selector name the release's own Objective-C metadata carries, keyed "-name". The names are kept in a
-- file beside the release, and the mtime of the source decides that the file is current - but a shared cache
-- taken out of a firmware keeps that firmware's own mtime (2011 for the held 4.3 one, 2013 for 6.1.3), so the
-- comparison stays true for the machine's lifetime and a reader that has changed is never read at all. The
-- file therefore carries the key of the reader that wrote it, beside it in a file of its own: the name stays
-- what it is, because tools/corpus/{crash-demand,observed}.py and tests/backports/host/mediaplayeritem/README.md
-- read it by that name, and what a
-- reader may answer with is the question the key settles. Measured 2026-10-03: the list beside the held 4.3
-- armv7 cache holds 70062 names and answers exactly what a fresh reading of that cache answers, and it names
-- isPaused, deviceName, isAsynchronous and distance - which the cache's own images do carry, on
-- AVCaptureVideoPreviewLayer and SSDownloadStatus, on CADisplay, ISDevice, UIHardware,
-- PLAirPlayBackgroundView, GKDevice and CAWindowServerDisplay, on NSOperation, and on MKRouteStep,
-- MKMapViewPositioningChange, SCRCGestureFactory and two OfficeImport classes. A selector belongs to no named
-- class, so a name the platform carries is no evidence about a class of it, and no image of a release carries
-- a __charon_catlist: none of the 354 images of the held 4.3 armv7 cache, none of the 524 of 6.1.3, and none
-- of the 581 files the store keeps in the four libraries_<arch> folders it has (1.1.4, 2.2.1 and 3.0).
function known_selectors(source)
    local architecture = path.filename(source):match("^dyld_shared_cache_([%w_]+)") or path.filename(source):match("^libraries_([%w_]+)$")
    local list = path.join(path.directory(source), "selectors_" .. architecture .. ".txt")
    local written_by = list .. ".reader"
    local known = {}
    if os.isfile(list) and os.isfile(written_by) and io.readfile(written_by) == reader_key() and os.mtime(list) >= os.mtime(source) then
        for line in io.readfile(list):gmatch("[^\n]+") do
            known["-" .. line] = true
        end
        return known
    end
    add_selectors(known, inventory(source))
    local names = {}
    for key in pairs(known) do
        table.insert(names, key:sub(2))
    end
    byteorder.sort(names)
    io.writefile(list, table.concat(names, "\n") .. "\n")
    io.writefile(written_by, reader_key())
    return known
end

function absent_selectors(source, binaries, architecture)
    local known = known_selectors(source)
    local results, implemented = {}, {}
    local found = {}
    for _, binary in ipairs(binaries) do
        local selectors = binary_selectors(binary, architecture)
        if selectors then
            found[binary] = selectors
            merge(implemented, selectors.implemented)
        end
    end
    for binary, selectors in pairs(found) do
        local missing = {}
        for key in pairs(selectors.used) do
            if not implemented[key] and not known[key] then
                table.insert(missing, key:sub(2))
            end
        end
        if #missing > 0 then
            byteorder.sort(missing)
            results[binary] = missing
        end
    end
    return results
end

local function method_entries(read, address, each)
    lists(read, address, function (list)
        if not read.mapped(list, 8) then
            return
        end
        local flags, count = read.u32(list), read.u32(list + 4)
        local entry_size = flags & 0xFFFC
        if entry_size == 0 or not read.mapped(list + 8, count * entry_size) then
            return
        end
        for index = 0, count - 1 do
            local entry = list + 8 + index * entry_size
            local name, imp
            if read.relative_lists and flags & RELATIVE_METHODS ~= 0 then
                local offset = read.i32(entry)
                name = flags & SELECTOR_OFFSETS ~= 0 and read.string(read.selector_base() + offset) or read.string(read.pointer(entry + offset))
                imp = entry + 8 + read.i32(entry + 8)
            else
                name = read.string(read.pointer(entry))
                imp = read.pointer(entry + 2 * read.size)
            end
            if name then
                each(name, imp)
            end
        end
    end)
end

local function class_ro(read, class)
    if class == 0 or not read.mapped(class, 5 * read.size) then
        return nil
    end
    local data = read.pointer(class + 4 * read.size) & (read.wide and ~7 or ~3)
    if not read.mapped(data, 10 * read.size) then
        return nil
    end
    local wide = read.wide
    return {flags = read.u32(data), name = read.string(read.pointer(data + (wide and 24 or 16))),
            methods = read.pointer(data + (wide and 32 or 20)), ivars = read.pointer(data + (wide and 48 or 28))}
end

function code_map(cachefile)
    local cache = dyld.open_cache(cachefile)
    local read = reader(cache)
    function read.raw(address, count)
        return cache.read_address(address, count)
    end
    local images = {}
    for _, loaded in ipairs(cache.images) do
        local found = {install = loaded.install, address = loaded.address, sections = {}, methods = {}, ivars = {}, classes = {},
                       selrefs = {}, classrefs = {}, superrefs = {}}
        for _, section in ipairs(loaded.image.sections) do
            table.insert(found.sections, {segment = section.segment, name = section.name, addr = section.addr, size = section.size, kind = section.flags & 0xFF})
        end
        local function add_methods(class_name, meta, category, address)
            method_entries(read, address, function (name, imp)
                table.insert(found.methods, {class_name, meta, name, imp, category})
            end)
        end
        for _, class in ipairs(section_entries(read, loaded.image, "__objc_classlist")) do
            local ro = class_ro(read, class)
            if ro and ro.name then
                local superclass = read.pointer(class + read.size)
                local super_ro = superclass ~= 0 and class_ro(read, superclass)
                table.insert(found.classes, {ro.name, super_ro and super_ro.name or nil})
                add_methods(ro.name, false, nil, ro.methods)
                local meta_ro = class_ro(read, read.pointer(class))
                if meta_ro then
                    add_methods(ro.name, true, nil, meta_ro.methods)
                end
                if ro.ivars ~= 0 and read.mapped(ro.ivars, 8) then
                    local entry_size, count = read.u32(ro.ivars), read.u32(ro.ivars + 4)
                    for index = 0, count - 1 do
                        local entry = ro.ivars + 8 + index * entry_size
                        if read.mapped(entry, entry_size) then
                            table.insert(found.ivars, {ro.name, read.string(read.pointer(entry + read.size)), read.pointer(entry)})
                        end
                    end
                end
            end
        end
        for _, category in ipairs(section_entries(read, loaded.image, "__objc_catlist")) do
            local class = read.pointer(category + read.size)
            local ro = class ~= 0 and class_ro(read, class)
            local category_name = read.string(read.pointer(category))
            if ro and ro.name then
                add_methods(ro.name, false, category_name or "?", read.pointer(category + 2 * read.size))
                add_methods(ro.name, true, category_name or "?", read.pointer(category + 3 * read.size))
            end
        end
        for _, section in ipairs(loaded.image.sections) do
            if section.name == "__objc_selrefs" then
                for index = 0, section.size // read.size - 1 do
                    local slot = section.addr + index * read.size
                    local name = read.string(read.pointer(slot))
                    if name then
                        table.insert(found.selrefs, {slot, name})
                    end
                end
            elseif section.name == "__objc_classrefs" or section.name == "__objc_superrefs" then
                local into = section.name == "__objc_classrefs" and found.classrefs or found.superrefs
                for index = 0, section.size // read.size - 1 do
                    local slot = section.addr + index * read.size
                    local ro = class_ro(read, read.pointer(slot))
                    if ro and ro.name then
                        table.insert(into, {slot, ro.name, ro.flags & 1 ~= 0})
                    end
                end
            end
        end
        local symbols = dyld.image_symbols(cache, loaded)
        found.exports, found.reexports, found.indirect, found.function_starts = symbols.exports, symbols.reexports, symbols.indirect, symbols.function_starts
        table.insert(images, found)
    end
    local header = {architecture = cache.architecture, mappings = {}}
    cache.close()
    return {architecture = header.architecture, images = images}
end

-- The code address of every method the named classes define themselves, keyed by class then selector,
-- with the bytes sitting at that address. inventory() answers WHICH selectors a class carries and drops
-- the address, because a corpus row asks that; a question about what a method DOES needs the code, and
-- the code is in the cache beside the metadata - measured 2026-10-03 on the arm64e cache of iOS 16.0 for
-- the ten HomeKit classes whose -init the port had to decide by.
--
-- One pass for the whole set of names: a pass over an arm64e cache costs minutes (8 measured on the cache
-- of iOS 18.0), so ten classes must not be ten passes. `count` is how many bytes to carry per method.
function method_imps(source, asked, count)
    count = count or 512
    local wanted = {}
    for _, name in ipairs(asked) do
        wanted[name] = true
    end
    local cache = dyld.open_cache(source)
    local read = reader(cache)
    function read.raw(address, bytes)
        return cache.read_address(address, bytes)
    end
    local found, order = {}, {}
    local function gather(methods, into)
        method_entries(read, methods, function (name, imp)
            if name and imp then
                into[name] = imp
            end
        end)
    end
    for _, loaded in ipairs(cache.images) do
        for _, class in ipairs(section_entries(read, loaded.image, "__objc_classlist")) do
            local data = class_data(read, class)
            if data.name and wanted[data.name] and not found[data.name] then
                local methods = {}
                gather(data.methods, methods)
                local metaclass = read.pointer(class)
                if metaclass ~= 0 then
                    gather(class_data(read, metaclass).methods, methods)
                end
                found[data.name] = {image = loaded.install, methods = methods}
                table.insert(order, data.name)
            end
        end
    end
    local named = {}
    for _, name in ipairs(order) do
        local entry = found[name]
        local bytes = {}
        for selector, imp in pairs(entry.methods) do
            if read.mapped(imp, 4) then
                bytes[selector] = read.raw(imp, count) or ""
            else
                bytes[selector] = ""
            end
        end
        named[name] = {image = entry.image, methods = entry.methods, bytes = bytes}
    end
    cache.close()
    return named
end

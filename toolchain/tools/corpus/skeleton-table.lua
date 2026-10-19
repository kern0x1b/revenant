local dyld_module = "apple.dyld"

local function open(root, cachefile)
    local dyld = import(dyld_module, {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    return dyld.open_cache(cachefile)
end

local function images(cache, wanted)
    local found = {}
    for _, loaded in ipairs(cache.images) do
        if loaded.install:find(wanted, 1, true) then
            local sections = {}
            for _, section in ipairs(loaded.image.sections) do
                table.insert(sections, {loaded.install .. " " .. section.name, section.addr,
                                        section.addr + section.size})
            end
            table.insert(found, {loaded, sections})
        end
    end
    return found
end

local function where(sections, address)
    for _, hit in ipairs(sections) do
        if address >= hit[2] and address < hit[3] then return hit[1] end
    end
    return "no image section"
end

local function pointer(cache, address)
    local raw = cache.read_address(address, 8)
    if not raw then return nil end
    local masked = string.unpack("<I8", raw) & 0xFFFFFFFFF
    if cache.mapped(masked, 1) then return masked end
    local pointed = cache.pointer_at(address, true)
    if type(pointed) == "number" and cache.mapped(pointed, 1) then return pointed end
    return nil
end

local function number(cache, address)
    local raw = cache.read_address(address, 8)
    if not raw then return nil end
    local value = string.unpack("<i8", raw)
    if value >= 0x8000000000000000 then return value - 0x10000000000000000 end
    return value
end

local function names(cache, sections, minimum)
    local lo, hi
    for _, hit in ipairs(sections) do
        if hit[1]:match("__cstring$") then lo, hi = hit[2], hit[3] end
    end
    if not lo then
        print("#no __cstring in that image")
        return
    end
    for _, section in ipairs(sections) do
        local name = section[1]:match("([^ ]+)$")
        if name == "__const" or name == "__data" or name == "__objc_const" then
            local data = cache.read_address(section[2], section[3] - section[2])
            if data then
                local run, start = {}, nil
                for offset = 0, #data - 8, 8 do
                    local value = string.unpack("<I8", data, offset + 1) & 0xFFFFFFFFF
                    local text
                    if value >= lo and value < hi then
                        text = cache.string_at(value)
                    end
                    if text and #text > 0 and #text < 64 then
                        if not start then start = section[2] + offset end
                        table.insert(run, text)
                    else
                        if #run >= minimum then
                            print(string.format("%#x\t%d\t%s", start, #run, table.concat(run, ",")))
                        end
                        run, start = {}, nil
                    end
                end
                if #run >= minimum then
                    print(string.format("%#x\t%d\t%s", start, #run, table.concat(run, ",")))
                end
            end
        end
    end
end

local function parents(cache, sections, at)
    local count = number(cache, at + 8)
    local values = pointer(cache, at + 16)
    print(string.format("array %#x count=%d values=%#x (%s)", at, count or 0, values or 0,
                        where(sections, values or 0)))
    for index = 0, (count or 0) - 1 do
        local value = pointer(cache, values + index * 8)
        if not value then
            print(string.format("  [%d] not a pointer in any mapping", index))
        else
            local words = {}
            for word = 0, 3 do words[word + 1] = number(cache, value + word * 8) end
            print(string.format("  [%d] %#x (%s) words %s %s %s %s", index, value, where(sections, value),
                                tostring(words[1]), tostring(words[2]), tostring(words[3]), tostring(words[4])))
        end
    end
end

local function impls(cache, wanted, class_wanted, only)
    local wide = cache.architecture:startswith("arm64")
    local size = wide and 8 or 4
    local strings, selector_base = {}, nil
    local function str(address)
        if address == 0 or not cache.mapped(address) then return nil end
        if strings[address] == nil then
            try {
                function ()
                    strings[address] = cache.string_at(address)
                end,
                catch {
                    function ()
                        strings[address] = false
                    end
                }
            }
            if strings[address] == nil then
                strings[address] = false
            end
            if strings[address] == false then
                local out = {}
                for index = 0, 255, 8 do
                    local chunk = cache.read_address(address + index, 8)
                    if not chunk then break end
                    local finish = chunk:find("\0", 1, true)
                    if finish then
                        table.insert(out, chunk:sub(1, finish - 1))
                        break
                    end
                    table.insert(out, chunk)
                end
                strings[address] = #out > 0 and table.concat(out) or false
            end
        end
        return strings[address] ~= false and strings[address] or nil
    end
    if not selector_base then
        local offset = cache.field(cache.main, 0x1d0, "<I8")
        if offset then
            local base_address = string.unpack("<I8", cache.read(cache.main, cache.main.mapping_offset, 8))
            local header = cache.read_address(base_address + offset, 56)
            selector_base = base_address + string.unpack("<I8", header, 48 + 1)
        end
    end
    if not selector_base then
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
    assert(selector_base, "no Objective-C optimization header: a direct selector cannot be read")
    local relative = cache.file or cache.main.mapping_offset >= 0x138
    local function pointer_at(address)
        if not cache.mapped(address, size) then return 0 end
        return cache.pointer_at(address, wide)
    end
    local function class_data(class)
        if class == 0 or not cache.mapped(class, 5 * size) then return nil end
        local data = pointer_at(class + 4 * size) & (wide and ~7 or ~3)
        if not cache.mapped(data, 7 * size) then return nil end
        local offsets = wide and {name = 24, methods = 32} or {name = 16, methods = 20}
        local metaclass = pointer_at(class)
        local meta_data = metaclass ~= 0 and pointer_at(metaclass + 4 * size) & (wide and ~7 or ~3)
        return {name = str(pointer_at(data + offsets.name)), methods = pointer_at(data + offsets.methods),
                meta = meta_data ~= nil and cache.mapped(meta_data, 7 * size) and
                       pointer_at(meta_data + offsets.methods) or 0}
    end
    for _, loaded in ipairs(cache.images) do
        if loaded.install:find(wanted, 1, true) then
            for _, section in ipairs(loaded.image.sections) do
                if section.name == "__objc_classlist" then
                    for index = 0, section.size // size - 1 do
                        local class = pointer_at(section.addr + index * size)
                        local data = class_data(class)
                        if data and data.name == class_wanted then
                            local function one(list)
                                if not cache.mapped(list, 8) then return end
                                local flags, count = string.unpack("<I4I4", cache.read_address(list, 8))
                                local entry_size = flags & 0xFFFC
                                print(string.format("#  entsize_and_flags=%#x count=%d entsize=%d small=%s selector_base=%s relative=%s",
                                                    flags, count, entry_size, tostring(flags & 1 ~= 0),
                                                    selector_base and string.format("%#x", selector_base) or "-",
                                                    tostring(relative)))
                                if entry_size == 0 or not cache.mapped(list + 8, count * entry_size) then return end
                                for slot = 0, count - 1 do
                                    local entry = list + 8 + slot * entry_size
                                    local name
                                    if flags & 1 ~= 0 then
                                        name = str(selector_base + string.unpack("<i4", cache.read_address(entry, 4)))
                                    elseif relative and flags & 0x800 ~= 0 then
                                        name = str(pointer_at(entry + string.unpack("<i4", cache.read_address(entry, 4))))
                                    else
                                        name = str(pointer_at(entry))
                                    end
                                    local imp
                                    if flags & 1 ~= 0 then
                                        local field = entry + 8
                                        imp = (field + string.unpack("<i4", cache.read_address(field, 4)))
                                    else
                                        imp = pointer_at(entry + entry_size - size)
                                    end
                                    if name and (not only or name == only) then
                                        print(string.format("%s\t%#x", name, imp))
                                    end
                                end
                            end
                            local function list_at(list, label)
                                print(string.format("#%s list=%#x", label, list))
                                if wide and list & 1 ~= 0 then
                                    local entry_size, count = string.unpack("<I4I4", cache.read_address(list & ~1, 8))
                                    if entry_size == 8 then
                                        for slot = 0, count - 1 do
                                            local entry = (list & ~1) + 8 + slot * 8
                                            local packed = string.unpack("<i8", cache.read_address(entry, 8))
                                            local delta = packed >> 16
                                            if delta >= 0x800000000000 then delta = delta - 0x1000000000000 end
                                            one(entry + delta)
                                        end
                                    end
                                elseif list ~= 0 then
                                    one(list)
                                end
                            end
                            list_at(data.methods, "instance")
                            list_at(data.meta or 0, "class")
                        end
                    end
                end
            end
        end
    end
end

local function texts(cache, addresses)
    for _, address in ipairs(addresses) do
        local holder = "no image section"
        for _, loaded in ipairs(cache.images) do
            for _, section in ipairs(loaded.image.sections) do
                if address >= section.addr and address < section.addr + section.size then
                    holder = loaded.install .. " " .. section.name
                end
            end
        end
        local text = cache.string_at(address)
        if not text then
            local out = {}
            for index = 0, 255, 8 do
                local chunk = cache.read_address(address + index, 8)
                if not chunk then break end
                local finish = chunk:find("\0", 1, true)
                if finish then
                    table.insert(out, chunk:sub(1, finish - 1))
                    break
                end
                table.insert(out, chunk)
            end
            text = #out > 0 and table.concat(out) or nil
        end
        print(string.format("%#x\t%s\t%s", address, text and text:gsub("[^\32-\126]", ".") or "(not a string)",
                            holder))
    end
end

local function bytes(cache, sections, low, count)
    local data = cache.read_address(low, count)
    if not data then
        print(string.format("#no bytes at %#x (%s)", low, where(sections, low)))
        return
    end
    if #data ~= count then
        print(string.format("#short read at %#x: asked %d, read %d", low, count, #data))
    end
    print(string.format("#%#x %d", low, #data))
    local hex = data:gsub(".", function (byte) return string.format("%02x", byte:byte()) end)
    for offset = 0, #hex - 1, 64 do
        print(string.sub(hex, offset + 1, offset + 64))
    end
end

local function functions(dyld, cache, wanted, low, high)
    for _, loaded in ipairs(cache.images) do
        if loaded.install:find(wanted, 1, true) then
            local addresses = {}
            for _, entry in ipairs(dyld.image_symbols(cache, loaded).function_starts or {}) do
                local address = type(entry) == "table" and tonumber(entry[1]) or tonumber(entry)
                if address and address >= low and address < high then table.insert(addresses, address) end
            end
            table.sort(addresses)
            print("#starts in window: " .. #addresses)
            for index, address in ipairs(addresses) do
                local next_address = addresses[index + 1]
                print(string.format("%#x", address), next_address and string.format("+%#x", next_address - address) or "")
            end
        end
    end
end

function main(cachefile, wanted, what, ...)
    local arguments = {...}
    local dyld = import(dyld_module, {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = dyld.open_cache(cachefile)
    local found = images(cache, wanted)
    assert(#found > 0, "no image of that cache has an install name containing " .. tostring(wanted))
    local sections = found[1][2]
    print(string.format("#cache %s image %s", cache.architecture, found[1][1].install))
    if what == "names" then
        local minimum = tonumber(arguments[1]) or 8
        names(cache, sections, minimum)
    elseif what == "parents" then
        local at = tonumber(arguments[1], 16)
        assert(at, "usage: skeleton-table.lua <cache> <image> parents <cfarray address>")
        parents(cache, sections, at)
    elseif what == "impls" then
        local class_wanted, only = arguments[1], arguments[2]
        assert(class_wanted, "usage: skeleton-table.lua <cache> <image> impls <class> [selector]")
        impls(cache, wanted, class_wanted, only)
    elseif what == "functions" then
        local low, high = tonumber(arguments[1], 16), tonumber(arguments[2], 16)
        assert(low and high, "usage: skeleton-table.lua <cache> <image> functions <lo> <hi>")
        functions(dyld, cache, wanted, low, high)
    elseif what == "sections" then
        for index = 0, 255, 1 do
            local entry = cache.read(cache.main, cache.main.mapping_offset + index * 32, 24)
            if not entry then break end
            local address, size = string.unpack("<I8I8", entry)
            if size == 0 then break end
            print(string.format("#mapping %d %#x .. %#x", index, address, address + size - 1))
        end
        for _, hit in ipairs(found) do
            print(string.format("#%s", hit[1].install))
            for _, section in ipairs(hit[1].image.sections) do
                print(string.format("  %-24s %#x .. %#x", section.name, section.addr,
                                    section.addr + section.size - 1))
            end
        end
    elseif what == "texts" then
        local addresses = {}
        for _, text in ipairs(arguments) do
            local address = tonumber(text, 16)
            assert(address, "usage: skeleton-table.lua <cache> <image> texts <address>...")
            table.insert(addresses, address)
        end
        assert(#addresses > 0, "usage: skeleton-table.lua <cache> <image> texts <address>...")
        texts(cache, addresses)
    elseif what == "bytes" then
        local low = tonumber(arguments[1], 16)
        local count = tonumber(arguments[2])
        assert(low and count, "usage: skeleton-table.lua <cache> <image> bytes <lo> <count>")
        bytes(cache, sections, low, count)
    else
        error("what must be names, parents, impls, functions, sections, texts or bytes, not "
              .. tostring(what))
    end
    cache.close()
end

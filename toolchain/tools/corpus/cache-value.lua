function main(cachefile, symbolfile)
    assert(cachefile and symbolfile, "usage: cache-value.lua <cache file> <symbols file>")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("REVENANT_ROOT"), "modules"), anonymous = true})
    local wanted, order = {}, {}
    for line in io.lines(symbolfile) do
        local name, width, pointer, text = line:match("^([^\t]+)\t(%S+)\t([^\t]*)\t([^\t]*)$")
        if name and not wanted[name] then
            wanted[name] = {width = width, pointer = pointer == "p", text = text == "s"}
            table.insert(order, name)
        end
    end
    local cache = dyld.open_cache(cachefile)
    local found = {}
    local exports_by_image = {}
    for _, loaded in ipairs(cache.images) do
        local entries = {}
        for _, entry in ipairs(dyld.image_symbols(cache, loaded).exports) do
            table.insert(entries, {address = entry[1], name = entry[2], order = #entries + 1})
        end
        table.sort(entries, function (a, b) return a.address < b.address or (a.address == b.address and a.order < b.order) end)
        exports_by_image[loaded.install] = entries
        for index, entry in ipairs(entries) do
            local name = entry.name:gsub("^_", "")
            if wanted[name] and not found[name] then
                local following = entries[index + 1]
                found[name] = {address = entry.address, install = loaded.install,
                                storage = following and (following.address - entry.address) or 0}
            end
        end
    end
    local function attempt(what)
        local value
        try {
            function ()
                value = what()
            end,
            catch {
                function ()
                    value = nil
                end
            }
        }
        return value
    end

    local function read(address, size)
        return attempt(function () return cache.read_address(address, size) end)
    end

    local base = string.unpack("<I8", cache.read(cache.main, cache.main.mapping_offset, 32))

    local function unslide(address, width)
        local candidates = {}
        if width == 8 then
            local raw = read(address, 8)
            if raw then
                local masked = string.unpack("<I8", raw) & 0xFFFFFFFFF
                table.insert(candidates, masked)
                table.insert(candidates, masked + base)
            end
        end
        local pointed = attempt(function () return cache.pointer_at(address) end)
        if type(pointed) == "number" then
            table.insert(candidates, pointed)
            table.insert(candidates, pointed + base)
        end
        for _, value in ipairs(candidates) do
            if cache.mapped(value, 1) then
                return value
            end
        end
        return nil
    end
    local pointer_size = cache.architecture:find("64") and 8 or 4
    print(table.concat({"#cache", cache.architecture, tostring(pointer_size)}, "\t"))
    local dashes = {"-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"}
    for _, name in ipairs(order) do
        local hit = found[name]
        if not hit then
            print(table.concat(dashes, "\t"))
        else
            local spec = wanted[name].width
            local width = spec == "p" and pointer_size or tonumber(spec) or 0
            local scalar = spec ~= "0"
            local storage = hit.storage or 0
            local read_it = scalar
            if width > storage and storage > 0 then
                read_it = false
            end
            local bytes = read_it and read(hit.address, width) or nil
            if not bytes then
                print(table.concat({name, hit.install, string.format("%#x", hit.address), "-", "-", "-",
                                    "-", "-", "-", tostring(width), tostring(storage)}, "\t"))
            else
                local padded = bytes .. string.rep("\0", math.max(0, 8 - #bytes))
                local u32, u64, f64 = string.unpack("<I4", padded), string.unpack("<I8", padded),
                                      string.unpack("<d", padded)
                local hex = (bytes:gsub(".", function (c) return string.format("%02x", c:byte()) end))
                local pointed, text = "-", "-"
                if wanted[name].pointer and wanted[name].text then
                    local value = unslide(hit.address, width)
                    if value then
                        pointed = string.format("%#x", value)
                        local chars_at = (width == 4) and (value + 8) or (value + 16)
                        local length_at = (width == 4) and (value + 12) or (value + 24)
                        local length_bytes = read(length_at, width)
                        local chars = unslide(chars_at, width)
                        if length_bytes and chars then
                            local length = width == 4 and string.unpack("<I4", length_bytes)
                                                     or string.unpack("<I8", length_bytes)
                            if length > 0 and length < 4096 then
                                local body = read(chars, length)
                                if body then
                                    text = body:gsub("[^\32-\126]", ".")
                                end
                            end
                        end
                    end
                end
                print(table.concat({name, hit.install, string.format("%#x", hit.address), hex,
                                    tostring(u32), tostring(u64), tostring(f64), pointed, text,
                                    tostring(width), tostring(storage)}, "\t"))
            end
        end
    end
    cache.close()
end

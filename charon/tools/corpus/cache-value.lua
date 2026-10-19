-- Read the value of exported data symbols out of a real dyld shared cache.
-- Usage: CHARON_ROOT=<worktree> xmake l cache-value.lua <cache file> <symbols file>
--
-- The symbols file is one symbol per line, TAB-separated:
--
--   <symbol>	<4|8|p>	<p|->	<s|->	-- the symbol is named as C names it; the cache names it
--                                      -- with the Mach-O leading underscore, which is added here
--                                      -- and stripped again on the way out
--                                      -- the value's width in bytes ("p" is this cache's pointer
--                                      -- size), whether it is a pointer, and whether it points at
--                                      -- a constant string
--
-- The width and the pointer flag are the caller's to know, because they come from the C type of
-- the declaration that names the symbol; this reads bytes and reports what is there. For every
-- symbol some image of the cache exports, one line comes back:
--
--   <symbol>	<install>	<address>	<bytes as hex>	<u32>	<u64>	<f64>	<pointer>	<string>	<width>	<storage>
--
-- preceded by one `#cache<TAB><architecture><TAB><pointer size>` line.
--
-- and for every symbol no image exports, one line of dashes -- "this release does not have it" is
-- an answer, not a failure. The address space is the project's own cache reader
-- (modules/apple/dyld.lua, through open_cache), so a split cache and the slide a stored pointer
-- carries are handled by the code that already binds them, not by a second parser here.
function main(cachefile, symbolfile)
    assert(cachefile and symbolfile, "usage: cache-value.lua <cache file> <symbols file>")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local wanted, order = {}, {}
    for line in io.lines(symbolfile) do
        local name, width, pointer, text = line:match("^([^\t]+)\t(%S+)\t([^\t]*)\t([^\t]*)$")
        if name and not wanted[name] then
            wanted[name] = {width = width, pointer = pointer == "p", text = text == "s"}
            table.insert(order, name)
        end
    end
    -- open_cache, not load: load assembles the library graph and closes the file, while reading a
    -- value needs the cache's own address space (read_address, pointer_at, mapped) and its images.
    local cache = dyld.open_cache(cachefile)
    local found = {}
    -- Every image's exports, sorted by address, so each wanted symbol's own storage can be measured:
    -- the distance to the next export in the same image. That distance bounds the storage from above
    -- (there may be padding after a symbol, never a symbol inside another's), which is what a read
    -- has to be checked against -- a read wider than the storage is reading its neighbour.
    local exports_by_image = {}
    for _, loaded in ipairs(cache.images) do
        local entries = {}
        for _, entry in ipairs(dyld.image_symbols(cache, loaded).exports) do
            table.insert(entries, {address = entry[1], name = entry[2]})
        end
        table.sort(entries, function (a, b) return a.address < b.address end)
        exports_by_image[loaded.install] = entries
        for index, entry in ipairs(entries) do
            local name = entry.name:gsub("^_", "")
            if wanted[name] and not found[name] then
                local following = entries[index + 1]
                found[name] = {address = entry.address, install = loaded.install,
                                -- 0 when this is the last export of the image, which means the
                                -- storage is not bounded by anything and no read is refused on it.
                                storage = following and (following.address - entry.address) or 0}
            end
        end
    end
    -- xmake's try/catch, not pcall: this dialect has no pcall. A read that runs off the end of a
    -- mapping must not take the whole run down, and must not read as a value either.
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

    -- A stored pointer's value: keep the address bits and drop what the slide info keeps above them
    -- (slide info v2 keeps chain bits above them). A 4-byte cache needs no slide, so the same mask is
    -- a no-op there. When the masked value is not in any mapping, the reader's own pointer_at is the
    -- second opinion: it follows the chained and v1-style encodings, which the mask above deliberately
    -- does not try to undo.
    -- The cache's base: the address its first mapping starts at, which a masked pointer is added to.
    -- It is one field of the mapping table the cache's own reader already holds (cache.main.header
    -- holds everything up to the table), not a second parse of the format.
    local base = string.unpack("<I8", cache.read(cache.main, cache.main.mapping_offset, 32))

    -- One hop of a stored pointer, in this order: keep the address bits, drop what the slide info
    -- keeps above them (slide info v2 keeps chain bits above them), and when that lands outside every
    -- mapping, add the cache's base. A 4-byte cache is never slid,
    -- so the mask is a no-op there. Every hop of a constant string needs this, not just the first:
    -- the value in the symbol and the object's chars pointer are each stored that way. The reader's
    -- own pointer_at is the last opinion tried, for the chained and v1-style encodings the mask does
    -- not try to undo -- after the mask rule, because a value pointer_at gets wrong can still land
    -- inside a mapping, and the neighbouring object is then read as this one.
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
    -- One header line, so the caller knows which ABI it just read without having to name the file:
    -- the reader's 32-bit path (never slid) and its 64-bit path (a slide and a chain to undo) are
    -- different code, and one cache's verdict says nothing about the other's.
    print(table.concat({"#cache", cache.architecture, tostring(pointer_size)}, "\t"))
    local dashes = {"-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"}
    for _, name in ipairs(order) do
        local hit = found[name]
        if not hit then
            print(table.concat(dashes, "\t"))
        else
            -- "p" in the width column means this cache's own pointer size, which is what a
            -- pointer, a long, a size_t, a CGFloat and an NSInteger all are on this ABI. "0" means
            -- the declared type is neither a scalar nor a pointer -- a struct, an array -- and
            -- nothing is read off the symbol at all.
            local spec = wanted[name].width
            local width = spec == "p" and pointer_size or tonumber(spec) or 0
            local scalar = spec ~= "0"
            local storage = hit.storage or 0
            local read_it = scalar
            -- A read wider than the symbol's own storage assembles a value out of the bytes past
            -- its end, which belong to whatever follows it. The storage is what is measurable -- the
            -- distance to the next export in the same image -- and a read that exceeds it is refused
            -- rather than delivered. Storage 0 means this is the image's last export, so nothing
            -- bounds it and nothing is refused on it.
            if width > storage and storage > 0 then
                read_it = false
            end
            local bytes = read_it and read(hit.address, width) or nil
            if not bytes then
                print(table.concat({name, hit.install, string.format("%#x", hit.address), "-", "-", "-",
                                    "-", "-", "-", tostring(width), tostring(storage)}, "\t"))
            else
                -- A 4-byte constant still has to answer for a double and a 64-bit read, so the
                -- bytes are zero-extended to 8 and every interpretation is reported; which one is
                -- the value is the caller's call, from the declaration's own type.
                local padded = bytes .. string.rep("\0", math.max(0, 8 - #bytes))
                local u32, u64, f64 = string.unpack("<I4", padded), string.unpack("<I8", padded),
                                      string.unpack("<d", padded)
                local hex = (bytes:gsub(".", function (c) return string.format("%02x", c:byte()) end))
                local pointed, text = "-", "-"
                -- A pointer-typed constant stores a slid pointer; pointer_at takes the slide off, and
                -- then the object it names is a constant string, whose chars and length sit at the
                -- offsets this width's CFString layout puts them.
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

-- found: the surface of a linked backport library, exactly as modules/apple/backports.lua's
-- surface() computes it, so the registry check reads the same answer the gate reads.
--
--   xmake l tests/backports/registry-shape/found.lua <checkout> <dylib> <architecture> <out.tsv>
--
-- Three of the functions surface() uses are local to backports.lua and cannot be imported, so the
-- smallest amount that answers them is copied here, each named with the line it came from:
--
--   symbols_where      modules/apple/backports.lua:187  - a memo over symbols_of
--   symbols_of         modules/apple/backports.lua:201  - exported, imported
--   defined_symbols     modules/apple/backports.lua:220  - the filter and its kind test. NOTE: it takes
--                                                      a second `hidden` argument and this copy
--                                                      hard-codes false, which is what surface() wants
--                                                      and what would be wrong for a caller that
--                                                      asks for the hidden symbols
--   exported_symbols    modules/apple/backports.lua:234  - defined minus internal
--   internal_symbol     modules/apple/backports.lua:164  - a protocol's own metadata object
--   carried_api         modules/apple/backports.lua:1397  - exported, imported below
--
-- Nothing else is copied: macho.imported_symbols (modules/apple/macho.lua:598), macho.text_literals
-- (:613), macho.read and macho.images are exported and imported; objc.binary_inventory
-- (modules/apple/objc.lua:395) and backports.symbols_of are imported too.
--
-- lines-copied.lua re-checks every one of those copies against the CURRENT backports.lua by
-- function name, so a backports.lua that moves a line or changes a filter is caught here rather
-- than silently answered from a stale copy.
function main(checkout, binary, architecture, out)
    local modules = path.join(checkout, "modules")
    local macho = import("apple.macho", {rootdir = modules, anonymous = true})
    local objc = import("apple.objc", {rootdir = modules, anonymous = true})
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})

    -- copy of modules/apple/backports.lua:220, over the exported symbols_of at :201, with
    -- backports' own body and its own `hidden` argument. surface() calls it without the argument, so
    -- hidden is nil and only the defined symbols are taken; a caller that wanted the hidden ones would
    -- pass true, and this copy takes that as backports does rather than fixing the value itself.
    local function defined_symbols(file, hidden)
        return backports.symbols_of(file, function(kind)
            return kind & 0xE0 == 0 and kind & 0x0E == 0x0E and (hidden or (kind & 0x10 == 0 and kind & 0x01 ~= 0))
        end, hidden and "hidden" or "defined")
    end

    -- copy of modules/apple/backports.lua:234, over defined_symbols at :220
    -- copy of modules/apple/backports.lua:164: a protocol object is metadata a caller reaches by name,
    -- an ivar object and anything with $shim in it are not API, and a symbol of the port's own Charon
    -- name is not either. lines-copied.py compares this against the current backports.lua.
    local function internal_symbol(name)
        if name:startswith("_OBJC_IVAR_$_") or name:startswith("_OBJC_PROTOCOL_$_") or name:find("$shim", 1, true) then
            return true
        end
        local bare = name:match("^_OBJC_%u*CLASS_%$_(.+)$") or name:match("^_(.+)$") or name
        return bare:startswith("charon_") or bare:startswith("Charon")
    end

    local function exported_symbols(file)  -- copy of modules/apple/backports.lua:234
        local found = {}
        for _, symbol in ipairs(defined_symbols(file)) do
            if not internal_symbol(symbol) then table.insert(found, symbol) end
        end
        return found
    end

    local found = {classes = {}, members = {}, symbols = {}, defined = {}, registered = {}, answered = {}}
    for _, symbol in ipairs(exported_symbols(binary)) do
        local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
        if class then
            found.classes[class] = true
        elseif not symbol:startswith("_OBJC_METACLASS_$_") and not symbol:startswith("_OBJC_IVAR_$_") then
            found.symbols[symbol:sub(2)] = true
            found.defined["_" .. symbol:sub(2)] = true
        end
    end
    -- modules/apple/backports.lua:1406-1412
    if macho.imported_symbols(binary, architecture)["objc_allocateClassPair"] then
        for literal in pairs(macho.text_literals(binary, architecture)) do
            found.registered[literal] = true
        end
    end
    -- modules/apple/backports.lua:1421-1437
    local inventory = objc.binary_inventory(binary, architecture)
    for name, class in pairs(inventory and inventory.classes or {}) do
        if class.image and not name:startswith("Charon") then
            found.classes[name] = true
        end
        if not name:startswith("Charon") then
            for kind, sign in pairs({instance = "-", class = "+"}) do
                for selector in pairs(class[kind]) do
                    found.answered[string.format("%s[%s %s]", sign, name, selector:sub(2))] = true
                end
            end
        end
    end
    for _, member in ipairs(backports.carried_api(inventory)) do
        found.members[member] = true
    end

    local file = assert(io.open(out, "w"))
    local n = 0
    for name in pairs(found.classes) do file:write("C\t", name, "\n"); n = n + 1 end
    for name in pairs(found.symbols) do file:write("S\t", name, "\n"); n = n + 1 end
    for name in pairs(found.members) do file:write("M\t", name, "\n"); n = n + 1 end
    for name in pairs(found.registered) do file:write("R\t", name, "\n"); n = n + 1 end
    for name in pairs(found.answered) do file:write("A\t", name, "\n"); n = n + 1 end
    file:close()
    print(string.format("found: %d names from %s", n, path.filename(binary)))
end

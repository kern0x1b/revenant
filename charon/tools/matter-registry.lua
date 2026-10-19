-- The Matter registry, derived rather than written.
--
-- The SDK 26.2 surface of the framework Matter is 24 647 rows, which no one types, and one registry entry per row of a
-- framework nobody re-implemented is not a fact record either: this library is connectedhomeip's own Darwin framework,
-- built by the port for the port's release, and what it carries is read out of the linked libMatterBackports.dylib.
--
-- So an entry is written for every row the library carries, and none for a row it does not: the corpus answers `none`
-- for those, which is the honest answer, and the ledger's `missing` measure counts them. The rows are read with the
-- same modules the gate's own check reads a binary with (modules/apple/objc.lua, modules/apple/macho.lua), so what this
-- writes and what the gate finds cannot disagree about what the library carries.
--
--   class      a class the library defines
--   method     a selector of a class the library carries, either as -[Class selector:] or as the Class.selector:
--              spelling the surface gives a method on a class it spells Class.selector:
--   property   the accessors of a property, through its getter -[Class name] or its setter -[Class setName:], which
--              is how the SDK spells them
--   constant   a symbol the library exports
--   function   a symbol the library exports
--   enum       a typedef, which carries no symbol of its own: it is carried when the library exports at least one of
--              the values the surface lists under it, and the SDK names each value after its type
--              (MTRAccessControlAuthModeCASE under MTRAccessControlAuthMode)
--   protocol   a protocol the library names in its metadata, or a class of the library's own that adopts it
--
-- The rows are written one file per family - the cluster a class belongs to, or the part of the framework it is part of -
-- so a file is a few dozen rows and a diff of one is readable.
--
-- Usage: xmake l tools/matter-registry.lua <dylib> <corpus.tsv> <outdir> [facts] [architecture]
import("core.base.json")
local objc = import("apple.objc", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
local macho = import("apple.macho", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local FRAMEWORK = "Matter"
local MINIMUM = "6.0"
local SOURCE = "the SDK 26.2 headers of Matter, and the exports and the Objective-C metadata of libMatterBackports.dylib, which is connectedhomeip's own Darwin framework (v1.6.1.0) built by charon@matter for this release"

-- The symbols a C++ library and a compiler's runtime carry that are not API: not the framework's, and not the
-- registry's business. An Objective-C class's metaclass and ivar symbols likewise, and the alias class of a class this
-- library stands in for.
local function api_symbol(symbol)
    if symbol:startswith("_OBJC_METACLASS_$_") or symbol:startswith("_OBJC_IVAR_$_") or symbol:startswith("_OBJC_")
       or symbol:startswith("__Z") or symbol:startswith("___Z") or symbol:startswith("__Unwind_") or symbol:startswith("_unwind_")
       or symbol:startswith("$") or symbol:startswith("__dso_handle") or symbol:startswith("_charon")
       or symbol:startswith("__swift") or symbol:startswith("swift_") or symbol:startswith("_swift") then
        return nil
    end
    return symbol:sub(2)
end

-- Every defined external symbol of every slice of a binary, and the classes among them.
local function symbols_of(binary)
    local found = {}
    local data = macho.read(binary)
    for _, image in ipairs(macho.images(data)) do
        if image.symtab then
            local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
            local entry = image.wide and 16 or 12
            for index = 0, nsyms - 1 do
                local strx, kind, _, _, value = string.unpack(image.wide and "<I4BBI2I8" or "<I4BBI2I4", data, image.base + symoff + index * entry + 1)
                -- a defined external symbol: N_EXT (0x01) set, N_UNDF (0x10) clear, and a value that is not the null one
                if kind & 0xE0 == 0 and kind & 0x01 ~= 0 and kind & 0x10 == 0 and value ~= 0 then
                    local finish = data:find("\0", image.base + stroff + strx + 1, true)
                    found[data:sub(image.base + stroff + strx + 1, finish - 1)] = true
                end
            end
        end
    end
    return found
end

-- What the library carries, in the registry's own spellings.
local function surface(binary, architecture)
    local found = {classes = {}, members = {}, symbols = {}, protocols = {}}
    for symbol in pairs(symbols_of(binary)) do
        local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
        if class then
            found.classes[class] = true
        else
            local name = api_symbol(symbol)
            if name then
                found.symbols[name] = true
            end
        end
    end
    local inventory = objc.binary_inventory(binary, architecture)
    if not inventory then
        raise("%s has no %s slice", binary, architecture)
    end
    found.inventory = inventory
    for name, class in pairs(inventory.classes) do
        found.classes[name] = true
        for kind, sign in pairs({instance = "-", class = "+"}) do
            for selector in pairs(class[kind]) do
                found.members[string.format("%s[%s %s]", sign, name, selector:sub(2))] = true
            end
        end
        for protocol in pairs(class.protocols) do
            found.protocols[protocol] = true
        end
    end
    for name in pairs(inventory.protocols) do
        found.protocols[name] = true
    end
    return found
end

-- A member of a class is answered by the class or by any of its superclasses, and objc.lua keys a class's *own* method
-- list by sign and selector ("-authMode"), not by the -[Class selector:] spelling the registry uses. Reading only the
-- class's own list misses every accessor a subclass inherits, which is every accessor of the model's deprecated
-- ...Entry, ...EP and ...OutputInfo classes over its ...Struct classes.
local function responds(inventory, name, sign, selector)
    local seen = {}
    while name and inventory.classes[name] and not seen[name] do
        seen[name] = true
        if inventory.classes[name].instance[sign .. selector] or inventory.classes[name].class[sign .. selector] then
            return true
        end
        name = inventory.classes[name].superclass
    end
    return false
end

-- The accessors a property is written as: its getter -[Class name], or its setter -[Class setName:]. The SDK spells a
-- getter after the property with a prefix as well (isName, hasName, canName, ...), so each of those is a getter too.
local function property_answered(found, owner, name)
    if found.members["-[" .. owner .. " " .. name .. "]"] or responds(found.inventory, owner, "-", name) then
        return true
    end
    if found.members["-[" .. owner .. " set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":]"] or
       responds(found.inventory, owner, "-", "set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":") then
        return true
    end
    for _, prefix in ipairs({"is", "has", "as", "can", "should", "will", "did", "countOf", "objectAt"}) do
        if responds(found.inventory, owner, "-", prefix .. name:sub(1, 1):upper() .. name:sub(2)) then
            return true
        end
    end
    return false
end

-- The family a row belongs to, which is the file it is written in: the cluster a class is the API of, taken from the
-- name the SDK gives the class (MTRDoorLockCluster, MTRAccessControlClusterTarget, ...), and the part of the framework
-- otherwise. The name is the SDK's, so a family is a fact about the surface and not a choice made here.
local FAMILIES = {
    Device = "the device and the controller: what a program commissions, connects, reads and writes through",
    Storage = "the store and the data the controller keeps",
    OperationalCredentials = "the certificates, the trust and the operational credentials",
    SetupPayload = "the payloads that carry a code to a human",
    Diagnostic = "the diagnostics and the logs a program asks the device for",
    Framework = "the framework itself: its version, its options, its log callback",
    Converters = "the conversions between the framework's types and Foundation's",
    Browser = "what the device finds on the network",
    OTA = "the software update",
    Metrics = "the metrics the device keeps and the collector that ships them",
    UnfairLock = "the lock the framework's own structures take",
    CertificateInfo = "the certificates, their chains and their validity",
    NetworkInterface = "the network interfaces the device has",
    Utilities = "the framework's helpers, which are not API of any row above"
}

local function family_of(api)
    local cluster = api:match("^MTR([%u][%w_]*)Cluster")
    if cluster then
        return cluster
    end
    for _, name in ipairs(table.orderkeys(FAMILIES)) do
        if api:find(name, 1, true) then
            return name
        end
    end
    -- Anything left is a struct, a typealias of the SDK's, or a helper class: grouped by the part of the name that is
    -- not the framework's own prefix, so MTRAccessControlClusterAccessControlEntry and MTRDoorLockClusterStruct land
    -- with their cluster rather than in one file of leftovers.
    return (api:gsub("^MTR", ""):match("^([%u][%w_]*)") or "Matter")
end

local function read_surface(corpus)
    local rows, order, seen = {}, {}, {}
    for line in io.lines(corpus) do
        local fields = {}
        -- io.lines keeps the trailing newline in this Lua, so it is taken off the line before it is split: a name that
        -- ended in "\n" would match nothing, and the comparison would say "neither side carries it" for every row.
        for field in (line:gsub("\n$", "") .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(fields, field)
        end
        if fields[1] == FRAMEWORK and fields[4] and fields[4] ~= "" and fields[2] ~= "framework" then
            if not seen[fields[4]] then
                seen[fields[4]] = true
                table.insert(order, {kind = fields[2], api = fields[4], introduced = fields[5] ~= "" and fields[5] or nil})
            end
        end
    end
    return order
end

function main(binary, corpus, outdir, facts, architecture)
    architecture = architecture or "armv7"
    assert(os.isfile(binary), "%s is not there: build charon@matter first", binary)
    assert(os.isfile(corpus), "%s is not there", corpus)
    local found = surface(binary, architecture)
    local rows = read_surface(corpus)

    -- The enum types of the surface, longest first, so a symbol is matched against the type it is a value of and not
    -- against a shorter one that happens to be its prefix.
    local types = {}
    for _, row in ipairs(rows) do
        if row.kind == "enum" then
            table.insert(types, row.api)
        end
    end
    table.sort(types, function (left, right) return #left > #right end)
    local type_of_value = {}
    for name in pairs(found.symbols) do
        for _, name_type in ipairs(types) do
            if #name > #name_type and name:startswith(name_type) and not type_of_value[name] then
                type_of_value[name] = name_type
            end
        end
    end

    local families, carried, missing = {}, 0, {}
    for _, row in ipairs(rows) do
        local status
        local sign, owner_of, selector = row.api:match("^([-+])%[([%w_]+) (.+)%]$")
        local owner, name = row.api:match("^([%u][%w_]*)%.(.+)$")
        if row.kind == "class" then
            status = found.classes[row.api]
        elseif row.kind == "protocol" then
            status = found.protocols[row.api]
        elseif row.kind == "method" then
            if sign then
                status = found.members[row.api] or responds(found.inventory, owner_of, sign, selector)
            elseif owner and found.members["-[" .. owner .. " " .. name .. "]"] or found.members["+[" .. owner .. " " .. name .. "]"] then
                status = true
            end
        elseif row.kind == "property" then
            status = owner and property_answered(found, owner, name) or nil
        elseif row.kind == "constant" or row.kind == "function" then
            status = found.symbols[row.api:gsub("%(%)$", "")]
        elseif row.kind == "enum" then
            local name_type = row.api:gsub("%(%)$", "")
            for value, carried_type in pairs(type_of_value) do
                if carried_type == name_type then
                    status = true
                    break
                end
            end
        end
        if status then
            carried = carried + 1
            local family = family_of(row.kind == "method" and (owner_of or owner) or row.api)
            families[family] = families[family] or {}
            table.insert(families[family], {api = row.api, kind = row.kind, introduced = row.introduced,
                                            minimum = MINIMUM, status = "implemented", source = SOURCE,
                                            facts = facts})
        else
            table.insert(missing, row.kind .. "\t" .. row.api)
        end
    end

    os.tryrm(outdir)
    os.mkdir(outdir)
    -- Two families whose names differ only in case are one file on the case-insensitive file system the registry is
    -- written and read on: the SDK spells the OTA cluster both ways (MTROTA... from 16.4, MTROta... from 16.1), and
    -- writing one family after the other overwrote the other's rows. So families are merged by their lowercase name,
    -- and the file takes the spelling that sorts first, which is the same whatever order the families were found in.
    local files = {}
    for family, entries in pairs(families) do
        local key = family:lower()
        if not files[key] then
            files[key] = {name = family, entries = {}}
        elseif byteorder.less(family, files[key].name) then
            files[key].name = family
        end
        for _, entry in ipairs(entries) do
            table.insert(files[key].entries, entry)
        end
    end
    local counts = {}
    for _, file in pairs(files) do
        table.sort(file.entries, function (left, right) return byteorder.less(left.api, right.api) end)
        io.writefile(path.join(outdir, file.name .. ".json"), json.encode({framework = FRAMEWORK, entries = file.entries}))
        counts[file.name] = #file.entries
    end
    local names = table.orderkeys(counts)
    io.writefile(path.join(outdir, "index.json"), json.encode({
        framework = FRAMEWORK, dylib = path.filename(binary), architecture = architecture,
        families = names, counts = counts, carried = carried, of = #rows,
        families_described = FAMILIES}))

    print("Matter: %d of %d rows carried, in %d files under %s", carried, #rows, #names, outdir)
    local bykind = {}
    for _, line in ipairs(missing) do
        local kind = line:match("^([^\t]*)\t")
        bykind[kind] = (bykind[kind] or 0) + 1
    end
    for _, kind in ipairs(table.orderkeys(bykind)) do
        print("  not carried: %s %d", kind, bykind[kind])
    end
    byteorder.sort(missing)
    io.writefile(path.join(outdir, "matter-not-carried.tsv"), table.concat(missing, "\n") .. "\n")
end

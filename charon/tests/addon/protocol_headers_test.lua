-- protocol_headers_test.lua: is every implemented protocol row of every library declared where that
-- library's generated protocol source can see it?
--
-- modules/apple/backports.lua's protocol_sources() writes one source per release a library's
-- implemented protocol rows arrived in, and each source opens with `#import "Charon<Folder>Protocols.h"`
-- and then names every row of that release with `@protocol(<name>)`. So a row with no declaration
-- reachable from that header is a source the 6.1.3 gate cannot compile, and nothing before it sees
-- it: the row is in the registry, the tool wrote the source, and the header is a file nothing reads
-- until a compiler does. That is what happened to UIKit's eight trait protocols, added with a
-- previous stack while CharonUIKitProtocols.h was last regenerated for another delivery.
--
-- A row passes when Charon<Folder>Protocols.h declares the protocol - forward (`@protocol X;`) or
-- with a body, which is what tools/gen.lua protocols writes for one the 16.4 SDK does not
-- declare - or when it declares it in a header that header imports by name. The imports are followed
-- inside the library's own folder and nowhere else, because that is where the generated source's
-- include path reaches, and an import of a header the folder does not hold is reported as well: the
-- same file that was supposed to supply the declaration would be the one the compiler cannot open.
--
-- A library with implemented protocol rows and no Charon<Folder>Protocols.h at all is a failure and
-- not a skip: the header is what its generated sources import, so its absence is the same defect with
-- no declaration to find.
import("core.base.json")
local protocol_headers = import("gen.protocol_headers", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})

local function libraries_of(modules)
    -- Loaded the way archive_language_test.lua loads it: as a module of the repository's own modules
    -- folder, which the import finds only when the test runs from the checkout the light guard runs.
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    return backports.libraries()
end

local function implemented_protocols(root, folder)
    -- The same two places protocol_sources() reads: the folder's own registry files and the single
    -- file named after the folder.
    local found = {}
    local registry = path.join(root, "packages", "a", "apple-backports", "registry")
    local files = os.files(path.join(registry, folder, "*.json"))
    local single = path.join(registry, folder .. ".json")
    if os.isfile(single) then table.insert(files, single) end
    for _, file in ipairs(files) do
        local held = json.loadfile(file)
        for _, entry in ipairs((held.entries or (type(held) == "table" and held) or {})) do
            if entry.kind == "protocol" and entry.status == "implemented" then
                table.insert(found, entry.api)
            end
        end
    end
    table.sort(found)
    return found
end

-- Every protocol a header declares, and the headers of the same folder it imports by name. Followed
-- through, with a visited set, so an import cycle is read once rather than for ever.
-- The lines of a header: the rendered text when the caller has it (the generated header is not in the folder), else the file.
local function lines_of(header, text)
    if text == nil then return io.lines(header) end
    return string.gmatch(text, "[^\n]*")
end

local function declared_in(folder, header, seen, text)
    local declared, imported = {}, {}
    local key = path.filename(header)
    if seen[key] then return declared, imported end
    seen[key] = true
    for line in lines_of(header, text) do
        for name in line:gmatch("@protocol%s+([A-Za-z0-9_]+)") do declared[name] = true end
        for name in line:gmatch('#import%s+"([^"]+)"') do imported[#imported + 1] = name end
    end
    for _, name in ipairs(imported) do
        local inner = path.join(folder, name)
        if os.isfile(inner) then
            local more = declared_in(folder, inner, seen)
            for protocol in pairs(more) do declared[protocol] = true end
        else
            imported[#imported] = nil
            declared["\0missing " .. name] = true
        end
    end
    return declared, imported
end

function failures(opt)
    local found = {}
    local root = path.join(opt.modules, "..")
    for _, library in ipairs(libraries_of(opt.modules)) do
        local folder = path.join(root, "packages", "a", "apple-backports", library.folder)
        local rows = implemented_protocols(root, library.folder)
        if #rows > 0 then
            local header = path.join(folder, "Charon" .. library.folder .. "Protocols.h")
            local text = protocol_headers.header_text(root, library.folder)
            if text == nil then
                table.insert(found, string.format(
                    "%s has %d implemented protocol row(s) and no Charon%sProtocols.h, which every generated "
                    .. "protocol source of it imports; the rows are: %s",
                    library.name, #rows, library.folder, table.concat(rows, " ")))
            else
                local declared, imported = declared_in(folder, header, {}, text)
                local undeclared = {}
                for _, api in ipairs(rows) do
                    if not declared[api] then table.insert(undeclared, api) end
                end
                for missing in pairs(declared) do
                    if missing:sub(1, 8) == "\0missing" then
                        table.insert(found, string.format(
                            "%s: Charon%sProtocols.h imports %q, which is not a header of the library's own "
                            .. "folder, so the generated source that imports it cannot open it",
                            library.name, library.folder, missing:sub(9)))
                    end
                end
                if #undeclared > 0 then
                    local named = {}
                    for _, name in ipairs(imported) do named[#named + 1] = name end
                    table.insert(found, string.format(
                        "%s: %d implemented protocol row(s) are named by a generated source and declared "
                        .. "neither in Charon%sProtocols.h nor in a header it imports (%s): %s",
                        library.name, #undeclared, library.folder,
                        #named > 0 and table.concat(named, ", ") or "it imports no header of the folder",
                        table.concat(undeclared, " ")))
                end
            end
        end
    end
    return found
end

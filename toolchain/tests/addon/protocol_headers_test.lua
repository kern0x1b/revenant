import("core.base.json")
local protocol_headers = import("gen.protocol_headers", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})

local function libraries_of(modules)
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    return backports.libraries()
end

local function implemented_protocols(root, folder)
    local found = {}
    local registry = path.join(root, "..", "packages", "frameworks", "apple-backports", "registry")
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
        local folder = path.join(root, "..", "packages", "frameworks", "apple-backports", library.folder)
        local rows = implemented_protocols(root, library.folder)
        if #rows > 0 then
            local header = path.join(folder, "Revenant" .. library.folder .. "Protocols.h")
            local text = protocol_headers.header_text(root, library.folder)
            if text == nil then
                table.insert(found, string.format(
                    "%s has %d implemented protocol row(s) and no Revenant%sProtocols.h, which every generated "
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
                            "%s: Revenant%sProtocols.h imports %q, which is not a header of the library's own "
                            .. "folder, so the generated source that imports it cannot open it",
                            library.name, library.folder, missing:sub(9)))
                    end
                end
                if #undeclared > 0 then
                    local named = {}
                    for _, name in ipairs(imported) do named[#named + 1] = name end
                    table.insert(found, string.format(
                        "%s: %d implemented protocol row(s) are named by a generated source and declared "
                        .. "neither in Revenant%sProtocols.h nor in a header it imports (%s): %s",
                        library.name, #undeclared, library.folder,
                        #named > 0 and table.concat(named, ", ") or "it imports no header of the folder",
                        table.concat(undeclared, " ")))
                end
            end
        end
    end
    return found
end

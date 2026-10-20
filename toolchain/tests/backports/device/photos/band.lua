local json = import("core.base.json")

local function versions(text)
    local out = {}
    for digits in (text or "0"):gmatch("%d+") do
        table.insert(out, tonumber(digits))
    end
    return out
end

local function before(a, b)
    for index = 1, math.max(#a, #b) do
        local x, y = a[index] or -1, b[index] or -1
        if x ~= y then
            return x < y
        end
    end
    return false
end

local function is_array(value)
    return type(value) == "table" and value[1] ~= nil
end

local function sorted_set(values)
    local seen, out = {}, {}
    for _, value in ipairs(values) do
        if not seen[value] then
            seen[value] = true
            table.insert(out, value)
        end
    end
    table.sort(out)
    return out
end

local function identifiers(text)
    local classes = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local name = line:match("^@implementation%s+([%a_][%w_]*)") or line:match("^@interface%s+([%a_][%w_]*)")
        if name then
            table.insert(classes, name)
        end
    end
    return classes
end

function main(release_text, photos, registry)
    if release_text == nil or photos == nil or registry == nil then
        raise("usage: band.lua RELEASE PHOTOS-DIR REGISTRY-DIR")
    end
    local release = versions(release_text)
    local minimums = {}
    local files = os.files(path.join(registry, "**.json"))
    table.sort(files)
    for _, file in ipairs(files) do
        local document = json.decode(io.readfile(file, {encoding = "binary"}))
        local entries = nil
        if type(document) == "table" and document.entries == nil and not is_array(document) then
            local keys = {}
            for key, value in pairs(document) do
                if type(value) == "table" and is_array(value) then
                    table.insert(keys, key)
                end
            end
            if #keys ~= 1 then
                io.stderr:write(string.format("band.lua: %s holds no entries and no one list; skipped\n", file))
                goto continue
            end
            document = document[keys[1]]
        end
        if type(document) == "table" and document.entries ~= nil then
            entries = document.entries
        else
            entries = document
        end
        for _, entry in ipairs(entries or {}) do
            if entry.kind == "class" and entry.minimum ~= nil and entry.minimum ~= "" then
                local current = minimums[entry.api]
                if current == nil or before(versions(entry.minimum), versions(current)) then
                    minimums[entry.api] = entry.minimum
                end
            end
        end
        ::continue::
    end
    local sources = os.files(path.join(photos, "*.m"))
    local names = {}
    for _, file in ipairs(sources) do
        table.insert(names, path.filename(file))
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local file = path.join(photos, name)
        local classes = identifiers(io.readfile(file, {encoding = "binary"}))
        local floors = {}
        for _, cls in ipairs(classes) do
            if minimums[cls] ~= nil then
                table.insert(floors, minimums[cls])
            end
        end
        if #floors == 0 and #classes > 0 then
            io.stderr:write(string.format("%s: no registry entry names %s, so it is in the band by default\n",
                name, table.concat(sorted_set(classes), ", ")))
        end
        local above = {}
        for _, floor in ipairs(floors) do
            if before(release, versions(floor)) then
                table.insert(above, floor)
            end
        end
        if #above > 0 then
            io.stderr:write(string.format("%s is not in the %s band: %s carries a minimum of %s\n",
                name, release_text, table.concat(sorted_set(classes), ", "), table.concat(sorted_set(above), ", ")))
        else
            print(name)
        end
    end
end

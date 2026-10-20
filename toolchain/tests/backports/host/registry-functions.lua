import("core.base.json")

local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})

local OPTIONS = {prefix = true, contains = true, except = true}

local function arguments(...)
    local files, filters = {}, {prefix = {}, contains = {}, except = {}}
    for _, word in ipairs({...}) do
        local option, value = word:match("^%-%-(%w+)=(.*)$")
        if option then
            assert(OPTIONS[option], "registry-functions: unknown option --" .. option)
            table.insert(filters[option], value)
        else
            table.insert(files, word)
        end
    end
    return files, filters
end

local function any(list, test)
    if #list == 0 then
        return true
    end
    for _, item in ipairs(list) do
        if test(item) then
            return true
        end
    end
    return false
end

local function wanted(name, filters)
    if table.contains(filters.except, name) then
        return false
    end
    return any(filters.prefix, function (prefix) return name:startswith(prefix) end)
       and any(filters.contains, function (part) return name:find(part, 1, true) ~= nil end)
end

function main(folder, ...)
    local files, filters = arguments(...)
    if #files == 0 then
        for _, file in ipairs(os.files(path.join(folder, "*.json"))) do
            table.insert(files, path.filename(file))
        end
        byteorder.sort(files)
    end
    for _, file in ipairs(files) do
        local filepath = path.join(folder, file)
        assert(os.isfile(filepath), "registry-functions: no registry file " .. filepath)
        local data = json.decode(io.readfile(filepath))
        assert(data.entries, "registry-functions: " .. filepath .. " has no entries")
        for _, entry in ipairs(data.entries) do
            local name = entry.api:gsub("%(%)$", "")
            if entry.kind == "function" and wanted(name, filters) then
                print(name)
            end
        end
    end
end

local facts = import("facts", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local function sources()
    local src = path.join(sdkfiles.root(), "frameworks", "Backports", "src")
    local files = {}
    for _, pattern in ipairs({"**.m", "**.c"}) do
        for _, file in ipairs(os.files(path.join(src, pattern))) do
            table.insert(files, path.absolute(file))
        end
    end
    table.sort(files)
    return files, src
end

local function read_keys(store)
    local keys = {}
    for line in io.lines(store) do
        table.insert(keys, line)
    end
    return keys
end

function detect(sdk, version)
    local files, src = sources()
    local folder = path.join(sdkfiles.build_root(), "implemented")
    os.mkdir(folder)
    local by_framework = {}
    for _, file in ipairs(files) do
        local framework = string.match(path.relative(file, src), "^([^/]+)/")
        assert(framework, file .. " is not under a framework folder of src")
        local store = path.join(folder, sdkfiles.cache_key(version) .. "-" .. hash.sha256(file) .. ".txt")
        local keys
        if os.isfile(store) then
            keys = read_keys(store)
        else
            local found = facts.src_keys(sdk, version, file)
            keys = {}
            for key in pairs(found) do
                table.insert(keys, key)
            end
            table.sort(keys)
            io.writefile(store, table.concat(keys, "\n") .. (#keys > 0 and "\n" or ""))
        end
        by_framework[framework] = by_framework[framework] or {}
        for _, key in ipairs(keys) do
            by_framework[framework][key] = true
        end
    end
    return by_framework
end

local facts = import("facts", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local function sources(names)
    local src = path.join(sdkfiles.root(), "frameworks", "Backports", "src")
    local files = {}
    for _, name in ipairs(names) do
        for _, pattern in ipairs({"*.m", "*.mm", "*.c"}) do
            for _, file in ipairs(os.files(path.join(src, name, pattern))) do
                table.insert(files, path.absolute(file))
            end
        end
    end
    table.sort(files)
    return files
end

local function read_keys(store)
    local keys = {}
    for line in io.lines(store) do
        table.insert(keys, line)
    end
    return keys
end

function detect(sdk, version, names, target, includes)
    local folder = path.join(sdkfiles.build_root(), "implemented")
    os.mkdir(folder)
    local digest = string.sub(hash.strhash128(target .. ";" .. table.concat(includes, ";")), 1, 16)
    local by_framework = {}
    for _, name in ipairs(names) do
        by_framework[name] = {}
    end
    for _, file in ipairs(sources(names)) do
        local framework = path.filename(path.directory(file))
        local store = path.join(folder, sdkfiles.cache_key(version) .. "-" .. digest .. "-" .. hash.sha256(file) .. ".txt")
        local keys
        if os.isfile(store) then
            keys = read_keys(store)
        else
            local found = facts.src_keys(sdk, file, target, includes)
            keys = {}
            for key in pairs(found) do
                table.insert(keys, key)
            end
            table.sort(keys)
            io.writefile(store, table.concat(keys, "\n") .. (#keys > 0 and "\n" or ""))
        end
        for _, key in ipairs(keys) do
            by_framework[framework][key] = true
        end
    end
    return by_framework
end

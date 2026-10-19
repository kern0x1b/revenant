local order = import("order", {anonymous = true})
local files = import("files", {anonymous = true})

local memo = {}

local function segments_of(text)
    local out = {}
    for segment in string.gmatch(text, "[^/]+") do
        table.insert(out, segment)
    end
    return out
end

local function lines_of(file)
    local text = files.read_text(file) or ""
    local out = {}
    for line in string.gmatch(text, "([^\n]*)\n?") do
        table.insert(out, line)
    end
    return out
end

local function declared_module(line)
    local name, after = string.match(line, "^explicit%s+module%s+([%w_]+)(.?)")
    if name == nil then
        name, after = string.match(line, "^module%s+([%w_]+)(.?)")
    end
    if name == nil or after == "." then
        return nil
    end
    return name
end

local function frameworks_in(dir, outer, kind, out)
    for _, folder in ipairs(os.dirs(path.join(dir, "*.framework"))) do
        local base = string.sub(path.filename(folder), 1, -11)
        local name = outer == "" and base or (outer .. "/" .. base)
        table.insert(out, {name = name, base = base, kind = kind, root = folder})
        frameworks_in(path.join(folder, "Frameworks"), name, kind, out)
    end
end

local function usr_maps(include)
    local maps = {}
    local candidates = os.files(path.join(include, "*.modulemap"))
    for _, folder in ipairs(os.dirs(path.join(include, "*"))) do
        if os.isfile(path.join(folder, "module.modulemap")) then
            table.insert(candidates, path.join(folder, "module.modulemap"))
        end
    end
    table.sort(candidates, order.less)
    local out = {}
    for _, map in ipairs(candidates) do
        for _, line in ipairs(lines_of(map)) do
            local name = declared_module(line)
            if name ~= nil then
                assert(out[name] == nil, "more than one module map declares the module " .. name .. ": " .. map)
                out[name] = map
            end
        end
    end
    return out
end

function discover(sdk)
    if memo[sdk] ~= nil then
        return memo[sdk]
    end
    local library = path.join(sdk, "System", "Library")
    local found = {}
    frameworks_in(path.join(library, "Frameworks"), "", "framework", found)
    frameworks_in(path.join(library, "SubFrameworks"), "", "subframework", found)
    local include = path.join(sdk, "usr", "include")
    for name, map in pairs(usr_maps(include)) do
        table.insert(found, {name = name, base = name, kind = "usr", root = include, map = map})
    end
    local modules, names = {}, {}
    local function add(record)
        assert(modules[record.name] == nil, "two modules are named " .. record.name)
        modules[record.name] = record
        table.insert(names, record.name)
    end
    local claimed = {}
    for _, record in ipairs(found) do
        assert(not claimed[record.name], "two frameworks are named " .. record.name)
        claimed[record.name] = true
        add(record)
    end
    for _, folder in ipairs(os.dirs(path.join(sdk, "usr", "lib", "swift", "*.swiftmodule"))) do
        local name = string.sub(path.filename(folder), 1, -13)
        if not claimed[name] then
            claimed[name] = true
            add({name = name, base = name, kind = "swift", root = folder})
        end
    end
    local developer = {}
    frameworks_in(path.join(sdk, "Developer", "Library", "Frameworks"), "", "developer", developer)
    for _, record in ipairs(developer) do
        if not claimed[record.name] then
            claimed[record.name] = true
            add(record)
        end
    end
    table.sort(names, order.less)
    memo[sdk] = {modules = modules, names = names}
    return memo[sdk]
end

function module_of(sdk, name)
    return discover(sdk).modules[name]
end

function root_of(sdk, name)
    local record = module_of(sdk, name)
    return record and record.root or nil
end

function export_files(sdk, name)
    local record = module_of(sdk, name)
    if record == nil then
        return {}
    end
    if record.kind ~= "usr" then
        local last = string.match(name, "([^/]+)$")
        local file = path.join(record.root, last .. ".tbd")
        return os.isfile(file) and {file} or {}
    end
    local out = {}
    for _, line in ipairs(lines_of(record.map)) do
        local library = string.match(line, "^%s*link%s+\"([^\"]+)\"")
        if library ~= nil then
            local file = path.join(sdk, "usr", "lib", "lib" .. library .. ".tbd")
            if os.isfile(file) then
                table.insert(out, file)
            end
        end
    end
    return out
end

local function map_headers(map, header_base, dir_base, wanted)
    local headers, named, excluded = {}, {}, {}
    local seen = {}
    local function add(file, is_named)
        if is_named then
            named[file] = true
        end
        if not seen[file] then
            seen[file] = true
            table.insert(headers, file)
        end
    end
    local depth, skipping_until = 0, nil
    for _, line in ipairs(lines_of(map)) do
        local code = string.gsub(string.gsub(line, "//.*$", ""), "^%s+", "")
        code = string.gsub(code, "%s+$", "")
        local _, opens = string.gsub(code, "{", "")
        local _, closes = string.gsub(code, "}", "")
        if skipping_until == nil or depth < skipping_until then
            skipping_until = nil
            local declared = declared_module(code)
            if string.match(code, "^framework%s+module%s") and depth >= 1 then
                skipping_until = depth + 1
            elseif string.match(code, "^requires%s+x86") then
                skipping_until = depth
            elseif wanted ~= "" and depth == 0 and declared ~= nil and declared ~= wanted then
                skipping_until = depth + 1
            else
                local header = string.match(code, "^umbrella%s+header%s+\"([^\"]+)\"") or string.match(code, "^header%s+\"([^\"]+)\"")
                    or string.match(code, "^textual%s+header%s+\"([^\"]+)\"")
                local excluded_header = string.match(code, "^exclude%s+header%s+\"([^\"]+)\"")
                local umbrella_dir = string.match(code, "^umbrella%s+\"([^\"]+)\"")
                if header ~= nil then
                    add(path.normalize(path.join(header_base, header)), true)
                elseif excluded_header ~= nil then
                    excluded[path.normalize(path.join(header_base, excluded_header))] = true
                elseif umbrella_dir ~= nil then
                    local dir = path.join(dir_base, umbrella_dir)
                    local listed = os.files(path.join(dir, "**.h"))
                    table.sort(listed, order.less)
                    for _, file in ipairs(listed) do
                        add(path.normalize(file), false)
                    end
                end
            end
        end
        depth = depth + opens - closes
        if skipping_until ~= nil and depth < skipping_until then
            skipping_until = nil
        end
    end
    local out = {}
    for _, file in ipairs(headers) do
        if not excluded[file] or named[file] then
            table.insert(out, file)
        end
    end
    return out
end

function headers_of(sdk, name)
    local record = module_of(sdk, name)
    if record == nil then
        return nil, "the SDK holds no module " .. name
    end
    if record.kind == "swift" then
        return nil, "no Objective-C or C header; Swift module only"
    end
    if record.kind == "usr" then
        local listed = map_headers(record.map, path.directory(record.map), path.directory(record.map), name)
        if #listed == 0 then
            return nil, "no module map header"
        end
        return listed
    end
    local headers_folder = path.join(record.root, "Headers")
    local map = path.join(record.root, "Modules", "module.modulemap")
    if os.isfile(map) then
        local listed = map_headers(map, headers_folder, record.root, "")
        if #listed > 0 then
            return listed
        end
    end
    local out = {}
    local umbrella = path.join(headers_folder, record.base .. ".h")
    if os.isfile(umbrella) then
        table.insert(out, umbrella)
    end
    for _, file in ipairs(os.files(path.join(headers_folder, "*.h"))) do
        if file ~= umbrella then
            table.insert(out, file)
        end
    end
    if #out == 0 then
        if #os.dirs(path.join(record.root, "Modules", "*.swiftmodule")) > 0 then
            return nil, "no Objective-C or C header; Swift interface only"
        end
        return nil, "no public header in Headers/ and no module map header"
    end
    return out
end

local owner_memo = {}
function usr_owner_of(sdk, file)
    if owner_memo[sdk] == nil then
        local owners = {}
        for _, name in ipairs(discover(sdk).names) do
            local record = module_of(sdk, name)
            if record.kind == "usr" then
                for _, header in ipairs(headers_of(sdk, name) or {}) do
                    owners[header] = owners[header] or name
                end
            end
        end
        owner_memo[sdk] = owners
    end
    return owner_memo[sdk][path.normalize(file)]
end

function umbrella_import(sdk, name)
    local record = module_of(sdk, name)
    if record == nil or record.kind == "usr" or record.kind == "swift" or string.find(name, "/", 1, true) then
        return nil
    end
    local header = path.join(record.root, "Headers", name .. ".h")
    return os.isfile(header) and ("<" .. name .. "/" .. name .. ".h>") or nil
end

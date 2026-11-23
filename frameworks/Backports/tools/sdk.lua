import("core.base.json")

function root()
    return path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
end

function workspace()
    return import("@addon.revenant.workspace", {anonymous = true})
end

function retention()
    return import("@addon.revenant.retention", {anonymous = true})
end

function src_root()
    return path.join(root(), "frameworks", "Backports", "src")
end

function sdk_folder()
    return workspace().sdk()
end

function sdk_version(sdk)
    local settings = json.loadfile(path.join(sdk, "SDKSettings.json"))
    assert(settings and settings.Version, "no Version in " .. path.join(sdk, "SDKSettings.json"))
    return settings.Version
end

function frameworks_dir(sdk)
    return path.join(sdk, "System", "Library", "Frameworks")
end

function framework_names(sdk)
    local names = {}
    for _, dir in ipairs(os.dirs(path.join(frameworks_dir(sdk), "*.framework"))) do
        local name = path.filename(dir)
        table.insert(names, string.sub(name, 1, #name - #".framework"))
    end
    table.sort(names)
    return names
end

function framework_root(sdk, name)
    return path.join(frameworks_dir(sdk), name .. ".framework") .. "/"
end

function umbrella_header(sdk, name)
    local base = path.join(frameworks_dir(sdk), name .. ".framework")
    local header = path.join(base, "Headers", name .. ".h")
    if os.isfile(header) then
        return header
    end
    local map = path.join(base, "Modules", "module.modulemap")
    if os.isfile(map) then
        local text = io.readfile(map)
        local relative = string.match(text, 'umbrella header "([^"]+)"') or string.match(text, 'umbrella "([^"]+)"')
        if relative ~= nil and string.sub(relative, -2) == ".h" then
            for _, folder in ipairs({"Headers", "Modules"}) do
                local candidate = path.join(base, folder, relative)
                if os.isfile(candidate) then
                    return candidate
                end
            end
        end
    end
    return nil
end

function umbrella_import(sdk, name)
    local header = umbrella_header(sdk, name)
    if header == nil then
        return nil
    end
    local headers = path.join(frameworks_dir(sdk), name .. ".framework", "Headers") .. "/"
    if string.sub(header, 1, #headers) == headers then
        return "#import <" .. name .. "/" .. string.sub(header, #headers + 1) .. ">"
    end
    return '#import "' .. header .. '"'
end

function has_swift_module(sdk, name)
    return os.isdir(path.join(frameworks_dir(sdk), name .. ".framework", "Modules", name .. ".swiftmodule"))
end

local FACTS = {"ast.lua", "facts.lua", "public.lua", "sdk.lua"}

local FACTS_EXTERNAL = {["async.runjobs"] = true, ["core.base.json"] = true, ["@addon.revenant.workspace"] = true, ["@addon.revenant.retention"] = true}

function facts_files()
    return table.clone(FACTS)
end

local LOADERS = {"dofile", "loadfile", "loadstring", "load", "require", "includes"}

local function without_strings(text)
    local out, at, size = {}, 1, #text
    while at <= size do
        local char = string.sub(text, at, at)
        if char == '"' or char == "'" then
            local cursor = at + 1
            while cursor <= size do
                local following = string.sub(text, cursor, cursor)
                if following == "\\" then
                    cursor = cursor + 2
                elseif following == char then
                    break
                else
                    cursor = cursor + 1
                end
            end
            table.insert(out, char .. char)
            at = cursor + 1
        else
            table.insert(out, char)
            at = at + 1
        end
    end
    return table.concat(out)
end

function facts_import_problems(folder)
    folder = folder or os.scriptdir()
    local inside = {}
    for _, name in ipairs(FACTS) do
        inside[name] = true
    end
    local problems = {}
    for _, name in ipairs(FACTS) do
        local text = io.readfile(path.join(folder, name))
        local code = without_strings(text)
        for following in string.gmatch(code, "%f[%w_]import%f[^%w_]%s*(.?)") do
            if following ~= "(" then
                table.insert(problems, name .. " uses import without calling it with parentheses (an alias, or a call with a string argument), which the key cannot follow")
            end
        end
        for _, loader in ipairs(LOADERS) do
            for start in string.gmatch(code, "()%f[%w_]" .. loader .. "%f[^%w_]") do
                local before = string.sub(code, start - 1, start - 1)
                if before ~= "." and before ~= ":" then
                    table.insert(problems, name .. " uses " .. loader .. ", which loads code the key does not cover")
                end
            end
        end
        for call in string.gmatch(text, "%f[%w_]import%s*%b()") do
            local module = string.match(call, '^import%s*%(%s*"([^"]+)"')
            if module == nil then
                table.insert(problems, name .. ": " .. string.gsub(call, "%s+", " ") .. " does not name its module by a literal")
            elseif not FACTS_EXTERNAL[module] and (string.find(module, "[%.@/]") or not inside[module .. ".lua"]) then
                table.insert(problems, name .. " imports " .. module .. ", which is not one of " .. table.concat(FACTS, ", ") .. " and not an allowed external module")
            end
        end
    end
    return problems
end

local facts_digest_memo = nil

function facts_digest()
    if facts_digest_memo == nil then
        local problems = facts_import_problems()
        assert(#problems == 0, "the facts cache key does not cover what the facts read:\n" .. table.concat(problems, "\n"))
        local digests = {}
        for _, name in ipairs(FACTS) do
            table.insert(digests, name .. "=" .. hash.sha256(path.join(os.scriptdir(), name)))
        end
        table.sort(digests)
        facts_digest_memo = string.sub(hash.strhash128(table.concat(digests, ";")), 1, 16)
    end
    return facts_digest_memo
end

local identity_memo = {}

function sdk_identity(sdk)
    local real = retention().real_path(sdk)
    if identity_memo[real] == nil then
        local lines = {}
        for _, file in ipairs(os.files(path.join(real, "**"))) do
            local content = os.islink(file) and ("link " .. os.readlink(file)) or hash.sha256(file)
            table.insert(lines, path.relative(file, real) .. "=" .. content)
        end
        table.sort(lines)
        identity_memo[real] = string.sub(hash.strhash128(table.concat(lines, "\n")), 1, 32)
    end
    return identity_memo[real]
end

function build_root()
    return path.join(root(), "build", "generated", "backports")
end

function tool(name)
    return os.iorunv("/usr/bin/xcrun", {"--find", name}):trim()
end

function digester()
    return tool("swift-api-digester")
end

function clang()
    return "/usr/bin/clang"
end

local clang_memo = nil

function clang_identity()
    if clang_memo == nil then
        local lines = {}
        for line in string.gmatch(os.iorunv(clang(), {"--version"}), "[^\n]+") do
            if not string.find(line, "^InstalledDir:") then
                table.insert(lines, line)
            end
        end
        clang_memo = {table.concat(lines, "\n")}
    end
    return clang_memo
end

local digester_memo = nil

function digester_identity()
    if digester_memo == nil then
        local file = digester()
        digester_memo = {tostring(os.filesize(file)), hash.sha256(file)}
    end
    return digester_memo
end

function model_cache(sdk)
    local identity = table.join({retention().real_path(sdk), sdk_version(sdk)}, digester_identity())
    return path.join(workspace().home(), "modcache", string.sub(hash.strhash128(table.concat(identity, "\n")), 1, 16))
end

local key_memo = {}

function cache_key(sdk)
    local real = retention().real_path(sdk)
    if key_memo[real] == nil then
        local identity = table.join({sdk_identity(sdk), sdk_version(sdk), facts_digest()}, clang_identity(), digester_identity())
        key_memo[real] = sdk_version(sdk) .. "-" .. string.sub(hash.strhash128(table.concat(identity, "\n")), 1, 16)
    end
    return key_memo[real]
end

function shared_root()
    return path.join(workspace().home(), "backports")
end

function cache_folder(sdk)
    return path.join(shared_root(), cache_key(sdk))
end

function clean_field(value)
    return (tostring(value or ""):gsub("[\t\n]", " "))
end

function write_rows(file, module, rows)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, table.concat({clean_field(module), clean_field(row.kind), clean_field(row.container),
            clean_field(row.name), clean_field(row.symbol), clean_field(row.signature), row.intro and tostring(row.intro) or "",
            clean_field(row.flags)}, "\t"))
    end
    local temp = file .. "." .. hash.strhash128(tostring({}) .. file) .. ".part"
    io.writefile(temp, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    os.mv(temp, file)
end

function read_rows(file)
    local rows = {}
    if not os.isfile(file) then
        return nil
    end
    for line in io.lines(file) do
        local module, kind, container, name, symbol, signature, intro, flags = string.match(line,
            "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        assert(module, "a malformed facts row in " .. file .. ": " .. line)
        table.insert(rows, {module = module, kind = kind, container = container, name = name, symbol = symbol,
            signature = signature, intro = tonumber(intro), flags = flags})
    end
    return rows
end

function framework_introduced(rows)
    local lowest = nil
    for _, row in ipairs(rows) do
        if row.intro ~= nil and (lowest == nil or row.intro < lowest) then
            lowest = row.intro
        end
    end
    return lowest
end

function framework_image(name)
    return "/System/Library/Frameworks/" .. name .. ".framework/" .. name
end

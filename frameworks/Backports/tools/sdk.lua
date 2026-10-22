import("core.base.json")

function root()
    return path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
end

function workspace()
    return import("@addon.revenant.workspace", {anonymous = true})
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

function has_swift_module(sdk, name)
    return os.isdir(path.join(frameworks_dir(sdk), name .. ".framework", "Modules", name .. ".swiftmodule"))
end

local GENERATOR = {"ast.lua", "facts.lua", "generate.lua", "skeleton.lua", "sdk.lua"}

function generator_digest()
    local digests = {}
    for _, name in ipairs(GENERATOR) do
        local file = path.join(os.scriptdir(), name)
        table.insert(digests, name .. "=" .. hash.sha256(file))
    end
    table.sort(digests)
    return string.sub(hash.strhash128(table.concat(digests, ";")), 1, 16)
end

function build_root()
    return path.join(root(), "build", "generated", "backports")
end

function model_cache()
    return path.join(workspace().home(), "cache", "backports", "modcache")
end

function cache_key(version)
    return version .. "-" .. generator_digest()
end

function cache_folder(version)
    return path.join(build_root(), "cache", cache_key(version))
end

function clean_field(value)
    return (tostring(value or ""):gsub("[\t\n]", " "))
end

function write_rows(file, module, rows)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, table.concat({clean_field(module), clean_field(row.kind), clean_field(row.container),
            clean_field(row.name), clean_field(row.symbol), clean_field(row.signature), row.intro and tostring(row.intro) or ""}, "\t"))
    end
    local temp = file .. ".part"
    io.writefile(temp, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    os.mv(temp, file)
end

function read_rows(file)
    local rows = {}
    if not os.isfile(file) then
        return nil
    end
    for line in io.lines(file) do
        local module, kind, container, name, symbol, signature, intro = string.match(line,
            "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        assert(module, "a malformed facts row in " .. file .. ": " .. line)
        table.insert(rows, {module = module, kind = kind, container = container, name = name, symbol = symbol,
            signature = signature, intro = tonumber(intro)})
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

function in_scope(row, minimum, framework_intro)
    if row.intro ~= nil then
        return row.intro > minimum
    end
    return framework_intro ~= nil and framework_intro > minimum
end

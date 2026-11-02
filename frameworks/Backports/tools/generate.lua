import("async.runjobs")

local publics = import("public", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local facts = import("facts", {rootdir = os.scriptdir(), anonymous = true})
local skeleton = import("skeleton", {rootdir = os.scriptdir(), anonymous = true})
local markers = import("markers", {rootdir = os.scriptdir(), anonymous = true})
local libraries = import("library_list", {rootdir = os.scriptdir(), anonymous = true}).backports_libraries()

local SHARDS = 4
local FIRST_IPHONE_OS = 2000

local function extract(sdk, version, cache, logs, name)
    local rows = facts.objc_facts(sdk, name, version)
    if sdkfiles.has_swift_module(sdk, name) then
        for _, row in ipairs(facts.swift_facts(sdk, name, version, logs)) do
            table.insert(rows, row)
        end
    end
    sdkfiles.write_rows(path.join(cache, name .. ".tsv"), name, rows)
end

local function failure_file(logs, name)
    return path.join(logs, name .. ".failed")
end

local function worker(args)
    local sdk, version, cache, logs = args[2], args[3], args[4], args[5]
    for index = 6, #args do
        local name = args[index]
        try
        {
            function ()
                extract(sdk, version, cache, logs, name)
            end,
            catch
            {
                function (errors)
                    io.writefile(failure_file(logs, name), tostring(errors))
                    raise("%s: %s", name, tostring(errors))
                end
            }
        }
    end
end

local function shard_failure(logs, list, errors)
    local reports = {}
    for _, name in ipairs(list) do
        if os.isfile(failure_file(logs, name)) then
            table.insert(reports, name .. ": " .. string.sub(io.readfile(failure_file(logs, name)), -1500))
        end
    end
    if #reports == 0 then
        reports = {tostring(errors)}
    end
    return table.concat(reports, "\n")
end

function extract_all(sdk, version, cache, logs, names)
    local shards = {}
    for index = 1, math.min(SHARDS, #names) do
        shards[index] = {}
    end
    for index, name in ipairs(names) do
        table.insert(shards[(index - 1) % #shards + 1], name)
    end
    if #shards == 0 then
        return
    end
    runjobs("backports/facts", function (index)
        local list = shards[index]
        local argv = {"l", "-P", sdkfiles.root(), path.join(os.scriptdir(), "generate.lua"), "facts", sdk, version, cache, logs}
        for _, name in ipairs(list) do
            os.tryrm(failure_file(logs, name))
            table.insert(argv, name)
        end
        try
        {
            function ()
                os.execv(os.programfile(), argv)
            end,
            catch
            {
                function (errors)
                    raise("facts failed:\n%s", shard_failure(logs, list, errors))
                end
            }
        }
    end, {total = #shards, comax = #shards})
end

local function ready(sdk, version, logs, names)
    local cache = sdkfiles.cache_folder(sdk)
    os.mkdir(cache)
    local missing = {}
    for _, name in ipairs(names) do
        if not os.isfile(path.join(cache, name .. ".tsv")) then
            table.insert(missing, name)
        end
    end
    for _, stale in ipairs(os.dirs(path.join(sdkfiles.build_root(), "cache", "*"))) do
        if path.filename(stale) ~= sdkfiles.cache_key(sdk) then
            os.tryrm(stale)
        end
    end
    if #missing > 0 then
        os.mkdir(logs)
        extract_all(sdk, version, cache, logs, missing)
    end
    return cache
end

local function frameworks_of(cache, names, sdk)
    local out = {}
    for _, name in ipairs(names) do
        table.insert(out, {name = name, import = sdkfiles.umbrella_import(sdk, name), rows = sdkfiles.read_rows(path.join(cache, name .. ".tsv")) or {}})
    end
    return out
end

local implemented_cache = nil

function implemented_names()
    if implemented_cache then
        return implemented_cache
    end
    local names = {}
    local text = os.iorunv("/usr/bin/grep", {"-rhoE", "--include=*.m", "--include=*.mm",
        "^(@implementation [A-Za-z_][A-Za-z0-9_]*([^(A-Za-z0-9_]|$)|REVENANT_ALIAS(_OF)?\\([A-Za-z_][A-Za-z0-9_]*)", sdkfiles.src_root()})
    for line in text:gmatch("[^\n]+") do
        local name = string.match(line, "^@implementation ([%w_]+)") or string.match(line, "^REVENANT_ALIAS_OF%(([%w_]+)")
            or string.match(line, "^REVENANT_ALIAS%(([%w_]+)")
        if name then
            names[name] = true
        end
    end
    local macros = os.iorunv("/usr/bin/grep", {"-rhoE", "--include=*.m", "--include=*.mm",
        "[A-Z][A-Z0-9_]*\\([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[,)]", sdkfiles.src_root()})
    for line in macros:gmatch("[^\n]+") do
        local name = string.match(line, "%(%s*([%w_]+)")
        if name then
            names[name] = true
        end
    end
    local runtime = os.iorunv("/usr/bin/grep", {"-rhoE", "--include=*.m", "--include=*.mm",
        "objc_runtime_name\\(\"[A-Za-z_][A-Za-z0-9_]*\"\\)", sdkfiles.src_root()})
    for line in runtime:gmatch("[^\n]+") do
        local name = string.match(line, "\"([%w_]+)\"")
        if name then
            names[name] = true
        end
    end
    implemented_cache = names
    return names
end

local markers_cache = nil
local definitions_cache = nil

function markers_of_src()
    if markers_cache == nil then
        local src = sdkfiles.src_root()
        local folders = library_folders()
        local owner = {}
        local definitions = {}
        local listing = os.iorunv("/usr/bin/grep", {"-rlF", "BACKPORT_IMPL(", src})
        for file in listing:gmatch("[^\n]+") do
            local relative = path.relative(file, src)
            if relative ~= "revenant_impl.h" then
                local folder = string.match(relative, "^([^/]+)")
                local text = io.readfile(file)
                local bad = markers.marker_arguments(text)
                if #bad > 0 then
                    raise("%s: BACKPORT_IMPL takes a literal name, not %s", relative, table.concat(bad, ", "))
                end
                for name in pairs(markers.marked(text)) do
                    if owner[name] ~= nil and owner[name] ~= folder then
                        raise("%s is implemented in both src/%s and src/%s", name, owner[name], folder)
                    end
                    owner[name] = folder
                end
                for name, definition in pairs(markers.marked_definitions(text)) do
                    definitions[name] = definition
                end
            end
        end
        for name, folder in pairs(owner) do
            if not folders[folder] then
                raise("%s is implemented in src/%s, which no library builds", name, folder)
            end
        end
        markers_cache = owner
        definitions_cache = definitions
    end
    return markers_cache, definitions_cache
end

function key_of(row)
    return row.kind .. "|" .. row.container .. "|" .. row.name
end

function prepare(only)
    local sdk = sdkfiles.sdk_folder()
    local version = sdkfiles.sdk_version(sdk)
    local logs = path.join(sdkfiles.build_root(), "logs")
    os.mkdir(logs)
    local names = sdkfiles.framework_names(sdk)
    if only then
        local chosen = {}
        for _, name in ipairs(names) do
            if table.contains(only, name) then
                table.insert(chosen, name)
            end
        end
        names = chosen
    end
    local cache = ready(sdk, version, logs, names)
    return {
        sdk = sdk,
        version = version,
        logs = logs,
        frameworks = frameworks_of(cache, names, sdk),
        images = publics.install_names(sdk),
    }
end

local everything_state = nil

function everything()
    everything_state = everything_state or prepare()
    return everything_state
end

function has_flag(row, flag)
    return string.find(" " .. (row.flags or "") .. " ", " " .. flag .. " ", 1, true) ~= nil
end

function unavailable_classes(rows)
    local names = {}
    for _, row in ipairs(rows) do
        if row.kind == "class" and has_flag(row, "unavailable") then
            names[row.name] = true
        end
    end
    return names
end

function unavailable_classes_of(state)
    if state.unavailable_classes == nil then
        local names = {}
        for _, framework in ipairs(state.frameworks) do
            for name in pairs(unavailable_classes(framework.rows)) do
                names[name] = true
            end
        end
        state.unavailable_classes = names
    end
    return state.unavailable_classes
end

function exists_on_ios(row, unavailable)
    if has_flag(row, "unavailable") then
        return false
    end
    if (row.kind == "instance method" or row.kind == "class method" or row.kind == "property") and unavailable[row.container] then
        return false
    end
    return row.intro == nil or row.intro >= FIRST_IPHONE_OS
end

function available_rows(state, framework)
    local unavailable = unavailable_classes_of(state)
    local kept = {}
    for _, row in ipairs(framework.rows) do
        if exists_on_ios(row, unavailable) then
            table.insert(kept, row)
        end
    end
    return kept
end

function unavailable_count(state, framework)
    local unavailable = unavailable_classes_of(state)
    local count = 0
    for _, row in ipairs(framework.rows) do
        if not exists_on_ios(row, unavailable) then
            count = count + 1
        end
    end
    return count
end

local function single_owned(row)
    return row.kind == "class" or row.kind == "global variable"
end

local folders_cache = nil

function library_folders()
    if folders_cache == nil then
        folders_cache = {}
        for _, library in ipairs(libraries) do
            folders_cache[library.folder] = true
        end
    end
    return folders_cache
end

function owners_of(state)
    if state.owners == nil then
        local folders = library_folders()
        local owners = {}
        for _, framework in ipairs(state.frameworks) do
            for _, row in ipairs(available_rows(state, framework)) do
                if single_owned(row) then
                    local key = row.kind .. "|" .. row.name
                    local score = (folders[framework.name] and 2 or 0) + (row.intro ~= nil and 1 or 0)
                    if owners[key] == nil or score > owners[key].score then
                        owners[key] = {framework = framework.name, score = score}
                    end
                end
            end
        end
        state.owners = owners
    end
    return state.owners
end

function pending_of(state, only)
    local owners = owners_of(state)
    local unavailable = unavailable_classes_of(state)
    local pending = {}
    for _, framework in ipairs(state.frameworks) do
        if only == nil or table.contains(only, framework.name) then
            local rows, skipped = {}, {}
            for _, row in ipairs(framework.rows) do
                local owner = single_owned(row) and owners[row.kind .. "|" .. row.name]
                if not single_owned(row) or (owner and owner.framework == framework.name) then
                    if exists_on_ios(row, unavailable) then
                        table.insert(rows, row)
                    else
                        skipped[row.kind] = (skipped[row.kind] or 0) + 1
                    end
                end
            end
            table.insert(pending, {name = framework.name, import = framework.import, rows = rows, skipped = skipped,
                unavailable = unavailable, images = state.images})
        end
    end
    return pending
end

function method_key(row)
    if row.kind == "property" then
        local getter = string.match(row.flags or "", "getter:(%S+)") or row.name
        return (has_flag(row, "class") and "class method" or "instance method") .. "|" .. row.container .. "|" .. getter
    end
    return row.kind .. "|" .. row.container .. "|" .. row.name
end

function inherited_init(row)
    return row.kind == "instance method" and row.name == "init"
end

function is_implemented(implemented, framework, row)
    local keys = implemented[framework.name] or {}
    if row.kind == "Swift declaration" then
        return keys["swift symbol||" .. row.symbol] == true
    elseif row.kind == "class" or row.kind == "C function" or row.kind == "global variable" then
        return keys[key_of(row)] == true
    end
    if inherited_init(row) or keys[method_key(row)] == true then
        return true
    end
    local proxy = row.kind .. "|Revenant" .. row.container .. "|" .. row.name
    if row.kind == "property" then
        proxy = (has_flag(row, "class") and "class method" or "instance method") .. "|Revenant" .. row.container .. "|"
            .. (string.match(row.flags or "", "getter:(%S+)") or row.name)
    end
    return keys[proxy] == true
end

function main(...)
    local args = {...}
    if args[1] == "facts" then
        return worker(args)
    end
    local state = everything()
    local pending = pending_of(state)
    os.tryrm(path.join(sdkfiles.build_root(), "skeleton"))
    local owners, definitions = markers_of_src()
    local totals = skeleton.write(path.join(sdkfiles.build_root(), "skeleton"), pending, implemented_names(), state.images, owners, definitions)
    local skipped = 0
    for _, framework in ipairs(pending) do
        for _, count in pairs(framework.skipped) do
            skipped = skipped + count
        end
    end
    print(string.format("skeleton: %d ObjC methods, %d classes, %d protocols, %d globals (%d not copied), %d C functions, %d trampolines, %d implemented in src (%d of them absent from the facts), %d Swift symbols, %d unavailable on iOS (not stubbed) under %s",
        totals.objc, totals.classes, totals.protocols, totals.globals, totals.globals_uncopied, totals.c, totals.trampolines, totals.c_in_src, totals.src_only, totals.swift, skipped,
        path.join(sdkfiles.build_root(), "skeleton")))
end

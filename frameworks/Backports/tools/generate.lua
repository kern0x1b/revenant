import("async.runjobs")
import("core.project.project")

local ast = import("ast", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local facts = import("facts", {rootdir = os.scriptdir(), anonymous = true})
local skeleton = import("skeleton", {rootdir = os.scriptdir(), anonymous = true})

local SHARDS = 4

function minimum()
    local option = project.option("backports_min_ios")
    assert(option, "frameworks/Backports/xmake.lua declares no backports_min_ios option")
    local text = option:value() or option:get("default")
    local value = ast.version_of(text)
    assert(value, "backports_min_ios is not an iOS version: " .. tostring(text))
    return value
end

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
    local cache = sdkfiles.cache_folder(version)
    os.mkdir(cache)
    local missing = {}
    for _, name in ipairs(names) do
        if not os.isfile(path.join(cache, name .. ".tsv")) then
            table.insert(missing, name)
        end
    end
    for _, stale in ipairs(os.dirs(path.join(sdkfiles.build_root(), "cache", "*"))) do
        if path.filename(stale) ~= sdkfiles.cache_key(version) then
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

function implemented_classes()
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
    return names
end

function key_of(row)
    return row.kind .. "|" .. row.container .. "|" .. row.name
end

function target_minimum()
    local option = project.option("backports_min_ios")
    assert(option, "frameworks/Backports/xmake.lua declares no backports_min_ios option")
    return option:value() or option:get("default")
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
        minimum = minimum(),
        frameworks = frameworks_of(cache, names, sdk),
    }
end

function skeleton_for(name)
    local state = prepare({name})
    local pending = {}
    for _, framework in ipairs(state.frameworks) do
        table.insert(pending, {name = framework.name, import = framework.import, rows = in_scope_rows(state, framework),
            unavailable = unavailable_classes(framework.rows)})
    end
    return skeleton.write(path.join(sdkfiles.build_root(), "skeleton"), pending, implemented_classes())
end

function in_scope_rows(state, framework)
    local intro = sdkfiles.framework_introduced(framework.rows)
    local kept = {}
    for _, row in ipairs(framework.rows) do
        if sdkfiles.in_scope(row, state.minimum, intro) and not has_flag(row, "unavailable") then
            table.insert(kept, row)
        end
    end
    return kept
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

function has_flag(row, flag)
    return string.find(" " .. (row.flags or "") .. " ", " " .. flag .. " ", 1, true) ~= nil
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
    local state = prepare()
    local pending = {}
    for _, framework in ipairs(state.frameworks) do
        table.insert(pending, {name = framework.name, import = framework.import, rows = in_scope_rows(state, framework),
            unavailable = unavailable_classes(framework.rows)})
    end
    os.tryrm(path.join(sdkfiles.build_root(), "skeleton"))
    local totals = skeleton.write(path.join(sdkfiles.build_root(), "skeleton"), pending, implemented_classes())
    print(string.format("skeleton: %d ObjC methods, %d classes, %d protocols, %d globals, %d C functions, %d Swift symbols under %s",
        totals.objc, totals.classes, totals.protocols, totals.globals, totals.c, totals.swift, path.join(sdkfiles.build_root(), "skeleton")))
end

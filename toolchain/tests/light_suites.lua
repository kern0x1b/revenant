import("core.base.process")

local source = debug.getinfo(1, "S").short_src or ""
if source:startswith("@") then
    source = source:sub(2)
end
local script = path.absolute(source)
local root = path.directory(path.directory(path.directory(script)))

function checkout()
    return root
end

local modules = path.join(root, "toolchain", "modules")
local tests = path.join(root, "toolchain", "tests")
local byteorder = import("byteorder", {rootdir = modules, anonymous = true})
local workspace = import("workspace", {rootdir = modules, anonymous = true})
local tmp_guard = import("tmp_guard", {rootdir = modules, anonymous = true})
local memo = import("memo", {rootdir = modules, anonymous = true})
local suite_guard = import("suite_guard", {rootdir = modules, anonymous = true})
local suite_reads = import("suite_reads", {rootdir = tests, anonymous = true})
local cache = import("cache", {rootdir = modules, anonymous = true})

local VERSION = "light suite memo 1"
local ALWAYS = {"xmake.lua", "xmakew", "toolchain/addon.lua", "toolchain/includes/**", "toolchain/rules/**", "toolchain/toolchains/**", "toolchain/plugins/**",
                "toolchain/tests/light_suites.lua", "toolchain/tests/suite_reads.lua", "toolchain/modules/memo.lua", "toolchain/modules/suite_guard.lua"}
local AMBIENT_SKIPS = {REVENANT_CACHE = true, REVENANT_TASK = true, REVENANT_BUDGET_POOL = true, REVENANT_BUDGET_PATIENCE = true, REVENANT_BUDGET_HELD = true, REVENANT_BUDGET_DISK_GB = true, REVENANT_LIGHT_SUITES_VERDICT = true, REVENANT_SUITE_TRACE = true, REVENANT_SUITE_ROOT = true}
local TOOL_NAMES = {"git", "rsync", "cmake", "ninja", "xcrun", "clang", "cc", "make", "sh"}
local WORKERS = 4

local WEIGHTS = {
    digest_test = 44, golden_generation_test = 35, shared_store_test = 31, store_race_test = 26, compat_test = 18,
    source_lock_test = 18, requires_sources_test = 10, cache_test = 10, store_test = 7,
}

local function declared()
    local text = io.readfile(path.join(root, "toolchain", "tests", "xmake.lua"))
    local list = text:match("local light = {(.-)}")
    if not list then
        raise("toolchain/tests/xmake.lua declares no light suites")
    end
    local suites = {}
    for suite in list:gmatch('"([^"]+)"') do
        table.insert(suites, suite)
    end
    return suites
end

local function tools_facts()
    local lines = {}
    for _, name in ipairs(TOOL_NAMES) do
        local found = try { function () return os.iorunv("sh", {"-c", "command -v " .. name}):trim() end } or "none"
        local version = try { function () return os.iorunv("sh", {"-c", name .. " --version 2>&1 | head -n 1"}):trim() end } or ""
        table.insert(lines, name .. "=" .. found .. " " .. version)
    end
    return table.concat(lines, "\n")
end

local tool_text

local function installed_tools()
    if not tool_text then
        tool_text = tools_facts()
    end
    return tool_text
end

local function suite_facts()
    return installed_tools() .. "\n--\n" .. memo.store_facts() .. "\n--\n" .. memo.sdk_facts()
end

local function step_of(suite)
    return {name = suite, reads = suite_reads.of(suite), facts = suite_facts}
end

function key_for(input, suite)
    return memo.key_of(input, step_of(suite), VERSION, ALWAYS, AMBIENT_SKIPS)
end

local function provenance(record)
    return string.format("ran %s s in %s, at %s", record.seconds, record.worktree, record.head)
end

local function run_suite(suite)
    local addon = path.join(root, "toolchain", "tests", "addon")
    local arguments = {modules = path.join(root, "toolchain", "modules")}
    local failures = {}
    local restore = tmp_guard.forbid(suite)
    suite_guard.start(root, table.join(suite_reads.of(suite) or {"**"}, ALWAYS))
    try {
        function ()
            failures = import(suite, {rootdir = addon, anonymous = true}).failures(arguments)
        end,
        catch {
            function (raised)
                failures = {"the suite raised an error: " .. tostring(raised)}
            end
        },
        finally {
            function ()
                restore()
            end
        }
    }
    return failures
end

function partition(suites, count)
    local ordered = table.clone(suites)
    table.sort(ordered, function (left, right)
        local a, b = WEIGHTS[left] or 1, WEIGHTS[right] or 1
        if a ~= b then
            return a > b
        end
        return byteorder.less(left, right)
    end)
    local buckets = {}
    for index = 1, count do
        buckets[index] = {weight = 0, suites = {}}
    end
    for _, suite in ipairs(ordered) do
        local lightest = buckets[1]
        for _, bucket in ipairs(buckets) do
            if bucket.weight < lightest.weight then
                lightest = bucket
            end
        end
        table.insert(lightest.suites, suite)
        lightest.weight = lightest.weight + (WEIGHTS[suite] or 1)
    end
    local used = {}
    for _, bucket in ipairs(buckets) do
        if #bucket.suites > 0 then
            table.insert(used, bucket.suites)
        end
    end
    return used
end

function workers(granted)
    return math.max(1, math.min(tonumber(granted) or 1, WORKERS))
end

local function run_serial(names)
    local failed = 0
    for _, suite in ipairs(names) do
        for _, failure in ipairs(run_suite(suite)) do
            failed = failed + 1
            print("%s: %s", suite, failure)
        end
    end
    if failed > 0 then
        raise("%d failures in %d light suites", failed, #names)
    end
    print("light suites: %d passed", #names)
end

function environment(overrides)
    local envs = {}
    for name, value in pairs(os.getenvs()) do
        if overrides[name] == nil then
            table.insert(envs, name .. "=" .. value)
        end
    end
    for name, value in pairs(overrides) do
        table.insert(envs, name .. "=" .. value)
    end
    return envs
end

function children_task(logs)
    return path.join(workspace.task(), path.filename(logs), "scratch")
end

local function run_in_children(groups, recalled)
    local children = {}
    local logs = workspace.fresh("light-suites")
    local temporary = path.join(logs, "tmp")
    os.mkdir(temporary)
    local envs = environment({XMAKE_TMPDIR = temporary, TMPDIR = temporary, REVENANT_LIGHT_CHILD = "1", REVENANT_TASK = children_task(logs)})
    local failed, total, failure = 0, 0, nil
    try {
        function ()
            for index, names in ipairs(groups) do
                local log = path.join(logs, string.format("%d.log", index))
                local child = process.openv(os.programfile(), table.join({"l", "-P", root, path.join(root, "toolchain", "tests", "light_suites.lua")}, names),
                                            {outpath = log, errpath = log, envs = envs})
                table.insert(children, {process = child, log = log, count = #names, done = false})
            end
            for _, child in ipairs(children) do
                local _, status = child.process:wait(-1)
                child.done = true
                for line in (io.readfile(child.log) or ""):gmatch("[^\n]*\n?") do
                    if line ~= "" and not line:match("^light suites: %d+ passed\n?$") then
                        io.write(line)
                    end
                end
                if status ~= 0 then
                    failed = failed + 1
                end
                total = total + child.count
            end
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        },
        finally {
            function ()
                for _, child in ipairs(children) do
                    if not child.done then
                        child.process:kill()
                    end
                    child.process:close()
                end
                os.tryrm(logs)
            end
        }
    }
    if failure then
        raise("%s", failure)
    end
    if failed > 0 then
        raise("%d of %d groups of light suites failed", failed, #children)
    end
    print("light suites: %d passed, %d recalled", total, recalled or 0)
end

local function run_with_memo(suites, count)
    local began = os.time()
    local input = memo.inputs(root)
    local store = path.join(cache.store(), "suite-memo")
    local signature = memo.digest(table.concat({input.tool, input.host, memo.ambient_environment(AMBIENT_SKIPS), suite_facts(), memo.manifest_digest(input.files)}, "\n"))
    local keys, pending, recalled = {}, {}, 0
    for _, suite in ipairs(suites) do
        local declaration = table.concat(suite_reads.of(suite) or {"**"}, "\n")
        keys[suite] = memo.cached_value("keys", path.join(suite, memo.digest(signature .. "\n" .. declaration)), function ()
            return key_for(input, suite)
        end)
        if os.getenv("SUITE_DEBUG_KEYS") then
            print("suite key " .. suite .. " " .. keys[suite])
        end
        local record = memo.recalled(store, suite, keys[suite])
        if record then
            recalled = recalled + 1
            print("ok %s memo (%s)", suite, provenance(record))
        else
            table.insert(pending, suite)
        end
    end
    if #pending == 0 then
        print("light suites: %d passed, %d recalled", #suites, recalled)
        return
    end
    run_in_children(partition(pending, count), recalled)
    local seconds = os.time() - began
    local record = {seconds = seconds, worktree = path.filename(root), head = memo.git(root, {"rev-parse", "HEAD"}):trim(), at = os.time()}
    for _, suite in ipairs(pending) do
        memo.remembered(store, suite, keys[suite], record, 40)
    end
end

function main(...)
    local names = {...}
    local suites = declared()
    if #names == 0 then
        run_with_memo(suites, workers(os.getenv("REVENANT_BUDGET_HELD")))
        return
    end
    local known = {}
    for _, suite in ipairs(suites) do
        known[suite] = true
    end
    for _, name in ipairs(names) do
        if not known[name] then
            raise("toolchain/tests/xmake.lua declares no light suite named %s", name)
        end
    end
    if os.getenv("REVENANT_LIGHT_CHILD") == "1" then
        run_serial(names)
        return
    end
    run_in_children({names})
end

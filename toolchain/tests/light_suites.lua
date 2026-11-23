import("core.base.process")

local root = path.absolute(path.directory(path.directory(os.scriptdir())))

local byteorder = import("byteorder", {rootdir = path.join(root, "toolchain", "modules"), anonymous = true})

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

local function run_suite(suite)
    local addon = path.join(root, "toolchain", "tests", "addon")
    local arguments = {modules = path.join(root, "toolchain", "modules")}
    local failures = {}
    try {
        function ()
            failures = import(suite, {rootdir = addon, anonymous = true}).failures(arguments)
        end,
        catch {
            function (raised)
                failures = {"the suite raised an error: " .. tostring(raised)}
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

local function run_parallel(groups)
    local children = {}
    local logs = os.tmpfile()
    local failed, total, failure = 0, 0, nil
    try {
        function ()
            for index, names in ipairs(groups) do
                local log = string.format("%s.%d.log", logs, index)
                local child = process.openv(os.programfile(), table.join({"l", "-P", root, path.join(root, "toolchain", "tests", "light_suites.lua")}, names),
                                            {outpath = log, errpath = log})
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
                    os.tryrm(child.log)
                end
            end
        }
    }
    if failure then
        raise("%s", failure)
    end
    if failed > 0 then
        raise("%d of %d groups of light suites failed", failed, #children)
    end
    print("light suites: %d passed", total)
end

function main(...)
    local names = {...}
    local suites = declared()
    if #names == 0 then
        local groups = partition(suites, workers(os.getenv("REVENANT_BUDGET_HELD")))
        if #groups > 1 then
            run_parallel(groups)
            return
        end
        run_serial(suites)
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
    run_serial(names)
end

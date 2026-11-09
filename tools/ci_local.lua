local ROOT = path.absolute(path.directory(os.scriptdir()))
local GIB = 1024 * 1024 * 1024
local MIN_FREE = 100 * GIB
local MEMORY_GB = 14
local TOTAL_GB = 8
local HARD_TOTAL_GB = 12
local KEEP_RUNS = 5
local DEFAULT_JOBS = "6"
local PARALLEL_JOBS = "3"
local PREBUILT = "kern0x1b/revenant"
local XCODE_DEFAULT = "/Applications/Xcode.app/Contents/Developer"
local BUDGET_MINUTES = 20
local ORDER = {"quick", "checks", "backports", "swift", "package", "repository"}
local ALL = {"quick", "checks", "backports", "swift", "package"}
local HEAVY = {"checks", "backports", "package", "swift", "repository"}
local REPORT = {"quick", "prepare", "checks", "backports", "swift", "package", "repository"}
local ESTIMATE_GB = {quick = 1.5, checks = 2.5, backports = 2.2, package = 1.4, swift = 0.8, repository = 0.5}
local SCRIPT = 'echo $$ > "$CI_LOCAL_PIDFILE"; "$@" > "$CI_LOCAL_LOG" 2>&1; echo $? > "$CI_LOCAL_STATUS"'
local CLONE = 'set -e; mkdir -p "$1"; cd "$2"; for e in $(ls -A); do case "$e" in .cache-private|.cache-boot|.git) ;; *) cp -cR "$e" "$1/" ;; esac; done'
local REMOVE = 'chmod -R u+w "$1" 2>/dev/null; rm -rf "$1"'

local function x(...)
    return table.join({"./xmakew"}, {...})
end

local FRESH = {name = "Start from a fresh configuration, as a new checkout does", argv = x("f", "-P", ".", "-c", "-y", "--emulator_vulkan=n"), fresh = true}
local HOST_CONFIGURE = x("f", "-P", ".", "-y", "--emulator_vulkan=n")
local BACKPORTS_CONFIGURE = x("f", "-P", ".", "-p", "iphoneos", "-a", "armv7", "--component=Backports", "-y", "-v")
local DYLD_FETCH = x("firmware", "-P", ".", "-y", "--arch=armv7", "fetch", "6.0")
local INVENTORY = x("firmware", "-P", ".", "-y", "--arch=armv7", "classes", "6.0")
local SWIFTUI_CONFIGURE = x("f", "-P", ".", "-p", "iphoneos", "-a", "armv7", "--component=SwiftUIDemo", "--emulator_vulkan=n", "-y", "-v")
local SWIFT_CONFIGURE = x("f", "-P", ".", "-p", "iphoneos", "-a", "armv7", "--component=Swift", "-y", "-v")
local SWIFT_TARGETS = {"AppIntents", "ActivityKit", "TipKit", "WidgetKit", "swiftSpatial", "swiftCloudKit", "swiftWeatherKit", "swiftNetwork", "swiftUniformTypeIdentifiers", "swiftCryptoKit", "swiftStoreKit", "swiftAuthenticationServices"}
local SWIFT_PACKAGES = {"revenant@appintents", "revenant@activitykit", "revenant@tipkit", "revenant@storekit", "revenant@authenticationservices", "revenant@widgetkit", "revenant@swiftui", "revenant@spatial", "revenant@cloudkit", "revenant@weatherkit", "revenant@uniformtypeidentifiers", "revenant@cryptokit"}

local JOBS = {
    quick = {prebuilt = "llvm,swift,ld64", steps = {
        {name = "Run the prepush checks", argv = x("l", "-P", ".", "tools/prepush.lua")},
    }},
    checks = {prebuilt = "llvm,swift,ld64", steps = {
        {name = "Install the packages", argv = HOST_CONFIGURE},
        {name = "Install the firmware tools through the Backports configuration", when = "no_inventory", argv = BACKPORTS_CONFIGURE},
        {name = "Fetch the iOS 6.0 armv7 shared cache", when = "no_dyld", argv = DYLD_FETCH},
        {name = "Write the iOS 6.0 inventory from the shared cache", when = "no_inventory", argv = INVENTORY},
        {name = "Configure the host again", when = "no_inventory", argv = HOST_CONFIGURE},
        {name = "Assert the iOS 6.0 inventory is in place", assert = "inventory"},
        {name = "Run the tests", argv = x("test", "-P", ".", "--output-on-failure")},
    }},
    backports = {prebuilt = "llvm,swift,ld64", steps = {
        {name = "Configure the Backports component", argv = BACKPORTS_CONFIGURE},
        {name = "Extract the facts of every framework", argv = x("l", "-P", ".", "frameworks/Backports/tools/generate.lua")},
        {name = "Build the Backports component", argv = x("build", "-P", ".")},
        {name = "Run the Backports tests", argv = x("test", "-P", ".", "backports_uikit/*", "--output-on-failure")},
        {name = "Link the probe app against the Backports libraries", argv = x("build", "-P", ".", "BackportsProbe")},
        {name = "Probe the Backports libraries", argv = x("l", "-P", ".", "frameworks/Backports/tools/probe.lua", "build/iphoneos/armv7/release/BackportsProbe")},
        {name = "Check the exports and count the implemented members", argv = x("l", "-P", ".", "frameworks/Backports/tools/exports.lua")},
    }},
    swift = {prebuilt = "llvm,swift,ld64,swift-runtime,libcxx", steps = {
        {name = "Install the firmware tools through the Backports configuration", when = "no_dyld", argv = BACKPORTS_CONFIGURE},
        {name = "Fetch the iOS 6.0 armv7 shared cache", when = "no_dyld", argv = DYLD_FETCH},
        {name = "Configure the Swift component", argv = SWIFT_CONFIGURE},
        {name = "Build the Swift targets", argv = table.join(x("build", "-P", "."), SWIFT_TARGETS)},
        {name = "Install the Swift packages through their wrappers", argv = table.join(x("require", "-P", ".", "-y"), SWIFT_PACKAGES)},
    }},
    package = {prebuilt = "llvm,swift,ld64,swift-runtime,libcxx", steps = {
        {name = "Update the package repositories for the keys", argv = x("repo", "-u")},
        {name = "Fetch the iOS 6.0 armv7 shared cache", when = "no_dyld", argv = DYLD_FETCH},
        {name = "Configure the SwiftUI demo's component", argv = SWIFTUI_CONFIGURE},
        {name = "Build the demo and package it with its platform package", argv = x("deb", "-P", ".", "SwiftUIDemo")},
        {name = "Check the demo's Depends and the platform package's file list", argv = x("l", "-P", ".", "toolchain/tools/deb_check.lua", "build", "space.kern0x1b.swiftui", "org.revenant.backports")},
    }},
    repository = {prebuilt = "llvm,swift,ld64", steps = {
        {name = "Install the packages", argv = HOST_CONFIGURE},
        {name = "Run the repository checks", argv = x("test", "-P", ".", "repository/*", "--output-on-failure")},
    }},
    prepare = {prebuilt = "llvm,swift,ld64", steps = {
        {name = "Install the firmware tools through the Backports configuration", when = "no_inventory_or_dyld", argv = BACKPORTS_CONFIGURE},
        {name = "Fetch the iOS 6.0 armv7 shared cache", when = "no_dyld", argv = DYLD_FETCH},
        {name = "Write the iOS 6.0 inventory from the shared cache", when = "no_inventory", argv = INVENTORY},
        {name = "Configure the host again", when = "no_inventory", argv = HOST_CONFIGURE},
    }},
}

for _, name in ipairs(ORDER) do
    table.insert(JOBS[name].steps, 1, FRESH)
end

local function cache()
    return os.getenv("REVENANT_CACHE")
end

local function inventory()
    return path.join(cache(), "dyld", "6.0", "classes_armv7.json")
end

local function dyld()
    return path.join(cache(), "dyld", "6.0", "dyld_shared_cache_armv7")
end

local function lines(text)
    local result = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(result, line)
    end
    return result
end

local function free_bytes()
    local rows = lines(os.iorunv("df", {"-Pk", cache()}))
    local fields = {}
    for field in rows[#rows]:gmatch("%S+") do
        table.insert(fields, field)
    end
    return tonumber(fields[4]) * 1024
end

local function snapshot()
    local rss, children = {}, {}
    for _, line in ipairs(lines(os.iorunv("ps", {"-axo", "pid=,ppid=,rss="}))) do
        local pid, ppid, kb = line:match("^%s*(%d+)%s+(%d+)%s+(%d+)")
        if pid then
            pid, ppid = tonumber(pid), tonumber(ppid)
            rss[pid] = tonumber(kb)
            children[ppid] = children[ppid] or {}
            table.insert(children[ppid], pid)
        end
    end
    return rss, children
end

local function subtree(rss, children, root)
    local pids, total, queue = {}, 0, {root}
    while #queue > 0 do
        local pid = table.remove(queue)
        if rss[pid] then
            table.insert(pids, pid)
            total = total + rss[pid]
        end
        for _, child in ipairs(children[pid] or {}) do
            table.insert(queue, child)
        end
    end
    return total, pids
end

local function tree(root)
    local rss, children = snapshot()
    return subtree(rss, children, root)
end

local function kill(pids)
    local args = {"-KILL"}
    for _, pid in ipairs(pids) do
        table.insert(args, tostring(pid))
    end
    os.execv("kill", args, {try = true})
end

local function watch(pidfile, statfile, limit_kb)
    local root, peak, killed = nil, 0, false
    local started = os.mclock()
    while not os.isfile(statfile) do
        if not root and os.isfile(pidfile) then
            root = tonumber(io.readfile(pidfile):trim())
        end
        if root then
            local total, pids = tree(root)
            if #pids == 0 then
                break
            end
            peak = math.max(peak, total)
            if total > limit_kb then
                kill(pids)
                killed = true
                break
            end
        elseif os.mclock() - started > 10000 then
            break
        end
        os.sleep(1000)
    end
    return peak, killed
end

local function execute(argv, log, limit_kb)
    local pidfile = log .. ".pid"
    local statfile = log .. ".status"
    os.execv("/bin/sh", table.join({"-c", SCRIPT, "ci-local"}, argv), {
        curdir = ROOT,
        detach = true,
        envs = {CI_LOCAL_PIDFILE = pidfile, CI_LOCAL_LOG = log, CI_LOCAL_STATUS = statfile},
    })
    local peak, killed = watch(pidfile, statfile, limit_kb)
    local code = os.isfile(statfile) and tonumber(io.readfile(statfile):trim()) or nil
    return {ok = code == 0 and not killed, code = code, killed = killed, peak = peak}
end

local function applies(step)
    if step.when == "no_inventory" then
        return not os.isfile(inventory())
    elseif step.when == "no_dyld" then
        return not os.isfile(dyld())
    elseif step.when == "no_inventory_or_dyld" then
        return not os.isfile(inventory()) or not os.isfile(dyld())
    end
    return true
end

local function minutes(ms)
    return string.format("%.1f min", ms / 60000)
end

local function gigabytes(kb)
    return string.format("%.1f GB", kb / (1024 * 1024))
end

local function memory_limit_kb()
    return (tonumber(os.getenv("REVENANT_CI_LOCAL_MEMORY_GB")) or MEMORY_GB) * GIB / 1024
end

local function budget_kb(variable, default)
    return (tonumber(os.getenv(variable)) or default) * GIB / 1024
end

local function load()
    local text = os.iorunv("uptime"):trim()
    return text:match("load averages?: (.+)$") or text
end

local function run_job(name, dir, limit_kb)
    local job = JOBS[name]
    local began = os.mclock()
    local peak = 0
    os.setenv("REVENANT_PREBUILT", PREBUILT)
    os.setenv("REVENANT_PREBUILT_ONLY", job.prebuilt)
    for index, step in ipairs(job.steps) do
        local label = string.format("%s %d/%d %s", name, index, #job.steps, step.name)
        if free_bytes() < MIN_FREE then
            print("%s: FAIL, free disk is below 100 GiB", label)
            return {name = name, ok = false, step = step.name, reason = "free disk", seconds = os.mclock() - began, peak = peak}
        end
        if step.assert then
            if not os.isfile(inventory()) then
                print("%s: FAIL, %s is missing", label, inventory())
                return {name = name, ok = false, step = step.name, reason = "missing inventory", seconds = os.mclock() - began, peak = peak}
            end
            print("%s: ok", label)
        elseif not applies(step) then
            print("%s: cached, skipped", label)
        else
            local log = path.join(dir, string.format("%s-%02d.log", name, index))
            local started = os.mclock()
            local result = execute(step.argv, log, limit_kb)
            peak = math.max(peak, result.peak)
            local outcome = result.ok and "ok" or (result.killed and "KILLED at the memory limit" or (result.code and string.format("exit %s", result.code) or "no exit status"))
            print("%s: %s, %s, peak %s", label, outcome, minutes(os.mclock() - started), gigabytes(result.peak))
            if not result.ok then
                return {name = name, ok = false, step = step.name, log = log, reason = outcome, seconds = os.mclock() - began, peak = peak}
            end
        end
    end
    return {name = name, ok = true, seconds = os.mclock() - began, peak = peak}
end

local function select_jobs(args)
    local names = {}
    local index = 1
    while index <= #args do
        local argument = args[index]
        local value
        if argument == "--job" then
            index = index + 1
            value = args[index]
        elseif argument:startswith("--job=") then
            value = argument:sub(7)
        else
            value = argument
        end
        if value == "all" then
            for _, name in ipairs(ALL) do
                names[name] = true
            end
        elseif value and JOBS[value] and value ~= "prepare" then
            names[value] = true
        else
            raise("usage: ./xmakew l -P . tools/ci_local.lua [--parallel] [--job] quick|checks|backports|swift|package|repository|all ... | test")
        end
        index = index + 1
    end
    local any = false
    for _ in pairs(names) do
        any = true
    end
    if not any then
        for _, name in ipairs(ALL) do
            names[name] = true
        end
    end
    return names
end

local function prune_runs(root)
    local runs = {}
    for _, name in ipairs(lines(os.iorunv("ls", {"-1", root}))) do
        if name:match("^%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d$") then
            table.insert(runs, name)
        end
    end
    table.sort(runs, function (a, b) return a > b end)
    for index = KEEP_RUNS + 1, #runs do
        os.execv("rm", {"-rf", path.join(root, runs[index])}, {try = true})
    end
end

local function git(...)
    return os.iorunv("git", table.join({"-C", ROOT}, {...})):trim()
end

local function works(developer)
    return try { function () os.iorunv("env", {"DEVELOPER_DIR=" .. developer, "xcrun", "--find", "clang"}) return true end } or false
end

local function toolchain(requested)
    local developer = requested or os.getenv("DEVELOPER_DIR")
    if developer then
        if not os.isdir(developer) or not works(developer) then
            raise("the developer dir %s has no working xcrun", developer)
        end
    elseif os.isdir(XCODE_DEFAULT) then
        if works(XCODE_DEFAULT) then
            developer = XCODE_DEFAULT
        else
            print("ci_local: %s has no working xcrun yet, so the Command Line Tools are used", XCODE_DEFAULT)
        end
    end
    if developer then
        os.setenv("DEVELOPER_DIR", developer)
    end
    local sdk = try { function () return os.iorunv("xcrun", {"--show-sdk-version"}):trim() end } or "unknown"
    local version = try { function () return (os.iorunv("xcodebuild", {"-version"}):gsub("%s+", " "):trim()) end } or "no Xcode"
    return developer or "Command Line Tools", sdk, version
end

local function options(args)
    local rest, developer = {}, nil
    local index = 1
    while index <= #args do
        local argument = args[index]
        if argument == "--developer-dir" then
            index = index + 1
            developer = args[index]
        elseif argument:startswith("--developer-dir=") then
            developer = argument:sub(17)
        else
            table.insert(rest, argument)
        end
        index = index + 1
    end
    return rest, developer
end

local function preflight(requested)
    local common = path.directory(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    local shared = path.join(common, ".cache")
    if not cache() then
        raise("REVENANT_CACHE is not set: run through ./xmakew with the private cache of this worktree (tools/private_cache.lua)")
    end
    if path.normalize(cache()) == path.normalize(shared) and path.normalize(ROOT) ~= path.normalize(common) then
        raise("this worktree must not use the main checkout's cache %s: make a private one with tools/private_cache.lua", shared)
    end
    local dirty = #lines(git("status", "--porcelain"))
    print("ci_local: commit %s %s", git("rev-parse", "--short=12", "HEAD"), git("log", "-1", "--format=%s"))
    print("ci_local: tree %s", dirty == 0 and "clean" or string.format("has %d changed or new paths; the result is for the working tree, not the commit", dirty))
    local developer, sdk, version = toolchain(requested)
    print("ci_local: developer dir %s, SDK %s, %s", developer, sdk, version)
    print("ci_local: cache %s", cache())
    print("ci_local: free %.1f GiB on the data volume", free_bytes() / GIB)
end

local function tracked(pattern)
    return lines(git("ls-files", "--", pattern))
end

local function over_budget(ms)
    return ms > BUDGET_MINUTES * 60000
end

local function budget_note(ms)
    return string.format("%s the %d-minute budget", over_budget(ms) and "OVER" or "within", BUDGET_MINUTES)
end

local function test()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("ci_local test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local sources = {}
    for _, file in ipairs(tracked("*xmake.lua")) do
        table.insert(sources, io.readfile(path.join(ROOT, file)))
    end
    local declared = table.concat(sources, "\n")
    local function names(group)
        local found = {}
        for _, name in ipairs(group) do
            found[name] = true
        end
        return found
    end
    check("a name that no xmake file declares is not found", declared:find('"NoTargetOfThisName"', 1, true), nil)
    local reported = names(REPORT)
    for _, name in ipairs(ORDER) do
        check(name .. " is a job", JOBS[name] ~= nil, true)
        check(name .. " is in the report", reported[name], true)
    end
    check("the preparation is in the report", reported.prepare, true)
    for _, name in ipairs(HEAVY) do
        check(name .. " has a memory estimate", ESTIMATE_GB[name] ~= nil, true)
    end
    for _, name in ipairs(ALL) do
        check(name .. " is a job of the default run", JOBS[name] ~= nil, true)
    end
    for name, job in pairs(JOBS) do
        for _, step in ipairs(job.steps) do
            local argv = step.argv
            if argv and not step.fresh then
                local verb = argv[2]
                local label = string.format("%s: %s", name, step.name)
                if verb == "l" then
                    check(label .. ": its script " .. tostring(argv[5]) .. " is in the repository", os.isfile(path.join(ROOT, argv[5])), true)
                elseif verb == "build" or verb == "deb" then
                    for index = 5, #argv do
                        check(label .. ": target " .. argv[index] .. " is declared", declared:find('"' .. argv[index] .. '"', 1, true) ~= nil, true)
                    end
                elseif verb == "test" then
                    for index = 5, #argv do
                        local group = argv[index]:match("^([%w_]+)/")
                        if group then
                            check(label .. ": test group " .. group .. " is declared", declared:find('"' .. group .. '"', 1, true) ~= nil, true)
                        end
                    end
                elseif verb == "require" then
                    for index = 5, #argv do
                        local package = argv[index]:match("^revenant@(.+)$")
                        if package then
                            check(label .. ": package " .. package .. " has a recipe", os.isfile(path.join(ROOT, "packages", package:sub(1, 1), package, "xmake.lua")), true)
                        end
                    end
                end
            end
        end
    end
    check("the quick job runs prepush after its fresh configuration", JOBS.quick.steps[2].argv[5], "tools/prepush.lua")
    local selected = select_jobs({})
    for _, name in ipairs(ALL) do
        check("no job argument selects " .. name, selected[name], true)
    end
    check("no job argument leaves out the repository job", selected.repository, nil)
    local one = select_jobs({"--job", "swift"})
    check("--job swift selects swift alone", one.swift == true and one.checks == nil, true)
    check("a job named without --job is selected", select_jobs({"package"}).package, true)
    check("an unknown job is refused", try { function () select_jobs({"nonsense"}) return true end } or false, false)
    local rss, children = {[1] = 10, [2] = 20, [3] = 30, [4] = 40}, {[1] = {2}, [2] = {3}}
    local total, pids = subtree(rss, children, 1)
    check("a process tree's size is the sum of its members", total, 60)
    check("a process tree lists its members and not the others", #pids, 3)
    check("a step without a condition applies", applies({}), true)
    check("minutes are written with one decimal", minutes(90000), "1.5 min")
    check("a run of twenty minutes is within the budget", over_budget(BUDGET_MINUTES * 60000), false)
    check("a run past twenty minutes is over the budget", over_budget(BUDGET_MINUTES * 60000 + 1), true)
    check("the budget note names the budget", budget_note(0), "within the 20-minute budget")
    print("ci_local: %d checks of the jobs, their scripts, targets, test groups and packages passed", count)
end

local function work(name, dir)
    local result = run_job(name, dir, memory_limit_kb())
    local fields = result.ok and {"ok"} or {"fail", result.step or "-", result.reason or "failed", result.log or dir}
    io.writefile(path.join(dir, name .. ".result"), table.concat(fields, "\t") .. "\n")
    if not result.ok then
        os.exit(1)
    end
end

local function start_worker(name, dir, clone, estimate)
    local entry = {
        name = name, estimate = estimate, began = os.mclock(), peak = 0, kb = 0, pids = {}, clone = clone,
        pidfile = path.join(dir, name .. ".worker.pid"),
        statfile = path.join(dir, name .. ".worker.status"),
        log = path.join(dir, name .. ".worker.log"),
        result = path.join(dir, name .. ".result"),
    }
    os.execv("/bin/sh", table.join({"-c", SCRIPT, "ci-local"}, {"./xmakew", "l", "-P", clone, "tools/ci_local.lua", "--worker", name, dir}), {
        curdir = clone,
        detach = true,
        envs = {CI_LOCAL_PIDFILE = entry.pidfile, CI_LOCAL_LOG = entry.log, CI_LOCAL_STATUS = entry.statfile},
    })
    return entry
end

local function collect(entry)
    local result = {name = entry.name, seconds = os.mclock() - entry.began, peak = entry.peak, ok = false}
    if entry.reason then
        result.reason = entry.reason
    elseif os.isfile(entry.result) then
        local fields = {}
        for field in io.readfile(entry.result):trim():gmatch("[^\t]+") do
            table.insert(fields, field)
        end
        result.ok = fields[1] == "ok"
        result.step, result.reason, result.log = fields[2], fields[3], fields[4]
    else
        result.reason = "the worker did not report a result"
    end
    return result
end

local function print_log(entry)
    if os.isfile(entry.log) then
        for _, line in ipairs(lines(io.readfile(entry.log))) do
            print("%s", line)
        end
    end
end

local function remove_tree(clone)
    os.execv("/bin/sh", {"-c", REMOVE, "ci-local", clone}, {try = true})
end

local function schedule(names, dir, limit_kb)
    local budget = budget_kb("REVENANT_CI_LOCAL_TOTAL_GB", TOTAL_GB)
    local hard = budget_kb("REVENANT_CI_LOCAL_HARD_TOTAL_GB", HARD_TOTAL_GB)
    local pending, running, done = {}, {}, {}
    local peak_total = 0
    local clones = {}
    for _, name in ipairs(names) do
        table.insert(pending, name)
        if name == "quick" then
            clones[name] = ROOT
        else
            clones[name] = path.join(dir, "tree-" .. name)
            os.execv("/bin/sh", {"-c", CLONE, "ci-local", clones[name], ROOT})
        end
    end
    while #pending > 0 or #running > 0 do
        local committed = 0
        for _, entry in ipairs(running) do
            committed = committed + entry.estimate
        end
        local index = 1
        while index <= #pending do
            local name = pending[index]
            local estimate = ESTIMATE_GB[name] * GIB / 1024
            if #running == 0 or committed + estimate <= budget then
                table.remove(pending, index)
                table.insert(running, start_worker(name, dir, clones[name], estimate))
                committed = committed + estimate
            else
                index = index + 1
            end
        end
        os.sleep(1000)
        local rss, children = snapshot()
        local total, worst = 0, nil
        for _, entry in ipairs(running) do
            if not entry.root and os.isfile(entry.pidfile) then
                entry.root = tonumber(io.readfile(entry.pidfile):trim())
            end
            if entry.root then
                entry.kb, entry.pids = subtree(rss, children, entry.root)
            end
            entry.peak = math.max(entry.peak, entry.kb)
            total = total + entry.kb
            if not worst or entry.kb > worst.kb then
                worst = entry
            end
        end
        peak_total = math.max(peak_total, total)
        if worst and total > hard then
            kill(worst.pids)
            worst.reason = "KILLED at the shared memory limit"
        end
        local still = {}
        for _, entry in ipairs(running) do
            if entry.kb > limit_kb and not entry.reason then
                kill(entry.pids)
                entry.reason = "KILLED at the memory limit"
            end
            local gone = entry.root ~= nil and #entry.pids == 0
            if entry.root == nil and os.mclock() - entry.began > 15000 then
                entry.reason = "the worker did not start"
            end
            if entry.reason or gone or os.isfile(entry.statfile) then
                local result = collect(entry)
                print_log(entry)
                if entry.clone ~= ROOT then
                    remove_tree(entry.clone)
                end
                table.insert(done, result)
            else
                table.insert(still, entry)
            end
        end
        running = still
    end
    return done, peak_total
end

local function run_serial(selected, dir, limit_kb)
    local by_name, quick_failed = {}, false
    for _, name in ipairs(ORDER) do
        if selected[name] and not (name ~= "quick" and quick_failed) then
            by_name[name] = run_job(name, dir, limit_kb)
            if name == "quick" and not by_name[name].ok then
                quick_failed = true
            end
        end
    end
    return by_name
end

local function run_parallel(selected, dir, limit_kb)
    local by_name, heavy = {}, {}
    for _, name in ipairs(HEAVY) do
        if selected[name] then
            table.insert(heavy, name)
        end
    end
    if #heavy == 0 then
        by_name.quick = run_job("quick", dir, limit_kb)
        return by_name, nil
    end
    if selected.checks or selected.swift or selected.package then
        by_name.prepare = run_job("prepare", dir, limit_kb)
        if not by_name.prepare.ok then
            return by_name, nil
        end
    end
    local names = heavy
    if selected.quick then
        names = table.join({"quick"}, heavy)
    end
    local done, peak = schedule(names, dir, limit_kb)
    for _, result in ipairs(done) do
        by_name[result.name] = result
    end
    return by_name, peak
end

local function report(by_name, selected, dir, began, peak_total)
    local overall, parts, failed = "PASS", {}, false
    for _, name in ipairs(REPORT) do
        local result = by_name[name]
        if result then
            if not result.ok then
                overall, failed = "FAIL", true
            end
            table.insert(parts, string.format("%s %s %s %s", name, result.ok and "PASS" or "FAIL", minutes(result.seconds), gigabytes(result.peak)))
        elseif selected[name] then
            table.insert(parts, name .. " skipped")
        end
    end
    print("ci_local: %s | %s", overall, table.concat(parts, " | "))
    for _, name in ipairs(REPORT) do
        local result = by_name[name]
        if result and not result.ok then
            print("ci_local: %s failed at '%s' (%s), log %s", name, result.step or "-", result.reason or "failed", result.log or dir)
        end
    end
    if peak_total then
        print("ci_local: wall %s, %s, peak total resident %s across the jobs at once (sampled each second)", minutes(os.mclock() - began), budget_note(os.mclock() - began), gigabytes(peak_total))
    else
        print("ci_local: wall %s, %s", minutes(os.mclock() - began), budget_note(os.mclock() - began))
    end
    print("ci_local: logs in %s (the last %d runs are kept)", dir, KEEP_RUNS)
    return failed
end

function main(...)
    local args, requested = options({...})
    if args[1] == "test" then
        return test()
    elseif args[1] == "--worker" then
        return work(args[2], args[3])
    end
    local serial, rest = true, {}
    for _, argument in ipairs(args) do
        if argument == "--parallel" then
            serial = false
        else
            table.insert(rest, argument)
        end
    end
    local selected = select_jobs(rest)
    preflight(requested)
    local heavy_count = 0
    for _, name in ipairs(HEAVY) do
        if selected[name] then
            heavy_count = heavy_count + 1
        end
    end
    if not os.getenv("XMAKE_MAX_JOBS") then
        if serial or heavy_count < 2 then
            os.setenv("XMAKE_MAX_JOBS", DEFAULT_JOBS)
        else
            os.setenv("XMAKE_MAX_JOBS", os.getenv("REVENANT_CI_LOCAL_JOBS") or PARALLEL_JOBS)
        end
    end
    local limit_kb = memory_limit_kb()
    print("ci_local: %s mode, jobs -j %s, memory limit %s per job (sum of resident sizes of its processes)", serial and "serial" or "parallel", os.getenv("XMAKE_MAX_JOBS"), gigabytes(limit_kb))
    print("ci_local: load before %s", load())
    local root = path.join(cache(), "scratch", "ci-local")
    local dir = path.join(root, os.date("%Y%m%d-%H%M%S"))
    os.execv("mkdir", {"-p", dir})
    prune_runs(root)
    local began = os.mclock()
    local by_name, peak_total
    if serial then
        by_name = run_serial(selected, dir, limit_kb)
    else
        by_name, peak_total = run_parallel(selected, dir, limit_kb)
    end
    local failed = report(by_name, selected, dir, began, peak_total)
    print("ci_local: load after %s", load())
    if failed then
        os.exit(1)
    end
end

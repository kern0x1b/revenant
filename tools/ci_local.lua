local ROOT = path.absolute(path.directory(os.scriptdir()))
local GIB = 1024 * 1024 * 1024
local MIN_FREE = 100 * GIB
local MEMORY_GB = 14
local KEEP_RUNS = 5
local DEFAULT_JOBS = "6"
local PREBUILT = "kern0x1b/revenant"
local XCODE_CI = "/Applications/Xcode_26.6.app/Contents/Developer"
local WORKFLOW = path.join(ROOT, ".github", "workflows", "check.yml")
local ORDER = {"quick", "checks", "backports", "swift", "package", "repository"}
local ALL = {"quick", "checks", "backports", "swift", "package"}
local SCRIPT = 'echo $$ > "$CI_LOCAL_PIDFILE"; "$@" > "$CI_LOCAL_LOG" 2>&1; echo $? > "$CI_LOCAL_STATUS"'

local function x(...)
    return table.join({"./xmakew"}, {...})
end

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
}

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

local function tree(root)
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

local function execute(argv, log, dir, limit_kb)
    local pidfile = path.join(dir, "pid")
    local statfile = path.join(dir, "status")
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
    end
    return true
end

local function minutes(ms)
    return string.format("%.1f min", ms / 60000)
end

local function gigabytes(kb)
    return string.format("%.1f GB", kb / (1024 * 1024))
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
            local result = execute(step.argv, log, dir, limit_kb)
            peak = math.max(peak, result.peak)
            local outcome = result.ok and "ok" or (result.killed and "KILLED at the memory limit" or string.format("exit %s", tostring(result.code)))
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
        elseif value and JOBS[value] then
            names[value] = true
        else
            raise("usage: ./xmakew l -P . tools/ci_local.lua [--job] quick|checks|backports|swift|package|repository|all ... | test")
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
    local runs = lines(os.iorunv("ls", {"-1r", root}))
    for index = KEEP_RUNS + 1, #runs do
        os.execv("rm", {"-rf", path.join(root, runs[index])}, {try = true})
    end
end

local function git(...)
    return os.iorunv("git", table.join({"-C", ROOT}, {...})):trim()
end

local function toolchain()
    local developer = os.getenv("DEVELOPER_DIR")
    if not developer and os.isdir(XCODE_CI) then
        developer = XCODE_CI
        os.setenv("DEVELOPER_DIR", developer)
    end
    local sdk = try { function () return os.iorunv("xcrun", {"--show-sdk-version"}):trim() end }
    return developer or "Command Line Tools", sdk or "unknown"
end

local function preflight()
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
    local developer, sdk = toolchain()
    print("ci_local: developer dir %s, SDK %s (CI selects %s)", developer, sdk, XCODE_CI)
    print("ci_local: cache %s", cache())
    print("ci_local: free %.1f GiB on the data volume", free_bytes() / GIB)
end

local function test()
    local text = io.readfile(WORKFLOW)
    local compact = (text:gsub("[\"']", ""))
    local count = 0
    for _, name in ipairs(ORDER) do
        assert(text:find("\n  " .. name .. ":\n", 1, true), "check.yml has no job " .. name)
        for _, step in ipairs(JOBS[name].steps) do
            if step.argv then
                local line = table.concat(step.argv, " ")
                assert(compact:find(line, 1, true), string.format("%s: '%s' is not a command of check.yml", name, line))
                count = count + 1
            end
        end
    end
    print("ci_local: %d commands of %d jobs are in check.yml", count, #ORDER)
end

function main(...)
    local args = {...}
    if args[1] == "test" then
        return test()
    end
    local selected = select_jobs(args)
    preflight()
    os.setenv("XMAKE_MAX_JOBS", os.getenv("XMAKE_MAX_JOBS") or DEFAULT_JOBS)
    local limit_kb = (tonumber(os.getenv("REVENANT_CI_LOCAL_MEMORY_GB")) or MEMORY_GB) * GIB / 1024
    print("ci_local: jobs -j %s, memory limit %s per job (sum of resident sizes of its processes)", os.getenv("XMAKE_MAX_JOBS"), gigabytes(limit_kb))
    local root = path.join(cache(), "scratch", "ci-local")
    local dir = path.join(root, os.date("%Y%m%d-%H%M%S"))
    os.execv("mkdir", {"-p", dir})
    prune_runs(root)
    local results, quick_failed = {}, false
    for _, name in ipairs(ORDER) do
        if selected[name] then
            if name ~= "quick" and quick_failed then
                table.insert(results, {name = name, skipped = true})
            else
                local result = run_job(name, dir, limit_kb)
                table.insert(results, result)
                if name == "quick" and not result.ok then
                    quick_failed = true
                end
            end
        end
    end
    local overall, parts, failed = "PASS", {}, false
    for _, result in ipairs(results) do
        if result.skipped then
            table.insert(parts, result.name .. " skipped")
        else
            if not result.ok then
                overall, failed = "FAIL", true
            end
            table.insert(parts, string.format("%s %s %s %s", result.name, result.ok and "PASS" or "FAIL", minutes(result.seconds), gigabytes(result.peak)))
        end
    end
    print("ci_local: %s | %s", overall, table.concat(parts, " | "))
    for _, result in ipairs(results) do
        if result.ok == false then
            print("ci_local: %s failed at '%s' (%s), log %s", result.name, result.step or "-", result.reason, result.log or dir)
        end
    end
    print("ci_local: logs in %s (the last %d runs are kept)", dir, KEEP_RUNS)
    if failed then
        os.exit(1)
    end
end

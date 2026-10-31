import("core.base.json")
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local log = import("ci.log", {rootdir = os.scriptdir()})

local LIMIT = 30

local function api(endpoint)
    return try {function () return os.iorunv("gh", {"api", "--allow-escape-sequences", endpoint}) end, catch {function () return nil end}}
end

local function integer(job)
    job.id = string.format("%.0f", job.id)
    return job
end

local function jobs_of(id)
    local run = api("repos/{owner}/{repo}/actions/runs/" .. id .. "/jobs?per_page=100")
    if run then
        local jobs = json.decode(run).jobs
        for _, job in ipairs(jobs) do
            integer(job)
        end
        return jobs
    end
    local job = api("repos/{owner}/{repo}/actions/jobs/" .. id)
    if not job then
        raise("%s is neither a run nor a job of this repository", id)
    end
    return {integer(json.decode(job))}
end

local function save(job, text)
    local folder = path.join(workspace.scratch(), "ci")
    os.mkdir(folder)
    local file = path.join(folder, job.id .. ".log")
    io.writefile(file, text)
    return file
end

local function show(job)
    print("== %s [%s] job %s", job.name, job.conclusion or job.status, job.id)
    if job.conclusion == "success" or job.conclusion == "skipped" then
        return
    end
    local text = api("repos/{owner}/{repo}/actions/jobs/" .. job.id .. "/logs")
    if not text then
        print("   no log")
        return
    end
    local file = save(job, text)
    local result = log.report(text)
    for _, found in ipairs(result.modules) do
        print("   swiftc failed for %s; replay it with: ./xmakew l -P . tools/ci_swiftc_replay.lua %s %s", found.module, file, found.module)
        for _, message in ipairs(found.diagnostics) do
            print("     %s", message)
        end
    end
    if #result.failed > 0 then
        print("   failed tests: %s", table.concat(result.failed, ", "))
    end
    for index, message in ipairs(result.errors) do
        if index > LIMIT then
            print("   ... %d more in %s", #result.errors - LIMIT, file)
            break
        end
        print("   %s", message)
    end
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function read(name)
        return io.readfile(path.join(os.scriptdir(), "ci", "data", name))
    end
    local function contains(list, value)
        for _, item in ipairs(list) do
            if item:find(value, 1, true) then
                return true
            end
        end
        return false
    end

    local swift = log.report(read("swift.log"))
    check("the swiftc module is named", swift.modules[1] and swift.modules[1].module, "swiftSpatial")
    check("its first real diagnostic is kept", swift.modules[1] and swift.modules[1].diagnostics[1]:find("invalid redeclaration", 1, true) ~= nil, true)
    check("the module's diagnostic is listed under the module only", contains(swift.errors, "invalid redeclaration"), false)
    check("the AppIntents probe errors are dropped", contains(swift.errors, "/probes/"), false)
    check("the generic.swift probe is dropped", contains(swift.errors, "generic.swift"), false)

    local runtime = log.report(read("runtime.log"))
    check("the libplist probe is dropped", contains(runtime.errors, "libplist"), false)
    check("the linker failure of the libplist probe is dropped", contains(runtime.errors, "linker command failed"), false)
    check("the curl 404 probe is dropped", contains(runtime.errors, "404"), false)
    check("the probe names no module", #runtime.modules, 0)

    local checks = log.report(read("checks.log"))
    check("the failed test is named", checks.failed[1], "repository/comments_check")
    check("the comment finding is kept", contains(checks.errors, "error: 1 files carry comments"), true)
    check("the stale lowered members are kept", contains(checks.errors, "lowered-members.txt no longer matches"), true)
    check("the negative run that exited 0 is kept", contains(checks.errors, "exited 0, but a negative case must fail"), true)

    print("ci_errors: %d tests passed", count)
end

function main(...)
    local args = {...}
    if args[1] == "test" and #args == 1 then
        test_suite()
    elseif args[1] and args[1]:match("^%d+$") and #args == 1 then
        for _, job in ipairs(jobs_of(args[1])) do
            show(job)
        end
    else
        raise("usage: ./xmakew l -P . tools/ci_errors.lua <run-id|job-id> | test")
    end
end

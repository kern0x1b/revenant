import("async.runjobs")

local root = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local test = path.join(os.scriptdir(), "facts_lock_test.lua")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local base = workspace.fresh("facts-lock-isolation-test")
    local logs = {}
    local statuses = {}
    local RUNS = 4
    runjobs("facts-lock-isolation", function (index)
        local log = path.join(base, index .. ".log")
        logs[index] = log
        statuses[index] = os.execv(os.programfile(), {"l", "-P", root, test}, {try = true, stdout = log, stderr = log})
    end, {total = RUNS, comax = RUNS})
    local roots = {}
    for index = 1, RUNS do
        local text = io.readfile(logs[index]) or ""
        assert(statuses[index] == 0, "run " .. index .. " exited with " .. tostring(statuses[index]) .. ":\n" .. text)
        assert(text:find("FACTS_LOCK_TEST passed", 1, true), "run " .. index .. " did not pass:\n" .. text)
        local found = text:match("FACTS_CACHE ([^\n]+)")
        assert(found, "run " .. index .. " named no facts cache:\n" .. text)
        roots[found] = true
    end
    local count = 0
    for _ in pairs(roots) do
        count = count + 1
    end
    assert(count == RUNS, "concurrent runs must use " .. RUNS .. " different facts caches, but they used " .. count .. ":\n" .. table.concat(table.keys(roots), "\n"))
    os.tryrm(base)
    print("FACTS_LOCK_ISOLATION_TEST passed")
end

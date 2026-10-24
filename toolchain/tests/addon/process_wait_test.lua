import("core.base.process")

local function exited(child, timeout, status, found, what)
    local ok, got = child:wait(timeout)
    if ok ~= 1 or got ~= status then
        table.insert(found, string.format("%s: the wait returned %s, %s, and must return 1 with status %d",
                                          what, tostring(ok), tostring(got), status))
    end
    child:close()
end

function failures(opt)
    local found = {}

    local first = process.openv("true", {}, {})
    local second = process.openv("true", {}, {})
    os.sleep(1000)
    exited(first, 1500, 0, found, "the first of two children that exited before their waits")
    exited(second, 1500, 0, found, "the second of two children that exited before their waits")

    local long = process.openv("sleep", {"3"}, {})
    local short = process.openv("sleep", {"1"}, {})
    exited(long, 3500, 0, found, "the child waited on while another one exits")
    exited(short, 1500, 0, found, "the child that exited during the other child's wait")

    local running = process.openv("sh", {"-c", "sleep 1; exit 3"}, {})
    exited(running, 3000, 3, found, "a child waited on while it runs")

    local spawned = {}
    for index = 1, 4 do
        table.insert(spawned, process.openv("sh", {"-c", "exit " .. index}, {}))
        os.iorunv("true", {})
    end
    os.sleep(1000)
    os.execv("true", {})
    for index, child in ipairs(spawned) do
        exited(child, 1500, index, found, "child " .. index .. " of several that exited before their waits")
    end
    return found
end

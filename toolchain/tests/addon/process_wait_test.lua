import("core.base.process")

-- process:wait reports a child's exit to the wait on that child, whenever the exit comes: before its wait starts, or while
-- another child is waited on. These are the probes that showed the exit lost (golden-probe reap2 to reap4): each of these
-- waits must read its child as exited, with the child's status, and not as running.

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

    -- two children exit before either wait starts
    local first = process.openv("true", {}, {})
    local second = process.openv("true", {}, {})
    os.sleep(1000)
    exited(first, 1500, 0, found, "the first of two children that exited before their waits")
    exited(second, 1500, 0, found, "the second of two children that exited before their waits")

    -- a child that exits while another child is waited on
    local long = process.openv("sleep", {"3"}, {})
    local short = process.openv("sleep", {"1"}, {})
    exited(long, 3500, 0, found, "the child waited on while another one exits")
    exited(short, 1500, 0, found, "the child that exited during the other child's wait")

    -- a child waited on while it runs, with a status that is not zero
    local running = process.openv("sh", {"-c", "sleep 1; exit 3"}, {})
    exited(running, 3000, 3, found, "a child waited on while it runs")

    -- children that exit while the test spawns and runs other processes, and are waited on afterwards
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

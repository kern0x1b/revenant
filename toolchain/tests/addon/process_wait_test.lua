import("core.base.bytes")
import("core.base.pipe")
import("core.base.process")

local BOUND = 30000

local function spawn(program, argv)
    local reader, writer = pipe.openpair("BB")
    local child = process.openv(program, argv, {stdout = writer})
    writer:close()
    return child, reader
end

local function read_readiness(reader, found, what)
    local buff = bytes(16)
    local n = reader:read(buff, 16, {timeout = BOUND})
    if not n or n <= 0 or buff:slice(1, n):str():trim() ~= "ready" then
        table.insert(found, what .. ": the child did not write its readiness line within " .. BOUND .. " ms")
        return false
    end
    return true
end

local function read_until_closed(reader, found, what)
    local buff = bytes(16)
    local n = reader:read(buff, 16, {timeout = BOUND})
    if n ~= 0 then
        table.insert(found, what .. ": the child did not close its output after its readiness line")
    end
end

local function exited(child, status, found, what)
    local ok, got = child:wait(BOUND)
    if ok ~= 1 or got ~= status then
        table.insert(found, string.format("%s: the wait returned %s, %s, and must return 1 with status %d",
                                          what, tostring(ok), tostring(got), status))
    end
    child:close()
end

function failures(opt)
    local found = {}

    local first, first_out = spawn("sh", {"-c", "echo ready"})
    local second, second_out = spawn("sh", {"-c", "echo ready"})
    local what_first = "the first of two children that exited before their waits"
    local what_second = "the second of two children that exited before their waits"
    if read_readiness(first_out, found, what_first) then
        read_until_closed(first_out, found, what_first)
    end
    if read_readiness(second_out, found, what_second) then
        read_until_closed(second_out, found, what_second)
    end
    exited(first, 0, found, what_first)
    exited(second, 0, found, what_second)

    local long, long_out = spawn("sh", {"-c", "echo ready; sleep 3"})
    local short, short_out = spawn("sh", {"-c", "echo ready; sleep 1"})
    local what_long = "the child waited on while another one exits"
    local what_short = "the child that exited during the other child's wait"
    read_readiness(long_out, found, what_long)
    read_readiness(short_out, found, what_short)
    exited(long, 0, found, what_long)
    exited(short, 0, found, what_short)

    local running, running_out = spawn("sh", {"-c", "echo ready; sleep 1; exit 3"})
    local what_running = "a child waited on while it runs"
    read_readiness(running_out, found, what_running)
    exited(running, 3, found, what_running)

    local spawned = {}
    for index = 1, 4 do
        local child, out = spawn("sh", {"-c", "echo ready; exit " .. index})
        table.insert(spawned, {child = child, out = out, index = index})
        os.iorunv("true", {})
    end
    os.execv("true", {})
    for _, entry in ipairs(spawned) do
        local what = "child " .. entry.index .. " of several that exited before their waits"
        if read_readiness(entry.out, found, what) then
            read_until_closed(entry.out, found, what)
        end
        exited(entry.child, entry.index, found, what)
    end
    return found
end

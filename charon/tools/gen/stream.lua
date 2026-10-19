import("core.base.pipe")
import("core.base.bytes")
import("core.base.process")

local SENTINEL = "\127END "
local PID_LINE = "\127PID "
local KILL_CHECKS = 20
local KILL_WAIT = 50
local CHUNK = 1 << 20
local ERROR_LIMIT = 1 << 20
local CHILD_POLL = 100
local CHILD_CHECK = 1
local CHILD_INTERVAL = 20
local STALL_LIMIT = 600000
local DRAIN_WAIT = 10
local WAIT_ERRORS = 100

local function processes()
    local all = {}
    for line in string.gmatch(os.iorunv("ps", {"-axo", "pid=,ppid=,state="}), "[^\n]+") do
        local pid, ppid, state = string.match(line, "^%s*(%d+)%s+(%d+)%s+(%S+)")
        if pid then
            all[pid] = {ppid = ppid, state = state}
        end
    end
    return all
end

local function kill_tree(root)
    local all = processes()
    local ids, queue = {}, {root}
    while #queue > 0 do
        local id = table.remove(queue)
        table.insert(ids, id)
        for other, info in pairs(all) do
            if info.ppid == id then
                table.insert(queue, other)
            end
        end
    end
    os.execv("kill", table.join({"-KILL"}, ids), {try = true})
    local left = {}
    for _ = 1, KILL_CHECKS do
        left = {}
        local now = processes()
        for _, id in ipairs(ids) do
            if now[id] and string.sub(now[id].state, 1, 1) ~= "Z" then
                table.insert(left, id)
            end
        end
        if #left == 0 then
            return
        end
        os.sleep(KILL_WAIT)
    end
    raise("processes still running after the kill: " .. table.concat(left, " "))
end

local function drive(program, args, each, want_err, raw, stall)
    local command = {"-c", 'sh -c \'printf "\\177PID %d\\n" $$; exec "$0" "$@"\' "$@" <&0 & wait $! 2>/dev/null; printf "\\177END %d\\n" $?', "sh", program}
    for _, arg in ipairs(args) do
        table.insert(command, arg)
    end
    local rpipe, wpipe = pipe.openpair("AB", CHUNK)
    local options = {stdout = wpipe}
    local erpipe, ewpipe = nil, nil
    if want_err then
        erpipe, ewpipe = pipe.openpair("AB", CHUNK)
        options.stderr = ewpipe
    end
    local child = process.openv("sh", command, options)
    assert(child, "could not start " .. program)
    wpipe:close()
    if ewpipe then
        ewpipe:close()
    end
    local buff, ebuff = bytes(CHUNK), bytes(CHUNK)
    local carry, status = "", nil
    local program_pid = nil
    local errors = {}
    local function read_errors()
        if erpipe == nil then
            return
        end
        while true do
            local m = erpipe:read(ebuff, CHUNK)
            if m <= 0 then
                break
            end
            table.insert(errors, ebuff:str(1, m))
        end
    end
    local exited, at_end, wait_errors = false, false, 0
    local checked_at = -CHILD_INTERVAL * 1000
    local last_byte = os.mclock()
    local function stop(cause)
        local kill_errors = {}
        try {
            function()
                if program_pid then
                    kill_tree(tostring(program_pid))
                end
            end,
            catch {
                function(e)
                    table.insert(kill_errors, "killing " .. program .. " failed: " .. tostring(e))
                end
            }
        }
        try {
            function()
                child:kill()
            end,
            catch {
                function(e)
                    table.insert(kill_errors, "killing the wrapper of " .. program .. " failed: " .. tostring(e))
                end
            }
        }
        rpipe:close()
        if erpipe then
            erpipe:close()
        end
        raise(tostring(cause) .. (#kill_errors > 0 and ("; " .. table.concat(kill_errors, "; ")) or ""))
    end
    try {
        function()
            while not status do
                read_errors()
                local n = rpipe:read(buff, CHUNK)
                if n > 0 then
                    at_end = false
                    last_byte = os.mclock()
                    local text = carry .. buff:str(1, n)
                    if raw then
                        local waiting = false
                        if program_pid == nil then
                            local newline = string.find(text, "\n", 1, true)
                            if newline == nil then
                                carry, waiting = text, true
                            else
                                program_pid = tonumber(string.match(string.sub(text, 1, newline - 1), "^" .. PID_LINE .. "(%d+)$"))
                                assert(program_pid ~= nil, "no process id from " .. program)
                                text = string.sub(text, newline + 1)
                            end
                        end
                        if not waiting then
                            local at = string.find(text, SENTINEL, 1, true)
                            if at then
                                if at > 1 then
                                    each(string.sub(text, 1, at - 1))
                                end
                                local digits = string.match(text, "^(%d+)\n", at + #SENTINEL)
                                if digits then
                                    status = tonumber(digits)
                                else
                                    carry = string.sub(text, at)
                                end
                            else
                                local keep = math.min(#text, #SENTINEL)
                                if #text > keep then
                                    each(string.sub(text, 1, #text - keep))
                                end
                                carry = string.sub(text, #text - keep + 1)
                            end
                        end
                    else
                        local pos = 1
                        while not status do
                            local newline = string.find(text, "\n", pos, true)
                            if not newline then
                                break
                            end
                            local line = string.sub(text, pos, newline - 1)
                            local at, _, digits = string.find(line, SENTINEL .. "(%d+)$")
                            if at then
                                if at > 1 then
                                    each(string.sub(line, 1, at - 1))
                                end
                                status = tonumber(digits)
                            elseif string.match(line, "^" .. PID_LINE .. "%d+$") then
                                program_pid = tonumber(string.sub(line, #PID_LINE + 1))
                            else
                                each(line)
                            end
                            pos = newline + 1
                        end
                        carry = string.sub(text, pos)
                    end
                elseif n == 0 then
                    assert(stall == false or os.mclock() - last_byte < (stall or STALL_LIMIT),
                           "no output from " .. program .. " for ten minutes")
                    if exited then
                        assert(not at_end, "the program ended without its sentinel: " .. program)
                        local ready = rpipe:wait(pipe.EV_READ, DRAIN_WAIT)
                        if ready < 0 then
                            wait_errors = wait_errors + 1
                            assert(wait_errors <= WAIT_ERRORS, "cannot observe the end of " .. program)
                        end
                        at_end = ready > 0
                    elseif os.mclock() - checked_at < CHILD_INTERVAL then
                        rpipe:wait(pipe.EV_READ, CHILD_INTERVAL)
                    else
                        checked_at = os.mclock()
                        local result = child:wait(CHILD_CHECK)
                        if result == 1 then
                            exited = true
                        elseif result == -1 then
                            wait_errors = wait_errors + 1
                            assert(wait_errors <= WAIT_ERRORS, "cannot observe the exit of " .. program)
                            rpipe:wait(pipe.EV_READ, DRAIN_WAIT)
                        else
                            rpipe:wait(pipe.EV_READ, CHILD_INTERVAL)
                        end
                    end
                else
                    raise("pipe read failed: " .. program)
                end
            end
        end,
        catch {
            function(e)
                stop(e)
            end
        }
    }
    read_errors()
    rpipe:close()
    if erpipe then
        erpipe:close()
    end
    if not exited then
        local finished = 0
        repeat
            finished = child:wait(CHILD_POLL)
        until finished ~= 0
        assert(finished == 1, "could not wait for " .. program)
    end
    child:close()
    local text = table.concat(errors)
    return status, string.sub(text, -ERROR_LIMIT)
end

function lines(program, args, each)
    local status = drive(program, args, each, false, false)
    return status
end

function run(program, args, each)
    return drive(program, args, each, true, false)
end

function text(program, args)
    local parts = {}
    local status, errors = drive(program, args, function(piece)
        table.insert(parts, piece)
    end, true, true)
    return status, table.concat(parts), errors
end

local HEAVY_SECONDS = 1800
function heavy_text(heavy, args)
    local argv = {"timeout", tostring(HEAVY_SECONDS)}
    for _, arg in ipairs(args) do
        table.insert(argv, arg)
    end
    local parts = {}
    local status, errors = drive(heavy, argv, function(piece)
        table.insert(parts, piece)
    end, true, true, false)
    return status, table.concat(parts), errors
end

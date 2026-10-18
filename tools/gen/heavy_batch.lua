-- A batch of heavy commands run as one job in one heavy slot (coordination/heavy.sh), the way swift_shard runs the digester's dumps: the
-- commands go to a file, NUL-separated, and xargs runs WIDTH of them at a time (sh -c each). The batch is bounded by BATCH_TIMEOUT seconds
-- and each command by TIMEOUT. A command's exit status is written to its .status file, so a command the batch never reached has none, and
-- run counts those. One slot for the batch, not one per command: a slot per command queued each of them behind the whole queue.

local WIDTH = 4
local TIMEOUT = 1800
local BATCH_TIMEOUT = 5400
-- A bound sends SIGTERM, then SIGKILL KILL_AFTER seconds later (gtimeout -k): a command that ignores SIGTERM is never left running.
local KILL_AFTER = 30

-- The gtimeout words that bound a command to `timeout` seconds: "gtimeout -k 30 1800". Exported for tests/gen/dump_bound_test.lua.
function bound_prefix(timeout)
    return string.format("gtimeout -k %d %d", KILL_AFTER, timeout)
end

-- A word quoted for sh: in single quotes, with each single quote of the word written as '\''.
function quote(word)
    return "'" .. (string.gsub(word, "'", "'\\''")) .. "'"
end

-- Runs the items as one batch in the heavy slot. An item is {base, command}: the command is shell text, run under gtimeout TIMEOUT, and its
-- exit status goes to base .. ".status". An item that has a status file is not run again, unless fresh: then its status file is removed
-- first, and every item runs. The folder holds the batch's file of commands. Returns the number of items with no status once the batch has
-- run (the batch stopped first, or the slot or BATCH_TIMEOUT did).
function run(heavy, folder, label, items, fresh)
    local commands = {}
    for _, item in ipairs(items) do
        if fresh and os.isfile(item.base .. ".status") then
            os.rm(item.base .. ".status")
        end
        if not os.isfile(item.base .. ".status") then
            table.insert(commands, string.format("%s %s ; echo $? > %s", bound_prefix(TIMEOUT), item.command,
                                                 quote(item.base .. ".status")))
        end
    end
    if #commands > 0 then
        local jobs = path.join(folder, "jobs-" .. label .. ".txt")
        io.writefile(jobs, table.concat(commands, "\0") .. "\0")
        -- xargs' own status is not read: a command that failed has its status file, and one the batch never reached has none, which is
        -- counted below.
        try {
            function()
                os.execv("gtimeout", {"-k", tostring(KILL_AFTER), tostring(BATCH_TIMEOUT), heavy, "sh", "-c",
                                      string.format("xargs -0 -P %d -n 1 sh -c < %s; true", WIDTH, jobs)})
            end,
            catch {
                function(e)
                    print(string.format("%s: the batch failed to start: %s", label, tostring(e)))
                end
            }
        }
    end
    local left = 0
    for _, item in ipairs(items) do
        if not os.isfile(item.base .. ".status") then
            left = left + 1
        end
    end
    return left
end

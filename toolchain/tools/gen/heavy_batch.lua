local WIDTH = 4
local TIMEOUT = 1800
local BATCH_TIMEOUT = 5400
local KILL_AFTER = 30

function bound_prefix(timeout)
    return string.format("gtimeout -k %d %d", KILL_AFTER, timeout)
end

function quote(word)
    return "'" .. (string.gsub(word, "'", "'\\''")) .. "'"
end

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

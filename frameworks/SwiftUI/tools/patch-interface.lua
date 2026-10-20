local OPENER = 'os_log(.fault, log: Log.runtimeIssuesLog, """\n'
local REPLACEMENT = "_ = Log.runtimeIssuesLog"

local function closing_end(s, body)
    local line_start = body
    while line_start <= #s do
        local newline = string.find(s, "\n", line_start, true)
        local line_end = newline and newline - 1 or #s
        local line = string.sub(s, line_start, line_end)
        local _, close = string.find(line, '^%s*"""%)')
        if close then
            return line_start + close - 1
        end
        if not newline then
            break
        end
        line_start = newline + 1
    end
    return nil
end

function main(...)
    local file = ({...})[1]
    local s = io.readfile(file)
    local from = 1
    while true do
        local at = string.find(s, OPENER, from, true)
        if not at then
            break
        end
        local finish = closing_end(s, at + #OPENER)
        if finish then
            io.writefile(file, string.sub(s, 1, at - 1) .. REPLACEMENT .. string.sub(s, finish + 1))
            return
        end
        from = at + 1
    end
    io.stderr:write("the os_log call this script patches was not found in the interface\n")
    os.exit(1)
end

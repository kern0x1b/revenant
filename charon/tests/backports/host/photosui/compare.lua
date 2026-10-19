-- compare.lua HOST PORT STATED - the host's answers against the port's, question by question, and what differs.
--
--    xmake l ./compare.lua <host.answers> <port.answers> <stated-differences.tsv>
--
-- Exits 0 when every question was asked on both sides, every answer is the same, and every stated difference is really a
-- difference; 1 otherwise, naming what it is. The stated file is a comment block of "name<TAB>reason" lines, a question the
-- host's own implementation does not answer at all.
--
-- Three things fail the comparison, and each of them is a failure a plain diff would report as a pass:
--
--   - a question on one side and not the other. Both sides are asked the same questions, so a missing line is a probe that
--     stopped early, and a comparison that skips it is a comparison of fewer questions than it claims.
--   - a difference nobody stated. The stated list is the whole of what may differ, so a new one is a change in behaviour and
--     not a detail.
--   - a stated difference that no longer differs. The statement is about a measurement, and a measurement that moved leaves
--     the statement wrong; passing on it would keep a claim in the tree that its own harness no longer supports.

-- The lines of a file, without their line ends, in order. xmake's handle:lines() keeps the "\n" on each line, so it is taken off
-- here, and the carriage return of a CRLF file with it.
local function lines(path)
    local handle = assert(io.open(path, "rb"))
    local out = {}
    for line in handle:lines() do
        local text = line:gsub("\n$", ""):gsub("\r$", "")
        out[#out + 1] = text
    end
    handle:close()
    return out
end

-- The name and the answer of a "name<TAB>answer" line; a line with no tab is a name with an empty answer, as partition gives.
local function split_tab(line)
    local tab = line:find("\t", 1, true)
    if not tab then
        return line, ""
    end
    return line:sub(1, tab - 1), line:sub(tab + 1)
end

-- {name: answer} and the names in the order they are asked, from a file of "name<TAB>answer" lines. nil, nil when a name is
-- asked twice on this side.
local function read(path)
    local answers, order = {}, {}
    for _, line in ipairs(lines(path)) do
        if line ~= "" then
            local name, answer = split_tab(line)
            if answers[name] ~= nil then
                print("FAIL  " .. name .. " is asked twice on this side, at " .. path)
                return nil, nil
            end
            answers[name] = answer
            order[#order + 1] = name
        end
    end
    return answers, order
end

-- {name: reason} and the names in the order they are stated, from the stated file, skipping the block that explains it.
local function stated(path)
    local reasons, order = {}, {}
    for _, line in ipairs(lines(path)) do
        if line ~= "" and line:sub(1, 2) ~= "//" then
            local name, reason = split_tab(line)
            if reasons[name] == nil then
                order[#order + 1] = name
            end
            reasons[name] = reason
        end
    end
    return reasons, order
end

local function same_list(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function main(...)
    local args = { ... }
    if #args ~= 3 then
        print("usage: xmake l ./compare.lua HOST.ANSWERS PORT.ANSWERS stated-differences.tsv")
        os.exit(2)
    end
    local host, host_order = read(args[1])
    local port, port_order = read(args[2])
    if host == nil or port == nil then
        os.exit(1)
    end

    local differences = 0
    for _, name in ipairs(host_order) do
        if port[name] == nil then
            print("FAIL  " .. name .. " is asked of the host and not of the port")
            differences = differences + 1
        end
    end
    for _, name in ipairs(port_order) do
        if host[name] == nil then
            print("FAIL  " .. name .. " is asked of the port and not of the host")
            differences = differences + 1
        end
    end
    local port_in_host = {}
    for _, name in ipairs(port_order) do
        if host[name] ~= nil then
            port_in_host[#port_in_host + 1] = name
        end
    end
    if not same_list(host_order, port_in_host) then
        print("FAIL  the two sides ask the questions in a different order")
        differences = differences + 1
    end

    local told, told_order = stated(args[3])
    for _, name in ipairs(host_order) do
        if port[name] ~= nil then
            if host[name] == port[name] then
                if told[name] ~= nil then
                    print(string.format("FAIL  %s is stated as a difference and both sides now answer %s, so the statement is stale",
                        name, host[name]))
                    differences = differences + 1
                end
            elseif told[name] ~= nil then
                print(string.format("stated  %s: host %s, port %s - %s", name, host[name], port[name], told[name]))
            else
                print(string.format("FAIL  %s: the host answers %s, the port answers %s, and nobody stated why",
                    name, host[name], port[name]))
                differences = differences + 1
            end
        end
    end
    for _, name in ipairs(told_order) do
        if host[name] == nil then
            print("FAIL  " .. name .. " is stated as a difference and is asked of neither side")
            differences = differences + 1
        end
    end

    local asked = #host_order
    if asked == 0 then
        print("FAIL  no question was asked of either side, so nothing was compared")
        os.exit(1)
    end
    if differences > 0 then
        print(string.format("not ok: %d questions, %d unstated differences", asked, differences))
        os.exit(1)
    end
    print(string.format("ok: %d questions, the host's and the port's answers agree on %d and %d differences are stated with their reasons",
        asked, asked - #told_order, #told_order))
end

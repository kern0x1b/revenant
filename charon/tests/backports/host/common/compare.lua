local modules = path.join(os.scriptdir(), "..", "..", "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = modules, anonymous = true})
local runtime = import("gyb.runtime", {rootdir = modules, anonymous = true})

function repr(value)
    if value == nil then
        return "None"
    end
    return runtime.to_repr(value)
end

function text_lines(file)
    local text = io.readfile(file, {encoding = "binary"}):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    for line in text:gmatch("[^\n]*\n") do
        table.insert(lines, line)
    end
    local rest = text:match("[^\n]+$")
    if rest then
        table.insert(lines, rest)
    end
    return lines
end

local function without_newline(line)
    return (line:gsub("\n$", ""))
end

local stopped

local function stop(message)
    stopped = message
    raise(message)
end

local function read_rows(file)
    local rows = {}
    for number, line in ipairs(text_lines(file)) do
        local bare = without_newline(line)
        local tab = bare:find("\t", 1, true)
        if not tab then
            stop(string.format("FAIL: %s line %d is not a label and a value: %s", file, number, repr(line)))
        end
        local label, value = bare:sub(1, tab - 1), bare:sub(tab + 1)
        if rows[label] ~= nil then
            stop(string.format("FAIL: %s names %s twice, so the two answers cannot be lined up", file, label))
        end
        rows[label] = value
    end
    return rows
end

local function read_declarations(file)
    local declared, why, count = {}, {}, 0
    for number, line in ipairs(text_lines(file)) do
        if number ~= 1 and line:match("%S") and not line:startswith("#") then
            local parts = without_newline(line):split("\t", {strict = true})
            if #parts < 4 then
                stop(string.format("FAIL: %s line %d has no reason, so a difference could be declared without one", file, number))
            end
            if not declared[parts[1]] then
                count = count + 1
            end
            declared[parts[1]] = {parts[2], parts[3]}
            why[parts[1]] = table.concat(parts, "\t", 4)
        end
    end
    return declared, why, count
end

local function count_of(map)
    local count = 0
    for _ in pairs(map) do
        count = count + 1
    end
    return count
end

local function differences(host_file, port_file, expected_file, out)
    local host = read_rows(host_file)
    local port = read_rows(port_file)
    local declared, why, declared_count = read_declarations(expected_file)
    local failures = 0
    if count_of(host) == 0 then
        out(string.format("FAIL: %s holds no case, so there is nothing to compare and the run is not a pass", host_file))
        failures = failures + 1
    end
    if count_of(port) == 0 then
        out(string.format("FAIL: %s holds no case, so there is nothing to compare and the run is not a pass", port_file))
        failures = failures + 1
    end
    if failures > 0 then
        out(string.format("cases read: %d a side; declared differences: %d; undeclared or moved: %d",
                          count_of(host), declared_count, failures))
        return 1
    end
    local labels = {}
    for label in pairs(host) do
        labels[label] = true
    end
    for label in pairs(port) do
        labels[label] = true
    end
    labels = byteorder.keys(labels)
    for _, label in ipairs(labels) do
        local system, mine = host[label], port[label]
        if declared[label] then
            local want_system, want_port = declared[label][1], declared[label][2]
            if system ~= want_system then
                out(string.format("DECLARED DIFFERENCE MOVED (system): %s answers %s, the case declares %s", label, repr(system), repr(want_system)))
                out("  why: " .. why[label])
                failures = failures + 1
            end
            if mine ~= want_port then
                out(string.format("DECLARED DIFFERENCE MOVED (port): %s answers %s, the case declares %s", label, repr(mine), repr(want_port)))
                out("  why: " .. why[label])
                failures = failures + 1
            end
            if system == mine then
                out(string.format("DECLARED DIFFERENCE GONE: %s answers %s on both sides, so the case is stale", label, repr(system)))
                out("  why: " .. why[label])
                failures = failures + 1
            else
                out(string.format("declared difference: %s: system %s, port %s", label, system == nil and "None" or system,
                                  mine == nil and "None" or mine))
            end
        elseif system ~= mine then
            out(string.format("UNDECLARED DIFFERENCE: %s: system %s, port %s", label, repr(system), repr(mine)))
            failures = failures + 1
        end
    end
    out(string.format("cases read: %d a side; declared differences: %d; undeclared or moved: %d", #labels, declared_count, failures))
    return failures > 0 and 1 or 0
end

function compare(host_file, port_file, expected_file)
    local lines = {}
    local function out(line)
        table.insert(lines, line)
    end
    local status
    stopped = nil
    try {
        function ()
            status = differences(host_file, port_file, expected_file, out)
        end,
        catch {
            function (errors)
                if not stopped then
                    raise(errors)
                end
                out(stopped)
                status = 1
            end
        }
    }
    return status, lines
end

function main(host_file, port_file, expected_file)
    if not host_file or not port_file or not expected_file then
        raise("usage: xmake l compare.lua <host.tsv> <port.tsv> <expected-differences.tsv>")
    end
    local status, lines = compare(host_file, port_file, expected_file)
    for _, line in ipairs(lines) do
        print(line)
    end
    if status ~= 0 then
        os.exit(status)
    end
end

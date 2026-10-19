local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})

local function after_last(text, separator)
    local at
    local from = 1
    while true do
        local found = text:find(separator, from, true)
        if not found then
            break
        end
        at, from = found, found + 1
    end
    if not at then
        return "", text
    end
    return text:sub(1, at - 1), text:sub(at + #separator)
end

function read(file)
    local seen = {present = {}, missing = {}, answered = {}, refused = {}, crashed = {}}
    local text = io.readfile(file, {encoding = "binary"}):gsub("\r\n", "\n"):gsub("\r", "\n")
    for _, line in ipairs(text:split("\n", {strict = true})) do
        if line:match("%S") then
            if line:startswith("present ") then
                seen.present[line:sub(9)] = true
            elseif line:startswith("missing ") then
                seen.missing[line:sub(9)] = (seen.missing[line:sub(9)] or 0) + 1
            elseif line:startswith("crashed ") then
                table.insert(seen.crashed, line:sub(9))
            elseif line:startswith("refused ") then
                local body = line:sub(9)
                local at = body:find(" raised ", 1, true)
                if at then
                    seen.refused[body:sub(1, at - 1)] = body:sub(at + 8)
                else
                    seen.refused[body] = ""
                end
            elseif line:startswith("answered ") then
                local head, value = after_last(line:sub(10), " -> ")
                seen.answered[head] = value
            end
        end
    end
    return seen
end

local function set_of(list)
    local set = {}
    for _, value in ipairs(list) do
        set[value] = true
    end
    return set
end

local function only_in(a, b)
    local out = {}
    for key in pairs(a) do
        if b[key] == nil then
            table.insert(out, key)
        end
    end
    byteorder.sort(out)
    return out
end

local function both(a, b)
    local out = {}
    for key in pairs(a) do
        if b[key] ~= nil then
            table.insert(out, key)
        end
    end
    byteorder.sort(out)
    return out
end

local function first(list, count)
    return table.concat(list, " ", 1, math.min(#list, count))
end

local function size(map)
    local count = 0
    for _ in pairs(map) do
        count = count + 1
    end
    return count
end

function compare(host_file, port_file, opt)
    opt = opt or {}
    local host, port = read(host_file), read(port_file)
    local lines = {}
    local function out(line)
        table.insert(lines, line)
    end
    out(string.format("classes: host %d, port %d", size(host.present), size(port.present)))
    local only_port = only_in(port.present, host.present)
    local only_host = only_in(host.present, port.present)
    if #only_port > 0 then
        out(string.format("  the port has %d the host does not: %s", #only_port, first(only_port, 12)))
    end
    if #only_host > 0 then
        out(string.format("  the host has %d the port does not: %s", #only_host, first(only_host, 12)))
    end
    local lost = only_in(host.answered, port.answered)
    local gained = only_in(port.answered, host.answered)
    out(string.format("members answered: host %d, port %d (the port has %d the host does not, and is missing %d)",
                      size(host.answered), size(port.answered), #gained, #lost))
    for _, name in ipairs(lost) do
        out("  LOST      " .. name)
    end
    for _, name in ipairs(gained) do
        out("  EXTRA     " .. name)
    end
    local port_crashes, host_crashes = set_of(port.crashed), set_of(host.crashed)
    local crashed_in_port = only_in(port_crashes, host_crashes)
    for _, name in ipairs(crashed_in_port) do
        out("  CRASHED   only in the port: " .. name)
    end
    for _, name in ipairs(only_in(host_crashes, port_crashes)) do
        out("  CRASHED   only on the host: " .. name)
    end
    local shared = both(host.answered, port.answered)
    local differing = {}
    for _, name in ipairs(shared) do
        if host.answered[name] ~= port.answered[name] then
            table.insert(differing, name)
        end
    end
    out(string.format("answers that differ: %d of %d members both answered", #differing, #shared))
    for index = 1, math.min(#differing, 40) do
        local name = differing[index]
        out(string.format("  %s\n      host: %s\n      port: %s", name, host.answered[name], port.answered[name]))
    end
    if #differing > 40 then
        out(string.format("  ... and %d more", #differing - 40))
    end
    local refused_port = only_in(port.refused, host.refused)
    local refused_host = only_in(host.refused, port.refused)
    out(string.format("refused the neutral value: host %d, port %d (only in the port %d, only on the host %d)",
                      size(host.refused), size(port.refused), #refused_port, #refused_host))
    for _, name in ipairs(refused_port) do
        out(string.format("  REFUSED   only in the port: %s (%s)", name, port.refused[name]))
    end
    for _, name in ipairs(refused_host) do
        out(string.format("  REFUSED   only on the host: %s (%s)", name, host.refused[name]))
    end
    local failed = #lost > 0 or #crashed_in_port > 0
    if opt.strict and (#differing > 0 or #gained > 0 or #only_port > 0 or #only_host > 0) then
        failed = true
    end
    return failed and 1 or 0, lines
end

function main(...)
    local files, strict = {}, false
    for _, argument in ipairs({...}) do
        if argument == "--strict" then
            strict = true
        else
            table.insert(files, argument)
        end
    end
    if #files ~= 2 then
        raise("usage: xmake l compare.lua <host.log> <port.log> [--strict]")
    end
    local status, lines = compare(files[1], files[2], {strict = strict})
    for _, line in ipairs(lines) do
        print(line)
    end
    if status ~= 0 then
        os.exit(status)
    end
end

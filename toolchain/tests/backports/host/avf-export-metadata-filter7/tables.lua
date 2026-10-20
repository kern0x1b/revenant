local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local BUILD_PREFIXES = {"CONTROL ", "release filter:", "rows"}
local SHARING = "sharing filter: metadata after the export"
local RELEASE = "release filter: sharing filter over the source"
local ALLOWANCES = {}
ALLOWANCES[SHARING] = "Apple's own session writes the kept items into the OUTPUT FILE and leaves `metadata` nil - measured "
    .. "here, on a real export of a real file. This release has no member that hands the file a list, so the "
    .. "port leaves the filtered items on the session and lets the release's own export write them. The value "
    .. "is not free: the row below asserts it is exactly the release's own filtered answer"

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function load(file)
    local rows = {}
    for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
        if line:trim() ~= "" then
            local at, stop = line:find(" | ", 1, true)
            if not at then
                print("MALFORMED       a line with no ' | ' in it: " .. line:trim())
            else
                rows[line:sub(1, at - 1):trim()] = line:sub(stop + 1):trim()
            end
        end
    end
    return rows
end

local function sorted_union(a, b)
    local seen, keys = {}, {}
    for key in pairs(a) do
        if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    for key in pairs(b) do
        if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    byteorder.sort(keys)
    return keys
end

local function is_build_row(key)
    for _, prefix in ipairs(BUILD_PREFIXES) do
        if key:startswith(prefix) then
            return true
        end
    end
    return false
end

local function join(build, oracle_dir)
    local host = load(path.join(build, "host.table"))
    local port = load(path.join(build, "port.table"))
    local port_only, host_only, unequal = 0, 0, 0
    local unexplained = {}
    for _, key in ipairs(sorted_union(host, port)) do
        if not is_build_row(key) then
            if port[key] == nil then
                print(string.format("HOST ONLY        %s", key))
                host_only = host_only + 1
            elseif host[key] == nil then
                print(string.format("PORT ONLY        %s", key))
                port_only = port_only + 1
            elseif host[key] ~= port[key] then
                unequal = unequal + 1
                if ALLOWANCES[key] then
                    print(string.format("ALLOWED          %-46s host=[%s] port=[%s]", key, host[key], port[key]))
                else
                    print(string.format("UNEXPLAINED      %-46s host=[%s] port=[%s]", key, host[key], port[key]))
                    table.insert(unexplained, key)
                end
            end
        end
    end
    local kept = port[SHARING]
    local release = port[RELEASE]
    if kept ~= release then
        print(string.format("UNEXPLAINED      the port left [%s] on the session and the release's own filter answers [%s] for the source's array", tostring(kept), tostring(release)))
        table.insert(unexplained, SHARING)
    end
    local host_count, port_count = 0, 0
    for _ in pairs(host) do
        host_count = host_count + 1
    end
    for _ in pairs(port) do
        port_count = port_count + 1
    end
    print(string.format("SUMMARY rows: host=%d port=%d  must-match-unequal=%d port-only=%d host-only=%d unexplained=%d",
        host_count, port_count, unequal, port_only, host_only, #unexplained))
    if port_only > 0 or host_only > 0 or #unexplained > 0 then
        os.exit(1)
    end
end

local function direction(build, oracle_dir)
    local base = load(path.join(oracle_dir, "port.baseline"))
    local port = load(path.join(build, "port.table"))
    local host = load(path.join(build, "host.table"))
    local changed, right_then_wrong = {}, {}
    for _, key in ipairs(sorted_union(base, port)) do
        if base[key] ~= port[key] then
            table.insert(changed, key)
            if host[key] ~= nil and base[key] == host[key] then
                table.insert(right_then_wrong, key)
            elseif key == SHARING and base[key] == base[RELEASE] then
                table.insert(right_then_wrong, key)
            end
        end
    end
    for _, key in ipairs(right_then_wrong) do
        print(string.format("BROKE A RIGHT ONE  %-46s was=[%s] now=[%s]", key, tostring(base[key]), tostring(port[key])))
    end
    for _, key in ipairs(changed) do
        print(string.format("CHANGED           %-46s before=[%s] after=[%s]", key, tostring(base[key]), tostring(port[key])))
    end
    print(string.format("DIRECTIONALITY changed=%d right-then-wrong=%d", #changed, #right_then_wrong))
    if #changed == 0 or #right_then_wrong == 0 then
        os.exit(1)
    end
end

function main(command, build, oracle_dir)
    if command == "join" then
        join(build, oracle_dir)
    elseif command == "direction" then
        direction(build, oracle_dir)
    else
        raise("usage: tables.lua join|direction <build> <oracle dir>")
    end
end

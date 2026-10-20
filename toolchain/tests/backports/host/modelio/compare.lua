local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local SKIPPED = {sanity = true, sweep = true, radial = true, second = true, dump = true, tri = true, verts = true, level = true}

local function number_at(line, p)
    local text = line:match("^%-?%d+", p)
    local q = p + #text
    local fraction = line:match("^%.%d+", q)
    if fraction then
        text = text .. fraction
        q = q + #fraction
    end
    local exponent = line:match("^[eE][%-+]?%d+", q)
    if exponent then
        text = text .. exponent
    end
    return text
end

local function split_key(line)
    local p = line:find("%-?%d")
    if not p then
        return nil
    end
    return line:sub(1, p - 1), number_at(line, p), line:sub(p)
end

local function numbers(text)
    local out = {}
    local pos = 1
    while true do
        local p = text:find("%-?%d", pos)
        if not p then
            break
        end
        local hit = number_at(text, p)
        table.insert(out, tonumber(hit) + 0.0)
        pos = p + #hit
    end
    return out
end

local function read(file)
    local records, index = {}, {}
    local seen = {}
    for line in pyish.lines_of(file) do
        if line:sub(-1) == "\r" then
            line = line:sub(1, -2)
        end
        local first = line:match("^([^ ]*)")
        if not SKIPPED[first] then
            local key, _, tail = split_key(line)
            if key == nil then
                key = line
                tail = nil
            end
            seen[key] = (seen[key] or 0) + 1
            local record = {key = key, count = seen[key], tail = tail, line = line}
            table.insert(records, record)
            index[key .. "\n" .. seen[key]] = record
        end
    end
    return records, index
end

function compare(host_path, port_path, tolerance, label)
    local host_records, host = read(host_path)
    local port_records, port = read(port_path)
    local same, different, only = 0, 0, 0
    local only_host, only_port = 0, 0
    for _, record in ipairs(host_records) do
        local composite = record.key .. "\n" .. record.count
        local other = port[composite]
        if other == nil then
            only = only + 1
            only_host = only_host + 1
            print("only the system answers: " .. record.line)
        else
            local agreed = false
            if record.tail == nil then
                agreed = record.line == other.line
            else
                local a = numbers(record.tail)
                local b = numbers(other.tail or "")
                if #a == #b then
                    agreed = true
                    for i = 1, #a do
                        if math.abs(a[i] - b[i]) > tolerance then
                            agreed = false
                            break
                        end
                    end
                end
            end
            if agreed then
                same = same + 1
            else
                different = different + 1
                print("different: " .. record.line)
                print("        the port: " .. other.line)
            end
        end
    end
    for _, record in ipairs(port_records) do
        local composite = record.key .. "\n" .. record.count
        if host[composite] == nil then
            only = only + 1
            only_port = only_port + 1
            print("only the port answers: " .. record.line)
        end
    end
    local total = #host_records
    if same + different + only_host ~= total then
        raise(string.format("the categories do not sum over the host: %d + %d + %d != %d", same, different, only_host, total), 0)
    end
    if only_host + only_port ~= only then
        raise(string.format("one-side-only does not split: %d + %d != %d", only_host, only_port, only), 0)
    end
    print(string.format("%s: %d host keys = %d the same + %d different + %d host-only; %d port-only, %d across both sides (tolerance %g)",
        label, total, same, different, only_host, only_port, total + only_port, tolerance))
    return different == 0 and 0 or 1
end

local function count(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

local function images(file)
    local out = {}
    for line in pyish.lines_of(file) do
        if line:sub(1, 6) == "image " then
            local parts = pyish.split(line)
            if #parts >= 4 then
                out[parts[2]] = out[parts[2]] or {}
                out[parts[2]][parts[4]] = true
            end
        end
    end
    return out
end

function check_images(host_err, port_err)
    local host, port = images(host_err), images(port_err)
    if count(host) == 0 or count(port) == 0 then
        print("FAIL  no image lines: the probe did not report which image answered")
        return 1
    end
    for _, cls in ipairs(pyish.sorted_keys(host)) do
        for kind in pairs(host[cls]) do
            if kind ~= "system-modelio" then
                print(string.format("FAIL  the host answered %s from %s, not from the system ModelIO", cls, kind))
                return 1
            end
        end
    end
    for _, cls in ipairs(pyish.sorted_keys(port)) do
        for kind in pairs(port[cls]) do
            if kind ~= "port" then
                print(string.format("FAIL  the port answered %s from %s - it does not link ModelIO", cls, kind))
                return 1
            end
        end
    end
    local common = 0
    for cls in pairs(host) do
        if port[cls] then
            common = common + 1
        end
    end
    print(string.format("  images: %d classes on both sides (%d host, %d port); host from the system ModelIO, port from its binary and band objects", common, count(host), count(port)))
    return 0
end

function main(command, ...)
    if command == "compare" then
        local host_path, port_path, tolerance, label = ...
        os.exit(compare(host_path, port_path, pyish.float(tolerance or "0.0"), label or "modelio"))
    elseif command == "images" then
        os.exit(check_images(...))
    end
    io.stderr:write("usage: compare.lua compare <host> <port> [tolerance] [label] | images <host-err> <port-err>\n")
    os.exit(2)
end

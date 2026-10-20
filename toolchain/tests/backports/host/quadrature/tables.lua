local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local TABLES = {
    {"x1", "dqng.f", "x1"},
    {"x2", "dqng.f", "x2"},
    {"x3", "dqng.f", "x3"},
    {"x4", "dqng.f", "x4"},
    {"w10", "dqng.f", "w10"},
    {"w21a", "dqng.f", "w21a"},
    {"w21b", "dqng.f", "w21b"},
    {"w43a", "dqng.f", "w43a"},
    {"w43b", "dqng.f", "w43b"},
    {"w87a", "dqng.f", "w87a"},
    {"w87b", "dqng.f", "w87b"},
    {"k15_wg", "dqk15.f", "wg"},
    {"k15_wgk", "dqk15.f", "wgk"},
    {"k15_xgk", "dqk15.f", "xgk"},
    {"k21_wg", "dqk21.f", "wg"},
    {"k21_wgk", "dqk21.f", "wgk"},
    {"k21_xgk", "dqk21.f", "xgk"},
    {"k31_wg", "dqk31.f", "wg"},
    {"k31_wgk", "dqk31.f", "wgk"},
    {"k31_xgk", "dqk31.f", "xgk"},
    {"k41_wg", "dqk41.f", "wg"},
    {"k41_wgk", "dqk41.f", "wgk"},
    {"k41_xgk", "dqk41.f", "xgk"},
    {"k51_wg", "dqk51.f", "wg"},
    {"k51_wgk", "dqk51.f", "wgk"},
    {"k51_xgk", "dqk51.f", "xgk"},
    {"k61_wg", "dqk61.f", "wg"},
    {"k61_wgk", "dqk61.f", "wgk"},
    {"k61_xgk", "dqk61.f", "xgk"},
}

local function literals(text)
    local out = {}
    local pos = 1
    while true do
        local s, e = text:find("%-?%d%.%d+", pos)
        if not s then
            break
        end
        local exponent = text:match("^e[%-+]?%d+", e + 1)
        if exponent then
            e = e + #exponent
        end
        table.insert(out, text:sub(s, e))
        pos = e + 1
    end
    return out
end

local function data_values(file)
    local values = {}
    local source = nil
    for line in pyish.lines_of(file) do
        if line:sub(1, 6) == "# --- " then
            source = pyish.strip(line:sub(7))
        end
        local arr, first, body = line:match("^%s*data%s+([%w_]+)%s*%(%s*(%d+)%s*%)%s*/(.*)/%s*$")
        if arr then
            arr = arr:lower()
            first = tonumber(first)
            local text = body:gsub("%s+", ""):gsub("[dDE]", "e")
            local key = source or ""
            values[key] = values[key] or {}
            local bucket = values[key][arr] or {}
            values[key][arr] = bucket
            local index = 0
            for _, lit in ipairs(literals(text)) do
                bucket[first + index] = tonumber(lit)
                index = index + 1
            end
        end
    end
    return values
end

local function table_of(values, source, arr)
    local bucket = values[source] and values[source][arr]
    if not bucket then
        raise(string.format("KeyError: %s %s", source, arr), 0)
    end
    local top = 0
    for k in pairs(bucket) do
        if k > top then
            top = k
        end
    end
    if top == 0 then
        raise("max() arg is an empty sequence", 0)
    end
    local out = {}
    for k = 1, top do
        if bucket[k] == nil then
            raise(string.format("KeyError: %d", k), 0)
        end
        out[k] = bucket[k]
    end
    return out
end

local function port_values(file)
    local text = io.readfile(file)
    local out = {}
    local pos = 1
    while true do
        local s, e, name = text:find("static const double ([%w_]+)%[%d+%] = {", pos)
        if not s then
            break
        end
        local close = text:find("};", e + 1, true)
        if not close then
            break
        end
        local numbers = {}
        for v in text:sub(e + 1, close - 1):gmatch("%-?%d%.%d+e[%-+]%d+") do
            table.insert(numbers, tonumber(v))
        end
        out[name] = numbers
        pos = close + 2
    end
    return out
end

function check(data, port)
    if not os.isfile(data) then
        print("missing " .. data)
        os.exit(2)
    end
    local source = data_values(data)
    if not os.isfile(port) then
        print("missing " .. port)
        os.exit(2)
    end
    local got_tables = port_values(port)
    local bad = 0
    local total = 0
    for _, entry in ipairs(TABLES) do
        local name, src_file, arr = entry[1], entry[2], entry[3]
        local want = table_of(source, src_file, arr)
        total = total + #want
        local got = got_tables[name]
        if got == nil then
            print(string.format("FAIL %s is not in %s", name, path.filename(port)))
            bad = bad + 1
        elseif #got ~= #want then
            print(string.format("FAIL %s holds %d values, %s %s has %d", name, #got, src_file, arr, #want))
            bad = bad + 1
        else
            for k = 1, #want do
                local g, w = got[k], want[k]
                if g ~= w then
                    local ratio = "nan"
                    if w ~= 0 then
                        ratio = string.format("%.17g", g / w)
                    end
                    print(string.format("FAIL %s[%d] is %.32e, %s %s(%d) is %.32e (ratio %s)", name, k - 1, g, src_file, arr, k, w, ratio))
                    bad = bad + 1
                end
            end
        end
    end
    if bad > 0 then
        print(string.format("%d of the %d tables differ from the DATA statements", bad, #TABLES))
        return 1
    end
    print(string.format("all %d tables hold the %d values their DATA statements give", #TABLES, total))
    return 0
end

function print_tables(data)
    if not os.isfile(data) then
        print("missing " .. data)
        return 2
    end
    local source = data_values(data)
    for _, entry in ipairs(TABLES) do
        local name, src_file, arr = entry[1], entry[2], entry[3]
        local values = table_of(source, src_file, arr)
        local body = {}
        for i = 1, #values, 3 do
            local row = {}
            for k = i, math.min(i + 2, #values) do
                table.insert(row, string.format("%.32e", values[k]))
            end
            table.insert(body, "    " .. table.concat(row, ", ") .. ",")
        end
        print(string.format("static const double %s[%d] = {", name, #values))
        print(table.concat(body, "\n"))
        print("};")
        print()
    end
    return 0
end

function main(command, ...)
    if command == "check" then
        os.exit(check(...))
    elseif command == "print" then
        os.exit(print_tables(...))
    end
    io.stderr:write("usage: tables.lua check <quadpack-data> <Quadrature10.m> | print <quadpack-data>\n")
    os.exit(2)
end

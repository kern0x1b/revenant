local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local WIDTHS = {float32 = 8, float16 = 4, int32 = 8}

local function integer_field(text, what)
    if not text:match("^[+-]?%d+$") then
        raise(string.format("%s is not an integer: '%s'", what, text), 0)
    end
    return tonumber(text)
end

local function read_all(file)
    local out = {}
    for line in pyish.lines_of(file) do
        table.insert(out, line)
    end
    return out
end

local function load_recorded(file)
    local recorded = {}
    local number = 0
    for line in pyish.lines_of(file) do
        number = number + 1
        if line:sub(1, 1) ~= "#" and pyish.strip(line) ~= "" then
            local f = pyish.split(line)
            if #f ~= 5 then
                print(string.format("recorded-cells.txt line %d is not five fields: %s", number, pyish.strip(line)))
                os.exit(1)
            end
            local index = integer_field(f[3], "recorded-cells.txt element")
            local key = string.format("%s %s %d", f[1], f[2], index)
            recorded[key] = {op = f[1], dtype = f[2], index = index, release = f[4], port = f[5]}
        end
    end
    return recorded
end

local function load_tolerances(file)
    local tolerances = {}
    local number = 0
    for line in pyish.lines_of(file) do
        number = number + 1
        if line:sub(1, 1) ~= "#" and pyish.strip(line) ~= "" then
            local f = pyish.split(line)
            if #f ~= 3 then
                print(string.format("tolerances.txt line %d is not three fields: %s", number, pyish.strip(line)))
                os.exit(1)
            end
            tolerances[f[1] .. " " .. f[2]] = integer_field(f[3], "tolerances.txt units")
        end
    end
    return tolerances
end

local function value_of(pattern)
    local reversed = {}
    for i = #pattern - 1, 1, -2 do
        table.insert(reversed, pattern:sub(i, i + 1))
    end
    return tonumber(table.concat(reversed), 16)
end

local function monotone(pattern)
    local bits = #pattern * 4
    local value = value_of(pattern)
    local sign = value >> (bits - 1)
    local magnitude = value & ((1 << (bits - 1)) - 1)
    if sign == 1 then
        return -magnitude
    end
    return magnitude
end

local function is_nan(pattern)
    local value = value_of(pattern)
    if #pattern == 4 then
        return (value & 0x7C00) == 0x7C00 and (value & 0x03FF) ~= 0
    end
    return (value & 0x7F800000) == 0x7F800000 and (value & 0x007FFFFF) ~= 0
end

local function is_zero(pattern)
    return (value_of(pattern) & ((1 << (#pattern * 4 - 1)) - 1)) == 0
end

local function distance(one, other)
    if is_nan(one) and is_nan(other) then
        return 0
    end
    if is_nan(one) or is_nan(other) then
        return nil
    end
    if is_zero(one) and is_zero(other) then
        return 0
    end
    return math.abs(monotone(one) - monotone(other))
end

local function ran_families(system_path)
    local ran = {}
    for line in pyish.lines_of(system_path) do
        local f = pyish.split(line)
        if #f >= 5 then
            ran[f[2] .. " " .. f[3]] = true
        end
    end
    return ran
end

local function sorted_recorded(recorded)
    local list = {}
    for _, entry in pairs(recorded) do
        table.insert(list, entry)
    end
    table.sort(list, function(a, b)
        if a.op ~= b.op then
            return a.op < b.op
        end
        if a.dtype ~= b.dtype then
            return a.dtype < b.dtype
        end
        return a.index < b.index
    end)
    return list
end

function compare(system_path, port_path, recorded_path, tolerances_path, family)
    local recorded = load_recorded(recorded_path)
    local tolerances = load_tolerances(tolerances_path)
    local ran = ran_families(system_path)
    local system_lines, port_lines = read_all(system_path), read_all(port_path)
    local hard, seen, differing = {}, {}, {}
    local checked, cells = 0, 0
    for i = 1, math.min(#system_lines, #port_lines) do
        local one, other = system_lines[i], port_lines[i]
        local a, b = pyish.split(one), pyish.split(other)
        if #a < 5 or #b < 5 or a[2] ~= b[2] then
            if one ~= other then
                table.insert(hard, table.concat(a, " "))
            end
        else
            checked = checked + 1
            local op, dtype = a[2], a[3]
            local width = WIDTHS[dtype] or (dtype:sub(1, 4) == "bool" and 2 or 8)
            local count = (integer_field(a[4], "case length") * 2) // width
            cells = cells + count
            local allowed = tolerances[op .. " " .. dtype] or 0
            for k = 0, count - 1 do
                local key = string.format("%s %s %d", op, dtype, k)
                local release = a[5]:sub(k * width + 1, (k + 1) * width)
                local mine = b[5]:sub(k * width + 1, (k + 1) * width)
                local listed = recorded[key]
                if release == mine then
                    if listed then
                        table.insert(hard, string.format("%s %s element %d is on recorded-cells.txt and the two now agree", op, dtype, k))
                    end
                else
                    local within = false
                    if allowed ~= 0 and (dtype == "float32" or dtype == "float16") then
                        local how_far = distance(release, mine)
                        if how_far and how_far <= allowed then
                            within = true
                        end
                    end
                    if not within then
                        differing[key] = true
                        if listed == nil then
                            table.insert(hard, string.format("%s %s element %d: release %s, port %s, and it is neither within %d ulp nor recorded", op, dtype, k, release, mine, allowed))
                        elseif listed.release ~= release or listed.port ~= mine then
                            table.insert(hard, string.format("%s %s element %d is recorded as release %s and port %s and answered %s and %s", op, dtype, k, listed.release, listed.port, release, mine))
                        else
                            seen[key] = true
                        end
                    end
                end
            end
        end
    end
    for _, entry in ipairs(sorted_recorded(recorded)) do
        local key = string.format("%s %s %d", entry.op, entry.dtype, entry.index)
        if ran[entry.op .. " " .. entry.dtype] and not differing[key] then
            table.insert(hard, string.format("%s %s element %d is recorded as release %s and port %s and the two now agree", entry.op, entry.dtype, entry.index, entry.release, entry.port))
        end
    end
    local nseen, ndiff = 0, 0
    for _ in pairs(seen) do
        nseen = nseen + 1
    end
    for _ in pairs(differing) do
        ndiff = ndiff + 1
    end
    print(string.format("%s: same as the system on %d of the %d cells with a result buffer; %d within the release's own precision, %d recorded", family, cells - nseen, cells, cells - nseen - ndiff, nseen))
    for _, name in ipairs(hard) do
        print("  DIFFERS: " .. name)
    end
    print(string.format("checks=%d failures=%d recorded=%d", checked, #hard, nseen))
    return #hard > 0 and 1 or 0
end

function main(command, ...)
    if command == "compare" then
        os.exit(compare(...))
    end
    io.stderr:write("usage: compare.lua compare <system> <port> <recorded> <tolerances> <family>\n")
    os.exit(2)
end

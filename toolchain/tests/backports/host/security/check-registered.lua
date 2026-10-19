local tsv = import("tsv", {rootdir = os.scriptdir()})

local NULL = {}

local function parse_json(text, path)
    local pos = 1

    local function fail(what)
        io.stderr:write("check-registered.lua: " .. path .. ": " .. what .. " at byte " .. pos .. "\n")
        os.exit(1)
    end

    local function skip()
        pos = text:find("[^ \t\r\n]", pos) or (#text + 1)
    end

    local simple_escapes = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}

    local value

    local function read_string()
        pos = pos + 1
        local parts = {}
        while true do
            local stop = text:find('["\\]', pos)
            if not stop then
                fail("unterminated string")
            end
            parts[#parts + 1] = text:sub(pos, stop - 1)
            if text:sub(stop, stop) == '"' then
                pos = stop + 1
                break
            end
            local escape = text:sub(stop + 1, stop + 1)
            pos = stop + 2
            if escape == "u" then
                local digits = text:sub(pos, pos + 3)
                if not digits:find("^%x%x%x%x$") then
                    fail("bad \\u escape")
                end
                local code = tonumber(digits, 16)
                pos = pos + 4
                if code >= 0xD800 and code <= 0xDBFF and text:sub(pos, pos + 1) == "\\u" then
                    local low_digits = text:sub(pos + 2, pos + 5)
                    local low = low_digits:find("^%x%x%x%x$") and tonumber(low_digits, 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        pos = pos + 6
                    end
                end
                parts[#parts + 1] = utf8.char(code)
            else
                local decoded = simple_escapes[escape]
                if not decoded then
                    fail("bad escape")
                end
                parts[#parts + 1] = decoded
            end
        end
        return table.concat(parts)
    end

    local function read_number()
        local lexeme = text:match("^-?%d+", pos)
        if not lexeme then
            fail("bad value")
        end
        local at = pos + #lexeme
        local fraction = text:match("^%.%d+", at) or ""
        at = at + #fraction
        local exponent = text:match("^[eE][%+%-]?%d+", at) or ""
        at = at + #exponent
        pos = at
        return tonumber(lexeme .. fraction .. exponent)
    end

    local function read_array()
        pos = pos + 1
        local items = {}
        skip()
        if text:sub(pos, pos) == "]" then
            pos = pos + 1
            return {array = true, items = items}
        end
        while true do
            skip()
            items[#items + 1] = value()
            skip()
            local separator = text:sub(pos, pos)
            pos = pos + 1
            if separator == "]" then
                return {array = true, items = items}
            elseif separator ~= "," then
                fail("expected , or ]")
            end
        end
    end

    local function read_object()
        pos = pos + 1
        local fields = {}
        skip()
        if text:sub(pos, pos) == "}" then
            pos = pos + 1
            return {object = true, fields = fields}
        end
        while true do
            skip()
            if text:sub(pos, pos) ~= '"' then
                fail("expected a key")
            end
            local key = read_string()
            skip()
            if text:sub(pos, pos) ~= ":" then
                fail("expected :")
            end
            pos = pos + 1
            skip()
            fields[key] = value()
            skip()
            local separator = text:sub(pos, pos)
            pos = pos + 1
            if separator == "}" then
                return {object = true, fields = fields}
            elseif separator ~= "," then
                fail("expected , or }")
            end
        end
    end

    value = function()
        local first = text:sub(pos, pos)
        if first == "{" then
            return read_object()
        elseif first == "[" then
            return read_array()
        elseif first == '"' then
            return read_string()
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return NULL
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        return read_number()
    end

    local data = value()
    skip()
    if pos <= #text then
        fail("data after the value")
    end
    return data
end

local function is_dict(v)
    return type(v) == "table" and v.object == true
end

local function get(row, key)
    local v = row.fields[key]
    if v == nil then
        return NULL
    end
    return v
end

local function truthy(v)
    if v == NULL or v == false then
        return false
    end
    if type(v) == "string" then
        return #v > 0
    elseif type(v) == "number" then
        return v ~= 0
    elseif type(v) == "table" then
        if v.array then
            return #v.items > 0
        end
        for _ in pairs(v.fields) do
            return true
        end
        return false
    end
    return true
end

local function repr(v)
    if v == NULL then
        return "None"
    elseif v == true then
        return "True"
    elseif v == false then
        return "False"
    elseif type(v) == "string" then
        return tsv.py_repr(v)
    end
    return tostring(v)
end

local function has_prefix(s, prefix)
    return s:sub(1, #prefix) == prefix
end

local here = os.scriptdir()
local worktree = here .. "/../../../.."
local objects = worktree .. "/packages/a/apple-backports/Security"
local registry = worktree .. "/packages/a/apple-backports/registry/Security"

local function names()
    local out = {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(here .. "/algorithms.txt"))) do
        local s = tsv.strip(line)
        if s ~= "" then
            out[#out + 1] = s
        end
    end
    table.sort(out, tsv.byte_less)
    return out
end

local function defined()
    local found, count = {}, 0
    local paths = os.files(objects .. "/SecurityConstants*.m")
    table.sort(paths, tsv.byte_less)
    for _, path in ipairs(paths) do
        for _, line in ipairs(tsv.text_lines(tsv.read_text(path))) do
            local name = line:match("^const CFStringRef ([%w_]+) = CFSTR")
            if name and not found[name] then
                found[name] = true
                count = count + 1
            end
        end
    end
    return found, count
end

local function recorded_rows(files)
    local out, count = {}, 0
    for _, entries in ipairs(files) do
        for _, row in ipairs(entries) do
            if is_dict(row) and get(row, "kind") == "constant" then
                local api = row.fields["api"]
                if type(api) ~= "string" then
                    io.stderr:write("check-registered.lua: a constant row has no string api\n")
                    os.exit(1)
                end
                if out[api] == nil then
                    count = count + 1
                end
                out[api] = row
            end
        end
    end
    return out, count
end

local function load_registry()
    local files = {}
    local paths = os.files(registry .. "/*.json")
    table.sort(paths, tsv.byte_less)
    for _, path in ipairs(paths) do
        local data = parse_json(tsv.read_text(path), path)
        local entries
        if type(data) == "table" and data.array then
            entries = data.items
        elseif is_dict(data) then
            local listed = data.fields["entries"]
            if listed == nil then
                entries = {}
            elseif type(listed) == "table" and listed.array then
                entries = listed.items
            else
                io.stderr:write("check-registered.lua: " .. path .. ": entries is not a list\n")
                os.exit(1)
            end
        else
            io.stderr:write("check-registered.lua: " .. path .. ": not a list or an object\n")
            os.exit(1)
        end
        files[#files + 1] = entries
    end
    return files
end

local function check(files)
    local wanted_list = names()
    local wanted, wanted_count = {}, 0
    for _, name in ipairs(wanted_list) do
        if not wanted[name] then
            wanted[name] = true
            wanted_count = wanted_count + 1
        end
    end
    local built, built_count = defined()
    local recorded, recorded_count = recorded_rows(files)

    local unique = {}
    for name in pairs(wanted) do
        unique[#unique + 1] = name
    end
    table.sort(unique, tsv.byte_less)

    local problems = {}
    for _, name in ipairs(unique) do
        if not built[name] then
            problems[#problems + 1] = name .. " is in the list and no object defines it"
        end
        local row = recorded[name]
        if row == nil then
            problems[#problems + 1] = name .. " is in the list and has no registry row"
        else
            local status = get(row, "status")
            if status ~= "implemented" then
                problems[#problems + 1] = name .. " has a row whose status is " .. repr(status) .. ", not implemented"
            end
        end
    end
    local both = {}
    for _, name in ipairs(unique) do
        if built[name] then
            both[#both + 1] = name
        end
    end
    for _, name in ipairs(both) do
        local row = recorded[name]
        if row == nil then
            problems[#problems + 1] = name .. " has a row with no facts path"
            problems[#problems + 1] = name .. " has a row with no source"
        else
            if not truthy(get(row, "facts")) then
                problems[#problems + 1] = name .. " has a row with no facts path"
            end
            if not truthy(get(row, "source")) then
                problems[#problems + 1] = name .. " has a row with no source"
            end
        end
    end
    print(wanted_count .. " in the list, " .. built_count .. " defined, " .. recorded_count .. " rows of kind constant")
    return problems
end

local function control(files)
    local before = check(files)
    if #before > 0 then
        print("CONTROL cannot start: the copy is red before the removal: " .. before[1])
        return 1
    end
    local listed = names()
    if #listed == 0 then
        io.stderr:write("check-registered.lua: the names list is empty, so there is no constant to remove\n")
        os.exit(1)
    end
    local victim = listed[1]
    local changed = {}
    for i, entries in ipairs(files) do
        changed[i] = entries
    end
    for i, entries in ipairs(files) do
        local kept = {}
        for _, row in ipairs(entries) do
            if not is_dict(row) then
                io.stderr:write("check-registered.lua: a registry row is not an object\n")
                os.exit(1)
            end
            if row.fields["api"] ~= victim then
                kept[#kept + 1] = row
            end
        end
        if #kept ~= #entries then
            changed[i] = kept
            break
        end
    end
    local after = check(changed)
    local named = nil
    for _, problem in ipairs(after) do
        if has_prefix(problem, victim .. " ") then
            named = problem
            break
        end
    end
    print("CONTROL removed the row for " .. victim .. ": " .. (named or "NOT CAUGHT"))
    return named and 0 or 1
end

function main(...)
    local args = {...}
    local files = load_registry()
    local status = 0
    for _, problem in ipairs(check(files)) do
        print("FAIL " .. problem)
        status = 1
    end
    for _, a in ipairs(args) do
        if a == "--control" then
            if status == 0 then
                status = control(files)
            end
        end
    end
    print("check-registered: " .. (status ~= 0 and "RED" or "OK"))
    os.exit(status)
end

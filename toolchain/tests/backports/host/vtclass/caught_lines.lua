local V = import("vtlib", {rootdir = os.scriptdir()})
local R = import("records_json", {rootdir = os.scriptdir()})

local function none_if_null(value)
    if value == false then
        return nil
    end
    return value
end

local function py_repr(value)
    if value == nil then
        return "None"
    end
    local quote = "'"
    if value:find("'", 1, true) and not value:find('"', 1, true) then
        quote = '"'
    end
    local out = {}
    for i = 1, #value do
        local ch = value:sub(i, i)
        local byte = string.byte(ch)
        if ch == "\\" then
            out[#out + 1] = "\\\\"
        elseif ch == quote then
            out[#out + 1] = "\\" .. ch
        elseif ch == "\n" then
            out[#out + 1] = "\\n"
        elseif ch == "\r" then
            out[#out + 1] = "\\r"
        elseif ch == "\t" then
            out[#out + 1] = "\\t"
        elseif byte < 32 or byte == 127 then
            out[#out + 1] = string.format("\\x%02x", byte)
        else
            out[#out + 1] = ch
        end
    end
    return quote .. table.concat(out) .. quote
end

local function read_or_fail(path)
    if not os.isfile(path) then
        V.fail("caught_lines.lua: " .. path .. " is not there, so the mutant wrote no records")
    end
    local map
    try {
        function()
            map = R.read_object(path)
        end,
        catch {
            function(err)
                V.fail("caught_lines.lua: " .. path .. " is not JSON: " .. tostring(err))
            end
        }
    }
    return map
end

function main(base_path, mutant_path)
    local before = read_or_fail(base_path)
    local after = read_or_fail(mutant_path)
    local seen = {}
    for key in pairs(before) do
        seen[key] = true
    end
    for key in pairs(after) do
        seen[key] = true
    end
    for _, key in ipairs(V.sorted_keys(seen)) do
        local a = none_if_null(before[key])
        local b = none_if_null(after[key])
        if a ~= b then
            print(string.format("  caught: %-58s %s -> %s", key, py_repr(a), py_repr(b)))
        end
    end
end

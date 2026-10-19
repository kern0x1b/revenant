-- caught_lines.lua PORT.json MUTANT.json - the "caught:" lines run.sh prints after a mutation whose records changed.
-- It is run.sh's inline python3 -c block, ported line for line. For every key of either file, in byte order, whose
-- value differs (a key that is missing and a key whose value is JSON null both read as None, so they are equal), it
-- prints  "  caught: %-58s %r -> %r"  with the two values in Python's repr. A file that is missing, or is not JSON,
-- ends the run with exit 1, as the Python's uncaught exception did.

local V = import("vtlib", {rootdir = os.scriptdir()})
local R = import("records_json", {rootdir = os.scriptdir()})

-- records_json stores JSON null as false; Python's dict.get on a missing key and on a null both give None.
local function none_if_null(value)
    if value == false then
        return nil
    end
    return value
end

-- Python's repr of a str, or of None. The values are ASCII record values; a quote is chosen as Python does.
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

-- Reads one records file. A missing file or a file that is not JSON is the Python's uncaught exception: exit 1.
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

-- check_records.lua RECORDS.json - refuse a record that does not look like one, before it is written over the expectations a device
-- test reads.
--
--    xmake l ./check_records.lua <records.json>
--
-- A recorder that writes its expectations on every run must not write a run that did not answer: the smallapis2 appearance cases
-- need the windowed host's run loop to have run before the colours are read, and a run that starts too early records "none" or an
-- all-zero colour where the answer is a colour. That is not an answer changing; it is a run that did not get to ask.
--
-- A record is refused when a case's answer is one of the values that means "not asked": empty, "nil" or "null". A colour that is
-- absent records "none", which is an answer and is left alone. Exits 0 when every case looks answered, printing "records: N", and
-- 1 otherwise, saying which.

import("core.base.json")

-- The values that mean a run never asked. A leaf with no colour set has none, and that is an answer -- "none" for a colour is a
-- real answer and is not in this set. What is refused is a record with no entries at all, or one whose value is empty, which is
-- a run that stopped before the case.
local NOT_ANSWERED = { [""] = true, ["nil"] = true, ["(nil)"] = true, ["null"] = true }

-- Names are sorted by their bytes, as Python sorts strings; the string comparison of Lua follows the locale's collation.
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

-- Python's str.strip(): the whitespace is taken off both ends.
local function strip(text)
    return (text:gsub("^[ \t\n\r\f\v]+", ""):gsub("[ \t\n\r\f\v]+$", ""))
end

-- Whether a table has any key at all. xmake Lua has no next().
local function has_entries(t)
    for _ in pairs(t) do
        return true
    end
    return false
end

function main(...)
    local args = { ... }
    local path = args[1]
    local handle = assert(io.open(path, "rb"))
    local records = json.decode(handle:read("a"))
    handle:close()
    -- a JSON object is a table with string keys; an array has its items at 1, 2, ...
    local is_object = type(records) == "table" and records[1] == nil and has_entries(records)
    if not is_object then
        print(path .. ": no records at all")
        os.exit(1)
    end

    local count, refused = 0, {}
    for name, value in pairs(records) do
        count = count + 1
        -- only a string can be one of the words; a number, a boolean or null never is
        if type(value) == "string" and NOT_ANSWERED[strip(value)] then
            refused[#refused + 1] = name
        end
    end
    if #refused > 0 then
        table.sort(refused, byte_less)
        local shown = {}
        for i = 1, math.min(6, #refused) do
            shown[#shown + 1] = refused[i]
        end
        print(string.format("%s: %d case(s) did not answer: %s", path, #refused, table.concat(shown, ", ")))
        os.exit(1)
    end
    print("records: " .. count)
end

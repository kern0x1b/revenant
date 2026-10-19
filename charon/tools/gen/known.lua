-- The known differences of the whole-SDK verify: the committed table tools/gen/verify-known.tsv, one row per difference the verify
-- measures and cannot remove, each row a key, the count measured for it, and its cause (tab-separated; a # line is a comment). A row
-- explains a measured difference only at its own count: a key the run measures at another count is unexplained, and a row the run
-- does not measure at all is stale. Both fail the verify, so the table cannot hide a change. Keys are written by verify.lua:
-- "headers <framework> <cause>" and "swift <module> <item>". Pure Lua: no SDK, no clang.

-- The rows of the table's text, keyed by their key: {count = n, cause = text}. Returns the rows and, when the text is malformed (a line
-- that is not key, count and cause, or a key named twice), the number of that line.
function parse(text)
    local rows, malformed, number = {}, nil, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        number = number + 1
        if line ~= "" and string.sub(line, 1, 1) ~= "#" and malformed == nil then
            local key, count, cause = string.match(line, "^([^\t]+)\t(%d+)\t(.+)$")
            if key == nil or rows[key] ~= nil then
                malformed = number
            else
                rows[key] = {count = tonumber(count), cause = cause}
            end
        end
    end
    return rows, malformed
end

-- The problems of one run: each measured key no row explains at its count, and each row the run does not measure. measured maps a key
-- to its count (above zero). Returns the lines to print, in key order; an empty list is a run every difference of which is known.
function problems(measured, rows)
    local keys = {}
    for key in pairs(measured) do keys[#keys + 1] = key end
    for key in pairs(rows) do
        if measured[key] == nil then keys[#keys + 1] = key end
    end
    table.sort(keys)
    local lines = {}
    for _, key in ipairs(keys) do
        local count, row = measured[key], rows[key]
        if count == nil then
            lines[#lines + 1] = string.format("stale row, not measured: %s (the table says %d: %s)", key, row.count, row.cause)
        elseif row == nil then
            lines[#lines + 1] = string.format("unexplained: %s, %d (no row in the table)", key, count)
        elseif row.count ~= count then
            lines[#lines + 1] = string.format("unexplained: %s, %d (the table says %d: %s)", key, count, row.count, row.cause)
        end
    end
    return lines
end

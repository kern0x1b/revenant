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

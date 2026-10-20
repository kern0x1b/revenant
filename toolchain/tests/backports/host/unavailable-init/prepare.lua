local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function fields_of(line)
    local out, at = {}, 1
    while true do
        local tab = line:find("\t", at, true)
        if not tab then
            table.insert(out, line:sub(at))
            return out
        end
        table.insert(out, line:sub(at, tab - 1))
        at = tab + 1
    end
end

local function rows_of(file)
    local header, rows = nil, {}
    for _, line in ipairs(lines_of(io.readfile(file, {encoding = "binary"}))) do
        if not line:startswith("#") and line:trim() ~= "" then
            local fields = fields_of(line)
            if header == nil then
                header = fields
            else
                local row = {}
                for index, name in ipairs(header) do
                    row[name] = fields[index]
                end
                table.insert(rows, row)
            end
        end
    end
    return rows
end

local function unique_in_order(rows, column)
    local seen, values = {}, {}
    for _, row in ipairs(rows) do
        if not seen[row[column]] then
            seen[row[column]] = true
            table.insert(values, row[column])
        end
    end
    return values
end

function main(table_file, outdir, ...)
    local asked = {...}
    local rows = rows_of(table_file)
    local names = asked
    if #names == 0 then
        local seen = {}
        for _, row in ipairs(rows) do
            if not seen[row.framework] then
                seen[row.framework] = true
                table.insert(names, row.framework)
            end
        end
        table.sort(names)
    end
    for _, name in ipairs(names) do
        local mine = {}
        for _, row in ipairs(rows) do
            if row.framework == name then
                table.insert(mine, row)
            end
        end
        if #mine > 0 then
            for _, pair in ipairs({{"class", "classes"}, {"port-source", "sources"}, {"port-object", "objects"}}) do
                local values = unique_in_order(mine, pair[1])
                local out = {}
                for _, value in ipairs(values) do
                    table.insert(out, value .. "\n")
                end
                io.writefile(path.join(outdir, name .. "." .. pair[2]), table.concat(out), {encoding = "binary"})
            end
        end
    end
    local listed = {}
    for _, name in ipairs(names) do
        if os.isfile(path.join(outdir, name .. ".classes")) then
            table.insert(listed, name .. "\n")
        end
    end
    io.writefile(path.join(outdir, "frameworks"), table.concat(listed), {encoding = "binary"})
end

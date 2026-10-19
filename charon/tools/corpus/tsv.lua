function split(line)
    local fields, start = {}, 1
    while true do
        local tab = line:find("\t", start, true)
        if not tab then
            table.insert(fields, line:sub(start))
            return fields
        end
        table.insert(fields, line:sub(start, tab - 1))
        start = tab + 1
    end
end

function body(file)
    local rows, header = {}, true
    for line in io.lines(file) do
        if header then
            header = false
        else
            table.insert(rows, split(line))
        end
    end
    return rows
end

function keyed(rows, column)
    local map, order = {}, {}
    for _, row in ipairs(rows) do
        local key = row[column]
        if key == nil then
            raise("tsv: a row has no column %d", column)
        end
        if map[key] == nil then
            table.insert(order, key)
        end
        map[key] = row
    end
    return map, order
end

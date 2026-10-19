-- Tab-separated files as the corpus tools read them. Fields are split on tabs and empty fields are kept;
-- the lists are 1-based (Python's field k is entry k+1). None of the corpus TSVs carry quoting, so a plain
-- split reads them the way Python's csv module with a tab delimiter does.

-- The fields of one line.
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

-- The fields of every line of a file after its first (the header).
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

-- The rows keyed by one column, as a dict built from them is: a key keeps the position of its first row
-- and takes the value of its last. Returns the map and the keys in that order.
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

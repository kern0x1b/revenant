function lines(text)
    local out, pos = {}, 1
    while pos <= #text do
        local newline = string.find(text, "\n", pos, true)
        if not newline then
            table.insert(out, string.sub(text, pos))
            break
        end
        table.insert(out, string.sub(text, pos, newline - 1))
        pos = newline + 1
    end
    return out
end

function fields(line)
    local out, pos = {}, 1
    while true do
        local tab = string.find(line, "\t", pos, true)
        if not tab then
            table.insert(out, string.sub(line, pos))
            return out
        end
        table.insert(out, string.sub(line, pos, tab - 1))
        pos = tab + 1
    end
end

function records(text)
    local all = lines(text)
    local header = fields(all[1] or "")
    local out = {}
    for i = 2, #all do
        if all[i] ~= "" then
            local values = fields(all[i])
            local row = {}
            for column, name in ipairs(header) do
                row[name] = values[column]
            end
            table.insert(out, row)
        end
    end
    return out
end

function table_text(columns, rows)
    local out = {table.concat(columns, "\t")}
    for _, row in ipairs(rows) do
        table.insert(out, table.concat(row, "\t"))
    end
    return table.concat(out, "\n") .. "\n"
end

local COL = {framework = 1, kind = 2, usr = 3, type = 11, value = 14}

function read(filepath)
    local text = io.readfile(filepath)
    assert(text, "port values: cannot read " .. filepath)
    local run = {values = {}, types = {}, unparsed = {}}
    for line in string.gmatch(text, "[^\n]+") do
        if string.sub(line, 1, 1) ~= "#" then
            local kind, framework, usr, value = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
            assert(kind, "port values: a line is not four cells: " .. line)
            if kind == "unparsed" then
                run.unparsed[framework] = value
            elseif kind == "enumconst" then
                local seen = run.values[usr]
                assert(seen == nil or seen == value, "port values: " .. usr .. " has two values in the run: " .. tostring(seen) .. ", " .. value)
                run.values[usr] = value
            elseif kind == "enumtype" then
                run.types[usr] = value
            else
                error("port values: an unknown kind " .. kind)
            end
        end
    end
    return run
end

function apply(rows, run)
    local changed, absent, unparsed, types = 0, 0, 0, 0
    for _, row in ipairs(rows) do
        local fixed = run.types[row[COL.usr]]
        if row[COL.kind] == "enum" and fixed ~= nil and row[COL.type] ~= "-" and fixed ~= row[COL.type] then
            row[COL.type] = fixed
            types = types + 1
        end
        if row[COL.kind] == "enumconst" and row[COL.value] ~= "-" then
            local value = run.values[row[COL.usr]]
            if value == nil then
                absent = absent + 1
                if run.unparsed[row[COL.framework]] ~= nil then unparsed = unparsed + 1 end
            elseif value ~= row[COL.value] then
                row[COL.value] = value
                changed = changed + 1
            end
        end
    end
    return changed, absent, unparsed, types
end

local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local COLUMNS = 3
local OURS = 4

local function convert(file)
    local rows, keys = {}, {}
    for number, line in ipairs(text.lines(io.readfile(file))) do
        if text.strip(line) ~= "" then
            local parts = text.split(line, "\t")
            local row = nil
            if #parts == OURS then
                row = {parts[1], parts[2], parts[3]}
            elseif #parts == COLUMNS then
                row = parts
            else
                io.stderr:write(string.format(
                    "%s: line %d has %d columns, the %d ours.lua writes or the %d surf-diff reads. Refusing.\n",
                    file, number, #parts, OURS, COLUMNS))
                os.exit(1)
            end
            local key = text.join("\t", row)
            if not keys[key] then
                keys[key] = row
                rows[#rows + 1] = row
            end
        end
    end
    table.sort(rows, function(a, b)
        for i = 1, COLUMNS do
            if a[i] ~= b[i] then
                return a[i] < b[i]
            end
        end
        return false
    end)
    return rows
end

function main(...)
    local args = {...}
    if #args ~= 1 then
        io.stderr:write("usage: ours3.lua ours.tsv > ours-3.tsv\n")
        os.exit(2)
    end
    local rows = convert(args[1])
    for _, row in ipairs(rows) do
        print(text.join("\t", row))
    end
    io.stderr:write(string.format("# %d rows of three columns from %s\n", #rows, args[1]))
end

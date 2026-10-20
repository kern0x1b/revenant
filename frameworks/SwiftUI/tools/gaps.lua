local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local function surface(file)
    local rows = {}
    for _, line in ipairs(text.lines(io.readfile(file))) do
        local parts = text.split(line, "\t")
        if #parts == 3 then
            rows[#rows + 1] = {owner = parts[1], kind = parts[2], api = parts[3]}
        end
    end
    return rows
end

local function ours(file)
    local declared = {}
    for number, line in ipairs(text.lines(io.readfile(file))) do
        local parts = text.split(line, "\t")
        if #parts ~= 4 then
            io.stderr:write(string.format("%s: line %d has %d columns, want 4 (owner, kind, name, file)\n",
                file, number, #parts))
            os.exit(1)
        end
        local owner, kind, name = parts[1], parts[2], parts[3]
        declared[owner] = declared[owner] or {}
        declared[owner][kind] = declared[owner][kind] or {}
        declared[owner][kind][name] = true
        declared[""] = declared[""] or {}
        declared[""][kind] = declared[""][kind] or {}
        declared[""][kind][name] = true
    end
    return declared
end

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local args = {...}
    local ours_path = args[1] or path.join(tree.run("surface"), "ours-source.tsv")
    local surface_path = args[2] or path.join(tree.run("surface"), "surface-26.2.tsv")
    local negative_name = args[3] or "TextEditorStyle"

    local apple = surface(surface_path)
    local declared = ours(ours_path)
    local gaps = {}
    for _, row in ipairs(apple) do
        local names = declared[row.owner] or {}
        local base = text.partition(row.api, "(")
        local found
        if row.kind == "type" or row.kind == "init" or row.kind == "subscript" then
            found = names[row.kind] ~= nil
        else
            found = (names["var"] or {})[base] or (names["func"] or {})[base] or (names["const"] or {})[base]
        end
        if not found then
            gaps[#gaps + 1] = row.owner .. "#" .. base
        end
    end
    io.stderr:write(string.format("# %d rows of the 26.2 surface that this tree declares no name for\n", #gaps))
    for _, row in ipairs(gaps) do
        print(row)
    end
    local kept = 0
    for _, row in ipairs(gaps) do
        if text.startswith(row, negative_name .. "#") then
            kept = kept + 1
        end
    end
    if kept == 0 then
        io.stderr:write(string.format("# FAIL the negative case is gone: nothing starting %s# is reported\n",
            negative_name))
        os.exit(1)
    end
    io.stderr:write(string.format("# the negative case is kept: %d row(s) of %s\n", kept, negative_name))
end

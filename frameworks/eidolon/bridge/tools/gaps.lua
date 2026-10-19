-- gaps.lua: the rows of the 26.2 surface that ours.lua finds no declaration for.
--
--     xmake l gaps.lua [ours.tsv] [surface.tsv] [NAME]
--
-- A row is `Type#member`. An enum's case counts as declared, and so does a type we only alias - both because the
-- declaration is there, whichever way it is written. A type we genuinely lack stays on the list, and the tool is
-- checked against one: a name that is in Apple's surface and in no source of ours.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

-- the lines of a file as Python's iteration gives them: a final newline ends the last line and adds none
local function lines_of(content)
    local lines = text.split(content, "\n")
    if lines[#lines] == "" then
        lines[#lines] = nil
    end
    return lines
end

-- surf.lua writes three columns and no header: owner, kind, the declaration as text. Other shapes are skipped.
local function surface(file)
    local rows = {}
    for _, line in ipairs(lines_of(io.readfile(file))) do
        local parts = text.split(line, "\t")
        if #parts == 3 then
            rows[#rows + 1] = {owner = parts[1], kind = parts[2], api = parts[3]}
        end
    end
    return rows
end

-- ours.lua writes four columns; any other shape is an error, as the Python's unpacking was
local function ours(file)
    local declared = {}
    for number, line in ipairs(lines_of(io.readfile(file))) do
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
        -- a type declared at file scope names itself
        declared[""] = declared[""] or {}
        declared[""][kind] = declared[""][kind] or {}
        declared[""][kind][name] = true
    end
    return declared
end

function main(...)
    local root = path.join(os.scriptdir(), "..", "..")
    local args = {...}
    local ours_path = args[1] or path.join(root, ".agent-work", "runs", "ours-source.tsv")
    local surface_path = args[2] or path.join(root, ".agent-work", "runs", "surface-26.2.tsv")
    local negative_name = args[3] or "TextEditorStyle"

    local apple = surface(surface_path)
    local declared = ours(ours_path)
    local gaps = {}
    for _, row in ipairs(apple) do
        local names = declared[row.owner] or {}
        local base = text.partition(row.api, "(")
        local found
        if row.kind == "type" or row.kind == "init" or row.kind == "subscript" then
            -- as written: the owner has some declaration of this kind. The name is not looked up.
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
    -- the negative: a name Apple's surface carries and no source of ours has must stay on the list
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

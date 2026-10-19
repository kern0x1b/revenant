-- The C function rows of a framework's snapshot (functions.tsv), keyed as the oracle keys them: the api followed by "()".

local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

-- "api()" -> the row of the function; {} when the snapshot holds no functions file. A repeated api keeps its last row.
function load(tree, fw)
    local out = {}
    local text = files.read_text(path.join(layout.snap_dir(tree, fw), "functions.tsv"))
    if text == nil then
        return out
    end
    for _, row in ipairs(tsv.records(text)) do
        out[row.api .. "()"] = row
    end
    return out
end

local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

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

local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

function list_path(tree)
    return path.join(tree, "tools", "found", "unparsed.tsv")
end

function parse(text)
    local out = {}
    for _, line in ipairs(tsv.lines(text)) do
        if line ~= "" and string.sub(line, 1, 1) ~= "#" then
            local cells = tsv.fields(line)
            out[cells[1]] = cells[3] or ""
        end
    end
    return out
end

function skipped(tree)
    local text = files.read_text(list_path(tree))
    assert(text, "no extractor list of skipped frameworks at " .. list_path(tree))
    return parse(text)
end

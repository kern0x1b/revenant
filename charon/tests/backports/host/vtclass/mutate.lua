local V = import("vtlib", {rootdir = os.scriptdir()})

local function count_occurrences(text, sub)
    if sub == "" then
        local chars = utf8.len(text)
        return chars + 1
    end
    local count, start = 0, 1
    while true do
        local s, e = string.find(text, sub, start, true)
        if not s then
            break
        end
        count = count + 1
        start = e + 1
    end
    return count
end

function main(path, from, to)
    if from == nil or to == nil then
        V.fail("mutate.lua: usage: mutate.lua PATH FROM TO")
    end
    local text
    try {
        function()
            text = V.read_text(path)
        end,
        catch {
            function(err)
                V.fail("mutate.lua: cannot read " .. path .. ": " .. tostring(err))
            end
        }
    }
    if utf8.len(text) == nil then
        V.fail("mutate.lua: " .. path .. " is not UTF-8, so Python's text read would have failed")
    end
    local count = count_occurrences(text, from)
    if count ~= 1 then
        V.fail(string.format("mutate.lua: %s appears %d times in %s, so the mutation would not be a mutation",
            V.py_repr(from), count, path))
    end
    local start, stop = string.find(text, from, 1, true)
    local mutated = string.sub(text, 1, start - 1) .. to .. string.sub(text, stop + 1)
    V.write_file(path, mutated)
end

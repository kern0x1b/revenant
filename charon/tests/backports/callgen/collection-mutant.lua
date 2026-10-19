local NEEDLE = "    return results;\n}"
local REPLACEMENT = "    if (results.count > 1) {\n"
                 .. "        [results removeLastObject];\n"
                 .. "    }\n"
                 .. "    return results;\n}"

function mutated(text)
    local pieces, at, found = {}, 1, 0
    while true do
        local first, last = text:find(NEEDLE, at, true)
        if not first then
            break
        end
        table.insert(pieces, text:sub(at, first - 1))
        table.insert(pieces, REPLACEMENT)
        at = last + 1
        found = found + 1
    end
    if found == 0 then
        raise("the mutation did not apply: the generated body has no 'return results;\\n}'")
    end
    table.insert(pieces, text:sub(at))
    return table.concat(pieces)
end

function main(source, out)
    if not source or not out then
        raise("usage: xmake l collection-mutant.lua <source> <out>")
    end
    local text = io.readfile(source, {encoding = "binary"})
    io.writefile(out, mutated(text), {encoding = "binary"})
end

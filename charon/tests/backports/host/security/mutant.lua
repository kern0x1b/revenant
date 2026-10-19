-- mutant.lua SRC OUT OLD NEW [WHY] - a copy of SRC with the one place OLD stands replaced by NEW, written to OUT.
--
--    xmake l mutant.lua SRC OUT OLD NEW [WHY]
--
-- OLD must stand EXACTLY ONCE in SRC. Any other count is a refusal: exit 1, and nothing written, so a mutation whose anchor has moved
-- is a failed run and not a mutant that is quietly not one. With WHY the line says what the mutant does; without it, that it was
-- written.

local tsv = import("tsv", {rootdir = os.scriptdir()})

function main(...)
    local args = {...}
    if #args < 4 then
        io.stderr:write("mutant.lua: pass the source, the output, the old text and the new text\n")
        os.exit(1)
    end
    local src, out, old, new, why = args[1], args[2], args[3], args[4], args[5]
    local text = tsv.read_text(src)
    local count = tsv.count_of(text, old)
    if count ~= 1 then
        io.stderr:write("the mutation anchor for " .. out .. " matched " .. count .. " times, not once\n")
        os.exit(1)
    end
    local s, e = text:find(old, 1, true)
    local handle = assert(io.open(out, "wb"))
    handle:write(text:sub(1, s - 1) .. new .. text:sub(e + 1))
    handle:close()
    local name = out:match("([^/]+)$")
    if why then
        print("  mutant " .. name .. ": " .. why)
    else
        print("  mutant " .. name .. " written")
    end
    os.exit(0)
end

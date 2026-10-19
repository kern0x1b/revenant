-- The mutant text run.sh makes of a port source: the first occurrence of <old> in <file> becomes <new>, and the
-- text must be there, or the mutant is not the one the test names.
--
--     xmake lua tests/backports/host/homeindicator/replace.lua <file> <old> <new>
function main(path, old, new)
    local text = io.readfile(path)
    local start, finish = text:find(old, 1, true)
    if not start then
        raise("replace.lua: the text to replace is not in " .. path)
    end
    io.writefile(path, text:sub(1, start - 1) .. new .. text:sub(finish + 1))
end

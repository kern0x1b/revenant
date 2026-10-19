function main(path, old, new)
    local text = io.readfile(path)
    local start, finish = text:find(old, 1, true)
    if not start then
        raise("replace.lua: the text to replace is not in " .. path)
    end
    io.writefile(path, text:sub(1, start - 1) .. new .. text:sub(finish + 1))
end

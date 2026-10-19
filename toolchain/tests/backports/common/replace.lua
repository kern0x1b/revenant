function main(src, out, needle, replacement)
    local handle = assert(io.open(src, "rb"))
    local text = handle:read("a")
    handle:close()
    local s, e = text:find(needle, 1, true)
    if not s then
        os.exit(1)
    end
    handle = assert(io.open(out, "wb"))
    handle:write(text:sub(1, s - 1) .. replacement .. text:sub(e + 1))
    handle:close()
end

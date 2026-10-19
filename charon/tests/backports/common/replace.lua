-- replace.lua SRC OUT NEEDLE REPLACEMENT - a copy of SRC with the first place NEEDLE stands replaced by REPLACEMENT, written to
-- OUT. It exits 1, and writes nothing, when NEEDLE is not in SRC: a plant that does not apply is not a mutation.
-- Usage (from run.sh): xmake l "$here/../../common/replace.lua" "$port" "$out" "$from" "$to"

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

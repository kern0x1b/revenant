local LIBRARIES = {
    {"quad", {"quad-vertex", "quad-fragment", "quad-stagein", "quad-flow", "quad-constants", "quad-fetch", "depth-vertex", "depth-fragment", "quad-pair", "depth-read", "depth-compare", "mask-shape", "mask-merge"}},
    {"pair", {"fetch-pair"}},
}

local function bitcode(llvm, fixtures, work, name)
    local out = path.join(work, name .. ".bc")
    os.execv(path.join(llvm, "bin", "llvm-as"), {path.join(fixtures, name .. ".ll"), "-o", out})
    local handle = assert(io.open(out, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

function build(llvm, fixtures, work)
    for _, entry in ipairs(LIBRARIES) do
        local library, names = entry[1], entry[2]
        local parts = {"MTLB", string.rep("\0", 16)}
        for _, name in ipairs(names) do
            table.insert(parts, bitcode(llvm, fixtures, work, name))
        end
        io.writefile(path.join(work, library .. ".metallib"), table.concat(parts))
    end
end

function main(command, ...)
    if command == "build" then
        build(...)
        return
    end
    io.stderr:write("usage: metallib.lua build <llvm> <fixtures> <work>\n")
    os.exit(2)
end

-- The band's own export names, which is what modules/apple/backports.lua's check_registry reads as
-- `exports[...]`: the same dyld.load the gate uses, one release, read once into a text file.
function main(checkout, cache, out)
    local dyld = import("apple.dyld", {rootdir = path.join(checkout, "modules"), anonymous = true})
    local release = dyld.load(cache)
    local names = {}
    for name in pairs(release.exports) do names[#names + 1] = name end
    table.sort(names)
    local f = assert(io.open(out, "w"))
    for _, n in ipairs(names) do f:write(n, "\n") end
    f:close()
    print("wrote " .. #names .. " export names to " .. out)
end

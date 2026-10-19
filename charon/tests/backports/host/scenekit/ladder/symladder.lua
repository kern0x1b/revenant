-- xmake l symladder.lua <modules> <out> <sym,...> : first release exporting each symbol (6.1.3 must be none)
function main(modules, output, list)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local SYMBOLS = list:split(",")
    local RELEASES = {"6.1.3", "7.1.2", "8.0", "8.1.3", "8.4.1", "9.0", "9.3", "10.0.1", "10.3", "11.0", "12.0", "16.0"}
    local first, lines = {}, {}
    for _, release in ipairs(RELEASES) do
        local folder = path.join(dyld.root(), release)
        local cache
        for _, arch in ipairs({"armv7", "armv7s", "arm64", "arm64e"}) do
            cache = dyld.held_source(folder, arch)
            if cache and os.isfile(cache) then break end
            cache = nil
        end
        if cache then
            local loaded = dyld.load(cache)
            for _, s in ipairs(SYMBOLS) do if loaded.exports[s] and not first[s] then first[s] = release end end
            table.insert(lines, "# read " .. release .. " " .. path.filename(cache))
        end
    end
    for _, s in ipairs(SYMBOLS) do table.insert(lines, s .. "\t" .. (first[s] or "none")) end
    io.writefile(output, table.concat(lines, "\n") .. "\n")
end

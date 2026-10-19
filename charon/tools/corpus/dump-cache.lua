function main(cachefile)
    assert(cachefile, "usage: dump-cache.lua <cache file>")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = dyld.load(cachefile)
    for install, library in pairs(cache.libraries) do
        local fw = path.filename(install)
        for name in pairs(library.exports) do
            print(name .. "\t" .. fw)
        end
    end
end

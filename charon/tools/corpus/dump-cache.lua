-- Dump a dyld shared cache's exports with framework attribution.
-- Prints: <symbol>\t<install-basename>   for every exported symbol.
-- Usage: CHARON_ROOT=<worktree> xmake l dump-cache.lua <abs-path-to-cache-file>
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

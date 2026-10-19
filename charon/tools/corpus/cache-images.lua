-- List a dyld shared cache's images: one line per image, <install name>\t<number of exports>, every image of the cache (an image that
-- exports nothing too). The ledger reads it for the Swift proof: a release whose cache holds no Swift runtime image has no Swift
-- declaration in it (ledger.lua swift_proof). dump-cache.lua lists the exports, and only the images that have some.
-- Usage: CHARON_ROOT=<worktree> xmake l cache-images.lua <abs-path-to-cache-file>
function main(cachefile)
    assert(cachefile, "usage: cache-images.lua <cache file>")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = dyld.load(cachefile)
    for install, library in pairs(cache.libraries) do
        local count = 0
        for _ in pairs(library.exports) do
            count = count + 1
        end
        print(install .. "\t" .. count)
    end
end

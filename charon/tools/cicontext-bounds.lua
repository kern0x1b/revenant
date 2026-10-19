-- Does the release's own armv7 cache carry the CoreImage image, and does that image export
-- _OBJC_CLASS_$_CIContext? Read with apple.dyld, because the export trie compresses names: a raw
-- search over the cache bytes is not an oracle, and it says 5.0 has no CIContext, which is not so.
-- The image's own export table answers "does that image export it", and exported_at with no owner
-- answers "does the cache export it anywhere".
--
-- Two ".." and no more, as every other tool in tools/ spells it (release-split.lua:72,
-- sdk-markers.lua:15, matter-alias.lua:13). With four, the path left this repository: from
-- charon/tools it reaches charon/.agent-work/worktrees and then the shared checkout one level
-- above it, so the tool read the *shared* tree's modules/apple/dyld.lua and answered from another
-- tree's code. Four dots do not fail loudly - they succeed against the wrong tree.
import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local IMAGE = "/System/Library/Frameworks/CoreImage.framework/CoreImage"
local SYMBOLS = {"_OBJC_CLASS_$_CIContext", "_OBJC_CLASS_$_CIImage", "_OBJC_CLASS_$_CIFilter", "_OBJC_CLASS_$_CIColor"}
local root = os.getenv("HOME") .. "/.charon/dyld"

for _, release in ipairs({"4.3", "4.3.5", "5.0", "5.1.1", "6.0", "6.1.3", "7.0"}) do
    local file = path.join(root, release, "dyld_shared_cache_armv7")
    if not os.isfile(file) then
        print(string.format("%-7s no cache held", release))
    else
        local cache = dyld.open_cache(file)
        local found
        for _, image in ipairs(cache.images) do
            if image.install == IMAGE then found = image break end
        end
        print(string.format("%-7s the CoreImage image: %s", release, found and "in the cache" or "NOT in the cache"))
        if found then
            -- The image's own export table, read through dyld.image_symbols(cache, found), which is
            -- what modules/apple/objc.lua:606 reads. There is no .exports on the image itself:
            -- found.image is the Mach-O header and found.image.exports is nil, so the expression
            -- this replaces fell back to an empty table and printed "by that image: no" for every
            -- symbol on every release - a table of NOs, not a measurement. The exports come back as
            -- a list of {address, name} pairs, so they go in a set to be asked of.
            local symbols = dyld.image_symbols(cache, found)
            local by_image = {}
            for _, entry in ipairs(symbols.exports or {}) do
                by_image[entry[2]] = true
            end
            -- "anywhere in the cache" needs the loaded cache, not the open one: exported_at with no
            -- owner reads cache.exports, and open_cache() (dyld.lua:518) returns the file map with
            -- images and no exports at all, so it raised "attempt to index a nil value (field
            -- 'exports')" at dyld.lua:861 and the tool died on the first release whose image is in
            -- the cache. load() (dyld.lua:623) is what builds the whole export map and the library
            -- table exported_by() walks.
            local loaded = dyld.load(file)
            for _, symbol in ipairs(SYMBOLS) do
                local there = by_image[symbol] ~= nil
                local anywhere = dyld.exported_at(loaded, symbol)
                print(string.format("          %-26s by that image: %-3s  anywhere in the cache: %s", symbol,
                                    there and "yes" or "no", anywhere and "yes" or "no"))
            end
        end
        cache.close()
    end
end

-- Does a held release's armv7 dyld shared cache export a set of symbols, and which image exports each?
--
--     VNET_MODULES=<charon>/modules xmake l tools/corpus/cache-exports.lua 4.3 6.0 6.1.3
--
-- Read with apple.dyld, because the export trie compresses names: a raw search over the cache bytes is
-- not an oracle, and tools/cicontext-bounds.lua:2-4 says so in the same words. Two dots and no more, as
-- every other tool in tools/ spells it (release-split.lua:72, sdk-markers.lua:15,
-- matter-alias.lua:13): with four, the path leaves this repository and the tool reads another tree's
-- modules/apple/dyld.lua and answers from another tree's code.
--
-- The symbols come from the environment, VNET_SYMBOLS, one per space, because which set is interesting
-- changes with the question; VNET_IMAGES, one install path per space, narrows the answer to the images
-- that carry the API and prints the others as not in the cache.
import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local function split(text)
    local words = {}
    for word in string.gmatch(text or "", "%S+") do
        table.insert(words, word)
    end
    return words
end

local root = os.getenv("HOME") .. "/.charon/dyld"
local wanted = split(os.getenv("VNET_SYMBOLS"))
local images = split(os.getenv("VNET_IMAGES"))

if #wanted == 0 then
    print("VNET_SYMBOLS names the symbols to ask for, space separated")
    return
end

for _, release in ipairs(os.getenv("VNET_RELEASES") and split(os.getenv("VNET_RELEASES")) or {"4.3", "4.3.5", "5.0", "6.0", "6.1.3"}) do
    local file = path.join(root, release, "dyld_shared_cache_armv7")
    if not os.isfile(file) then
        print(string.format("%-7s no cache held", release))
    else
        local cache = dyld.open_cache(file)
        local where = {}
        for _, image in ipairs(cache.images) do
            for _, entry in ipairs((dyld.image_symbols(cache, image).exports) or {}) do
                for _, name in ipairs(wanted) do
                    if entry[2] == name then
                        where[name] = where[name] or image.install
                    end
                end
            end
        end
        print(string.format("%-7s images=%d", release, #cache.images))
        for _, name in ipairs(wanted) do
            local image = where[name]
            if image and #images > 0 then
                local named = false
                for _, wanted_image in ipairs(images) do
                    named = named or image == wanted_image
                end
                image = named and image or (image .. "  (outside the images asked for)")
            end
            print(string.format("    %-38s %s", name, image or "NOT EXPORTED"))
        end
    end
end
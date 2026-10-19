import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local function split(text)
    local words = {}
    for word in string.gmatch(text or "", "%S+") do
        table.insert(words, word)
    end
    return words
end

local root = os.getenv("HOME") .. "/.revenant/dyld"
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

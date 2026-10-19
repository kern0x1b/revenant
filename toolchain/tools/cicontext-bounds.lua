import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local IMAGE = "/System/Library/Frameworks/CoreImage.framework/CoreImage"
local SYMBOLS = {"_OBJC_CLASS_$_CIContext", "_OBJC_CLASS_$_CIImage", "_OBJC_CLASS_$_CIFilter", "_OBJC_CLASS_$_CIColor"}
local root = os.getenv("HOME") .. "/.revenant/dyld"

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
            local symbols = dyld.image_symbols(cache, found)
            local by_image = {}
            for _, entry in ipairs(symbols.exports or {}) do
                by_image[entry[2]] = true
            end
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

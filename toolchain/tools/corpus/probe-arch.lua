local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function main(cachefile, wanted, prefix)
    local cache = dyld.open_cache(cachefile)
    print("#cache " .. tostring(cache.architecture))
    local matched = 0
    for _, loaded in ipairs(cache.images) do
        if loaded.install:find(wanted, 1, true) then
            matched = matched + 1
            print("#" .. loaded.install .. string.format(" base %#x", loaded.address))
            local symbols = dyld.image_symbols(cache, loaded)
            local rows = {}
            for _, entry in ipairs(symbols.exports or {}) do
                local address, name = entry[1], entry[2]
                if address and (not prefix or name:find(prefix, 1, true)) then
                    table.insert(rows, string.format("%#x\t%s%s", address, name,
                                                      address % 2 == 1 and "\t(thumb)" or ""))
                end
            end
            for _, entry in ipairs(symbols.indirect or {}) do
                local slot, name = entry[1], entry[2]
                if name and (not prefix or name:find(prefix, 1, true)) then
                    table.insert(rows, string.format("%#x\t%s\t(indirect slot)", slot, name))
                end
            end
            byteorder.sort(rows)
            print(string.format("#exports %d, indirect %d, listed %d",
                                #(symbols.exports or {}), #(symbols.indirect or {}), #rows))
            for _, row in ipairs(rows) do
                print(row)
            end
        end
    end
    if matched == 0 then
        error("no image of this cache has an install name containing " .. tostring(wanted))
    end
    cache.close()
end

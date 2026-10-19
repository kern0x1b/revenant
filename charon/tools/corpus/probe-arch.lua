-- The exports of one image of one cache, as "address<TAB>name", sorted by address.
--
--   CHARON_ROOT=<worktree> CACHE=<cache> xmake l tools/corpus/probe-arch.lua <image substring> [prefix]
--
-- The walk needs name -> address twice: to start at an exported symbol, and to put a name on whatever a
-- branch lands on. dyld.image_symbols() is what reads it - it walks the export trie and the indirect
-- symbol table of the image, which is the same answer a whole-cache `ipsw dyld exports` gives, without
-- reading the whole cache.
--
-- One thing this got wrong first, and it cost the walk a round: an image comes out of `cache.images` as a
-- *loaded* pair, and the base is `loaded.address`. `loaded.image.base` is nil, and passing that to
-- image_symbols() made it add a nil base to every export address - so the reader found the exports and
-- every one of them came back nil. skeleton-table.lua walks `cache.images` the same way and uses
-- `loaded.image.sections`, which is why it worked and this did not.

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
                    -- An odd address is Thumb: the low bit is the mode, not part of the address.
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
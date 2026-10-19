-- The NUL-terminated strings of a dyld shared cache's __cfstring records, in address order, read with
-- the project's own reader (modules/apple/dyld.lua's open_cache). Bounded memory: one record is read
-- at a time and nothing is kept but what is printed.
--
-- A __cfstring is 32 bytes on a 64-bit cache and the field offsets are the whole difficulty:
--
--     struct __CFConstantString { uintptr_t isa; uintptr_t flags; const char *str; unsigned long length; }
--         isa +0, flags +8, str +16, length +24
--
-- `str` is stored the way the cache stores every pointer - slid and tagged above the address bits -
-- so it is masked with 0xFFFFFFFFF before it is read, the same rule tools/cache-value.lua applies to a
-- stored pointer (its line 107) and for the same reason. Reading `str` at +8 gets `flags`, which is
-- one small constant for every record, and that is the mistake this reader's comment exists to name.
--
-- Usage: CHARON_ROOT=<worktree> xmake l cfstring-run.lua <cache file> <first address> <count> [max length]
import("core.base.option")

function main(cachefile, first, count, longest)
    assert(cachefile and first and count, "usage: cfstring-run.lua <cache file> <first address> <count> [max length]")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = dyld.open_cache(cachefile)
    local base = tonumber(first, 16)
    local total = tonumber(count)
    local limit = tonumber(longest) or 80
    print("# cache " .. cache.main.header:sub(1, 4) .. " " .. cache.architecture ..
          ", records of 32 bytes from " .. string.format("%#x", base) .. ", " .. total)
    for index = 0, total - 1 do
        local record = base + index * 32
        local isa, flags, raw, length = string.unpack("<I8I8I8I8", cache.read_address(record, 32))
        local address = raw & 0xFFFFFFFFF
        local text = (length > 0 and length < limit) and cache.string_at(address) or nil
        print(string.format("%d\t%s\t%s\t%s\t%d\t%s", index, string.format("%#x", record),
                            string.format("%#x", isa), string.format("%#x", address), length,
                            text or ""))
    end
end

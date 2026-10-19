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

import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

function main()
    local dyld = import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
    local held
    for _, release in ipairs({"6.0", "6.1.3"}) do
        local cachefile = path.join(dyld.root(), release, "dyld_shared_cache_armv7")
        if not os.isfile(cachefile) then
            raise("%s is not held, so its install names cannot be listed: fetch it with ./xmakew firmware -P . -a armv7 fetch %s", cachefile, release)
        end
        local names = {}
        for install in pairs(dyld.load(cachefile).images) do
            if not held or held[install] then
                names[install] = true
            end
        end
        held = names
    end
    local lines = table.keys(held)
    byteorder.sort(lines)
    local output = path.join(os.scriptdir(), "..", "src", "iphoneos-sdk", "inventory", "ios6.txt")
    os.mkdir(path.directory(output))
    io.writefile(output, table.concat({
        "# The install names the iOS 6.0 and iOS 6.1.3 releases both hold, from their dyld shared caches (armv7).",
        "# Written by toolchain/tools/sdk_inventory.lua; a library not listed here is one iOS 6 lacks.",
    }, "\n") .. "\n" .. table.concat(lines, "\n") .. "\n")
    print("%s: %d install names", output, #lines)
end

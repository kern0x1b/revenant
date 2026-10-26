local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function stamp(seconds)
    if not seconds or seconds == 0 then
        return "-"
    end
    return os.date("%Y-%m-%d %H:%M", seconds)
end

local function status()
    local root = cache().root()
    local rows, total = cache().status(root)
    print("cache    %s", root)
    print("cap      %s (REVENANT_CACHE_GB, 15 GB by default)", cache().human(cache().limit()))
    print("used     %s (the cache and the build outputs of every worktree)", cache().human(total))
    print("")
    print("%10s  %-10s %-16s %s", "size", "class", "last used", "entry")
    for _, row in ipairs(rows) do
        print("%10s  %-10s %-16s %s%s", cache().human(row.bytes), row.class, stamp(row.used), row.name, row.held and "  (in use)" or "")
    end
end

local function prune(dry)
    local generations, firmware = cache().prune(cache().root(), {dry = dry})
    for _, folder in ipairs(generations) do
        print("%s %s", dry and "would remove" or "removed", folder)
    end
    for _, folder in ipairs(firmware) do
        print("%s %s", dry and "would remove" or "removed", folder)
    end
    print("%s %d package generations and %d firmware folders or files that the configured releases do not need",
          dry and "would remove" or "removed", #generations, #firmware)
end

local function guard(from)
    local result = cache().guard(from)
    for _, listed in ipairs(result.evicted) do
        print("evicted  %s  %s", cache().human(listed.bytes), listed.name)
    end
end

function main(command, ...)
    local arguments = {...}
    if command == "guard" then
        return guard(arguments[1])
    elseif command == "record" then
        cache().record(arguments[1])
        return
    end
    local dry = false
    for _, argument in ipairs(arguments) do
        if argument == "--dry-run" or argument == "-n" then
            dry = true
        else
            raise("usage: ./xmakew l tools/cache.lua [status | prune [--dry-run]]")
        end
    end
    if command == nil or command == "status" then
        status()
    elseif command == "prune" then
        prune(dry)
    else
        raise("usage: ./xmakew l tools/cache.lua [status | prune [--dry-run] | guard | record]")
    end
end

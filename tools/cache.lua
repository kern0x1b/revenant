local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local USAGE = "usage: ./xmakew l tools/cache.lua [status | prune [--dry-run] | guard | record]"

local function stamp(seconds)
    if not seconds or seconds == 0 then
        return "-"
    end
    return os.date("%Y-%m-%d %H:%M", seconds)
end

local function rows_of(rows)
    print("%10s  %-10s %-16s %s", "size", "class", "last used", "entry")
    for _, row in ipairs(rows) do
        print("%10s  %-10s %-16s %s%s%s", cache().human(row.bytes), row.class, stamp(row.used), row.name, row.held and "  (in use)" or "",
              row.pinned and "  (pinned)" or "")
    end
end

local function status()
    local root = cache().root()
    local rows, total = cache().status(root)
    print("cache    %s", root)
    print("cap      %s (REVENANT_CACHE_GB, 50 GB by default)", cache().human(cache().limit()))
    print("used     %s (the cache and the build outputs of every worktree)", cache().human(total))
    print("")
    rows_of(rows)
    local shared = cache().store()
    local shared_rows, shared_total = cache().status(shared, {builds = {}})
    print("")
    print("store    %s (shared by every checkout of this machine)", shared)
    print("cap      %s (REVENANT_STORE_GB, 80 GB by default)", cache().human(cache().store_limit()))
    print("used     %s", cache().human(shared_total))
    print("")
    rows_of(shared_rows)
end

local function prune(dry)
    local generations, firmware = cache().prune(cache().root(), {dry = dry})
    local shared = cache().prune(cache().store(), {dry = dry})
    for _, folder in ipairs(table.join(generations, firmware, shared)) do
        print("%s %s", dry and "would remove" or "removed", folder)
    end
    print("%s %d package generations (%d of them in the shared store) and %d firmware folders or files that the configured releases do not need",
          dry and "would remove" or "removed", #generations + #shared, #shared, #firmware)
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
            raise(USAGE)
        end
    end
    if command == nil or command == "status" then
        status()
    elseif command == "prune" then
        prune(dry)
    else
        raise(USAGE)
    end
end

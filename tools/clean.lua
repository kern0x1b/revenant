local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function retention()
    return import("@addon.revenant.retention", {anonymous = true})
end

local function checkout()
    return path.directory(os.scriptdir())
end

local function size(folder)
    local out = try { function () return os.iorunv("du", {"-sk", folder}) end }
    return tonumber(out and out:match("^(%d+)")) or 0
end

local function human(kib)
    if kib >= 1024 * 1024 then
        return string.format("%.1fG", kib / 1024 / 1024)
    elseif kib >= 1024 then
        return string.format("%.1fM", kib / 1024)
    end
    return string.format("%dK", kib)
end

local function plan(level)
    local root = cache().root()
    local targets = {}
    for _, build in ipairs(cache().build_outputs()) do
        table.insert(targets, build.folder)
    end
    if level == "all" then
        table.insert(targets, root)
        return targets
    end
    table.join2(targets, os.dirs(path.join(root, "scratch", "*")), os.dirs(path.join(root, "xmake", "*.build.*")),
                os.files(path.join(root, "xmake", "*.log")))
    if level == "packages" then
        table.insert(targets, path.join(root, "xmake-global"))
    elseif os.isdir(path.join(root, "xmake-global", ".xmake", "cache")) then
        table.insert(targets, path.join(root, "xmake-global", ".xmake", "cache"))
    end
    return targets
end

local function prune(dry)
    local generations, firmware = cache().prune(cache().root(), {dry = dry})
    for _, folder in ipairs(table.join(generations, firmware)) do
        print("%s %s", dry and "would remove" or "removed", folder)
    end
    print("%s %d package generations and %d firmware entries that the kept releases do not need",
          dry and "would remove" or "removed", #generations, #firmware)
end

local function enforce(dry)
    if dry then
        return
    end
    try
    {
        function ()
            for _, listed in ipairs(cache().enforce().evicted) do
                print("evicted  %s  %s", cache().human(listed.bytes), listed.name)
            end
        end,
        catch
        {
            function (errors)
                print("cap: %s", tostring(errors))
            end
        }
    }
end

local function scratch(dry)
    prune(dry)
    local report = retention().sweep(cache().root(), {checkout = checkout(), dry = dry})
    if report.error then
        print("scratch: %s", report.error)
    else
        for _, item in ipairs(report.kept) do
            print("kept     %s: %s", path.filename(item.folder), item.why)
        end
        for _, folder in ipairs(report.removed) do
            print("%s %s", dry and "would remove" or "removed", folder)
        end
        if dry then
            print("would remove %d scratch folders; kept %d", #report.removed, #report.kept)
        else
            print("removed %d scratch folders; kept %d; freed %s of disk, by the free space before and after (du overstates clones)",
                  #report.removed, #report.kept, human(report.freed_kib))
        end
    end
    enforce(dry)
end

function main(...)
    local arguments = {...}
    local level, dry = "default", false
    for _, argument in ipairs(arguments) do
        if argument == "--packages" then
            level = "packages"
        elseif argument == "--all" then
            level = "all"
        elseif argument == "--scratch" then
            level = "scratch"
        elseif argument == "--dry-run" or argument == "-n" then
            dry = true
        else
            raise("usage: ./xmakew l tools/clean.lua [--packages | --all | --scratch] [--dry-run]")
        end
    end
    if level == "scratch" then
        return scratch(dry)
    end
    local total = 0
    for _, target in ipairs(plan(level)) do
        local kib = size(target)
        total = total + kib
        print("%s %8s  %s", dry and "would remove" or "removing", human(kib), target)
        if not dry then
            os.tryrm(target)
            if os.exists(target) then
                os.vrunv("rm", {"-rf", target})
            end
        end
    end
    local kept = {
        default = "the xmake binaries, the package store and the data under " .. cache().root(),
        packages = "the xmake binaries and the data under " .. cache().root(),
        all = "nothing under " .. cache().root()
    }
    print("%s %s; kept %s", dry and "would free" or "freed", human(total), kept[level])
end

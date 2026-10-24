local STORES = {"xmake", "xmake-global"}
local OUTPUTS = {".xmake", "build"}

local function home()
    return assert(os.getenv("HOME"), "clean: HOME is not set")
end

local function revenant()
    return path.join(home(), ".revenant")
end

local function cache()
    return path.join(revenant(), "cache")
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

local function worktrees()
    local roots = {}
    local out = try { function () return os.iorunv("git", {"-C", checkout(), "worktree", "list", "--porcelain"}) end }
    for line in (out or ""):gmatch("[^\n]+") do
        local root = line:match("^worktree (.+)$")
        if root and os.isdir(root) then
            table.insert(roots, root)
        end
    end
    if #roots == 0 then
        table.insert(roots, checkout())
    end
    return roots
end

local function ignored(root, folder)
    local relative = path.relative(folder, root)
    local tracked = try { function () return os.iorunv("git", {"-C", root, "ls-files", "--", relative}) end }
    if tracked == nil or tracked:trim() ~= "" then
        return false
    end
    return os.execv("git", {"-C", root, "check-ignore", "-q", relative}, {try = true}) == 0
end

local function build_outputs()
    local found = {}
    for _, root in ipairs(worktrees()) do
        local parents = {root}
        for _, member in ipairs(os.dirs(path.join(root, "*"))) do
            table.insert(parents, member)
        end
        for _, framework in ipairs(os.dirs(path.join(root, "frameworks", "*"))) do
            table.insert(parents, framework)
        end
        for _, parent in ipairs(parents) do
            for _, name in ipairs(OUTPUTS) do
                local folder = path.join(parent, name)
                if os.isdir(folder) and ignored(root, folder) then
                    table.insert(found, folder)
                end
            end
        end
    end
    return found
end

local function kept(name, level)
    if level == "all" then
        return false
    end
    if level == "packages" then
        return name == "xmake"
    end
    return table.contains(STORES, name)
end

local function plan(level)
    local root = cache()
    local targets = build_outputs()
    local last
    for _, entry in ipairs(os.filedirs(path.join(root, "*"))) do
        if not kept(path.filename(entry), level) then
            if path.filename(entry) == "xmake" then
                last = entry
            else
                table.insert(targets, entry)
            end
        end
    end
    local packages_cache = path.join(root, "xmake-global", ".xmake", "cache")
    if level == "default" and os.isdir(packages_cache) then
        table.insert(targets, packages_cache)
    end
    if level ~= "all" then
        table.join2(targets, os.dirs(path.join(root, "xmake", "*.build.*")), os.files(path.join(root, "xmake", "*.log")))
    end
    if last then
        table.insert(targets, last)
    end
    return targets
end

local function scratch(dry)
    local retention = import("@addon.revenant.retention", {anonymous = true})
    local report = retention.sweep(home(), {checkout = checkout(), dry = dry})
    if report.error then
        print("scratch: %s", report.error)
        return
    end
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
    print("%s %s; kept %s", dry and "would free" or "freed", human(total),
          level == "all" and "nothing under " .. cache() or table.concat(level == "packages" and {"xmake"} or STORES, ", "))
    local data = {}
    for _, entry in ipairs(os.filedirs(path.join(revenant(), "*"))) do
        if path.filename(entry) ~= "cache" then
            table.insert(data, path.filename(entry))
        end
    end
    table.sort(data)
    print("never touched: %s under %s, and ~/.xmake", table.concat(data, ", "), revenant())
end

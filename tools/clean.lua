local STORES = {"xmake", "xmake-global", "ccache"}
local OUTPUTS = {".xmake", "build"}
local VOLUME = "RevenantCache"

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

local function alive(pid)
    return pid and os.execv("kill", {"-0", tostring(pid)}, {try = true, stdout = os.nuldev(), stderr = os.nuldev()}) == 0
end

local function running_jobs()
    local dir = path.join(os.getenv("FLEET_HEAVY_DIR") or "/tmp/fleet-heavy", "pool", "jobs")
    local found = {}
    for _, file in ipairs(os.files(path.join(dir, "*"))) do
        local record = try { function () return io.load(file) end }
        if record and alive(record.pid) then
            table.insert(found, record)
        end
    end
    return found
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
        return name == "xmake" or name == "ccache"
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

local function container()
    local info = os.iorunv("diskutil", {"info", "/System/Volumes/Data"})
    return assert(info:match("APFS Container:%s+(%S+)") or info:match("APFS Container Reference:%s+(%S+)"),
                  "clean: no APFS container for /System/Volumes/Data")
end

local function volume(quota, create)
    local mountpoint = cache()
    local disk = container()
    local steps = {
        {"diskutil", "apfs", "addVolume", disk, "APFS", VOLUME, "-quota", quota, "-mountpoint", mountpoint},
        {"mdutil", "-i", "off", mountpoint},
        {"tmutil", "addexclusion", mountpoint}
    }
    print("an APFS volume %s of %s with a quota of %s, mounted at %s:", VOLUME, disk, quota, mountpoint)
    for _, step in ipairs(steps) do
        print("  %s", os.args(step))
    end
    print("wiped in one step with: diskutil apfs eraseVolume APFS %s %s", VOLUME, mountpoint)
    if not create then
        print("nothing was changed; the steps run with --volume=%s --create, after the owner agreed", quota)
        return
    end
    if #running_jobs() > 0 then
        raise("clean: heavy jobs are running; the volume is made when the machine is idle")
    end
    local moved = mountpoint .. ".before-volume"
    if os.exists(moved) then
        raise("clean: %s is still there from an earlier attempt; look at it and remove it first", moved)
    end
    if os.isdir(mountpoint) then
        os.mv(mountpoint, moved)
    end
    os.mkdir(mountpoint)
    for _, step in ipairs(steps) do
        os.vrunv(step[1], table.slice(step, 2))
    end
    local binaries = path.join(moved, "xmake")
    if os.isdir(binaries) then
        os.vrunv("cp", {"-R", binaries, path.join(mountpoint, "xmake")})
    end
    local uuid = os.iorunv("diskutil", {"info", mountpoint}):match("Volume UUID:%s+(%S+)")
    print("the volume is mounted at %s; to mount it there at every boot, add this line with sudo vifs:", mountpoint)
    print("  UUID=%s %s apfs rw", uuid or "<Volume UUID of diskutil info " .. mountpoint .. ">", mountpoint)
    print("the old folder is %s; remove it by hand once builds run from the volume", moved)
end

function main(...)
    local arguments = {...}
    local level, dry, force, quota, create = "default", false, false, nil, false
    for _, argument in ipairs(arguments) do
        if argument == "--packages" then
            level = "packages"
        elseif argument == "--all" then
            level = "all"
        elseif argument == "--dry-run" or argument == "-n" then
            dry = true
        elseif argument == "--force" then
            force = true
        elseif argument == "--create" then
            create = true
        elseif argument == "--volume" then
            quota = "80g"
        elseif argument:startswith("--volume=") then
            quota = argument:sub(#"--volume=" + 1)
        else
            raise("usage: xmake l tools/clean.lua [--packages | --all] [--dry-run] [--force] | --volume[=<quota>] [--create]")
        end
    end
    if quota then
        return volume(quota, create)
    end
    local jobs = running_jobs()
    if #jobs > 0 and not force and not dry then
        for _, job in ipairs(jobs) do
            print("running: %s (pid %d)", job.command, job.pid)
        end
        raise("clean: %d heavy jobs are running and use what this would remove; wait for them, or pass --force", #jobs)
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
          level == "all" and "nothing under " .. cache() or table.concat(level == "packages" and {"xmake", "ccache"} or STORES, ", "))
    local data = {}
    for _, entry in ipairs(os.filedirs(path.join(revenant(), "*"))) do
        if path.filename(entry) ~= "cache" then
            table.insert(data, path.filename(entry))
        end
    end
    table.sort(data)
    print("never touched: %s under %s, and ~/.xmake", table.concat(data, ", "), revenant())
end

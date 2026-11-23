import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})
import("workspace", {rootdir = path.join(os.scriptdir(), "..")})
import("exclusive", {rootdir = path.join(os.scriptdir(), "..")})

local SHARED_CACHE = "^dyld_shared_cache_[%w_]+$"
local HASHED_BELOW = 32 * 1024 * 1024
local STALE_AFTER = 3600

function root()
    return path.join(workspace.home(), "dyld")
end

function complete(folder)
    if not os.isdir(folder) then
        return false
    end
    for _, file in ipairs(os.files(path.join(folder, "dyld_shared_cache_*"))) do
        if path.filename(file):match(SHARED_CACHE) and os.isfile(file .. ".source") then
            return true
        end
    end
    return #os.dirs(path.join(folder, "libraries_*")) > 0
end

function worktrees(porcelain)
    local found = {}
    for line in porcelain:gmatch("[^\n]+") do
        local folder = line:match("^worktree (.+)$")
        if folder then
            table.insert(found, folder)
        end
    end
    return found
end

local function roots_of(checkout)
    local found = {}
    local plain = path.join(checkout, ".cache", "dyld")
    if os.isdir(plain) then
        table.insert(found, plain)
    end
    local others = os.dirs(path.join(checkout, ".cache-*", "dyld"))
    byteorder.sort(others)
    return table.join(found, others)
end

function sources(here, listing)
    listing = listing or os.iorunv("git", {"-C", workspace.root(), "worktree", "list", "--porcelain"})
    local found = {}
    for _, checkout in ipairs(worktrees(listing)) do
        for _, folder in ipairs(roots_of(checkout)) do
            if path.normalize(folder) ~= path.normalize(here) then
                table.insert(found, folder)
            end
        end
    end
    return found
end

local function clone(folder, target, here)
    local staging = path.join(path.directory(here), ".dyld-clone-" .. hash.uuid():sub(1, 8))
    local cloned = try { function () os.vrunv("cp", {"-c", "-R", folder, staging}) return true end }
    if not cloned then
        os.tryrm(staging)
        os.vrunv("cp", {"-R", folder, staging})
    end
    return exclusive.run(path.join(path.directory(here), ".dyld-clone.lock"), "the device caches", function ()
        if os.exists(target) then
            os.tryrm(staging)
            return false
        end
        os.mv(staging, target)
        return true
    end)
end

local function sweep(here)
    for _, folder in ipairs(os.dirs(path.join(path.directory(here), ".dyld-clone-*"))) do
        if os.time() - os.mtime(folder) > STALE_AFTER then
            os.tryrm(folder)
        end
    end
end

function provision(opt)
    opt = opt or {}
    local here = opt.here or root()
    local cloned, skipped = {}, {}
    os.mkdir(here)
    sweep(here)
    for _, source in ipairs(opt.sources or sources(here)) do
        local releases = os.dirs(path.join(source, "*"))
        byteorder.sort(releases)
        for _, folder in ipairs(releases) do
            local release = path.filename(folder)
            local target = path.join(here, release)
            if not release:startswith(".") and complete(folder) then
                if not os.exists(target) then
                    if clone(folder, target, here) then
                        table.insert(cloned, {release = release, from = folder})
                    end
                elseif not complete(target) then
                    skipped[release] = target
                end
            end
        end
    end
    return cloned, skipped
end

function identity(here)
    local lines = {}
    for _, folder in ipairs(os.dirs(path.join(here or root(), "*"))) do
        if complete(folder) then
            for _, file in ipairs(os.files(path.join(folder, "**"))) do
                local size = os.filesize(file)
                table.insert(lines, string.format("%s %s %d %s", path.filename(folder), path.relative(file, folder), size, size < HASHED_BELOW and hash.sha256(file) or "-"))
            end
        end
    end
    byteorder.sort(lines)
    return table.concat(lines, "\n")
end

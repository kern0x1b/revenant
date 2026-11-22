import("retention")
import("generations")
import("exclusive")

local GIGABYTE = 1000 * 1000 * 1000
local DEFAULT_GIGABYTES = 50
local DEFAULT_GROWTH = 2 * GIGABYTE
local ROOT_VARIABLE = "REVENANT_CACHE"
local LIMIT_VARIABLE = "REVENANT_CACHE_GB"
local STORE_VARIABLE = "REVENANT_STORE"
local STORE_LIMIT_VARIABLE = "REVENANT_STORE_GB"
local DEFAULT_STORE_GIGABYTES = 80
local STORE_STAMP = ".cap-checked"
local STORE_TRIM_LOCK = ".trim.lock"
local STORE_CHECK_SECONDS = 600
local ARCHITECTURE = "armv7"
local RELEASES = {"6.1.3", "6.0"}
local BUILD_OUTPUTS = {".xmake", "build"}
local ORDER = {generation = 1, source = 2, scratch = 3, build = 4, package = 5}
local resolved = {}

local function checkout_of(from)
    local common = try { function () return os.iorunv("git", {"-C", from, "rev-parse", "--path-format=absolute", "--git-common-dir"}):trim() end }
    if common and common ~= "" then
        return path.directory(common)
    end
    return path.directory(path.directory(path.normalize(path.absolute(os.scriptdir()))))
end

function checkout(from)
    if from then
        return checkout_of(from)
    end
    resolved.checkout = resolved.checkout or checkout_of(os.scriptdir())
    return resolved.checkout
end

local function physical(folder)
    local absolute = path.normalize(path.absolute(folder))
    local rest = {}
    local head = absolute
    while #head > 1 and not os.isdir(head) do
        table.insert(rest, 1, path.filename(head))
        head = path.directory(head)
    end
    local real = try { function () return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", head}):trim() end }
    return path.join(real ~= nil and real ~= "" and real or head, table.unpack(rest))
end

function inside_store(folder)
    local shared = try { function () return store() end }
    if not shared then
        return false
    end
    local prefix = physical(shared) .. "/"
    return (physical(folder) .. "/"):sub(1, #prefix) == prefix
end

local function refuse_store(folder, how)
    if inside_store(folder) then
        raise("%s is %s, which is the shared store %s or lies inside it: the cache is trimmed to %s, and that would evict the installs of the store. %s is the cache of one checkout (by default <checkout>/.cache); the store is %s, and the two are different folders",
              how, folder, store(), LIMIT_VARIABLE, ROOT_VARIABLE, STORE_VARIABLE)
    end
end

function root()
    local named = os.getenv(ROOT_VARIABLE)
    if named and named ~= "" then
        local folder = path.absolute(named)
        refuse_store(folder, ROOT_VARIABLE)
        return folder
    end
    return path.join(checkout(), ".cache")
end

function store()
    local named = os.getenv(STORE_VARIABLE)
    if named and named ~= "" then
        if not path.is_absolute(named) then
            raise("%s is %q, which is not an absolute path", STORE_VARIABLE, named)
        end
        return path.normalize(named)
    end
    local home = os.getenv("HOME")
    if not home or home == "" then
        raise("HOME is unset, so the shared store has no default place: set %s", STORE_VARIABLE)
    end
    return path.join(home, ".revenant", "store")
end

local function gigabytes_of(variable, default)
    local text = os.getenv(variable)
    if not text or text == "" then
        return default * GIGABYTE
    end
    local gigabytes = tonumber(text)
    if not gigabytes or gigabytes <= 0 then
        raise("%s is %q, which is not a positive number of gigabytes", variable, text)
    end
    return math.floor(gigabytes * GIGABYTE)
end

function limit()
    return gigabytes_of(LIMIT_VARIABLE, DEFAULT_GIGABYTES)
end

function store_limit()
    return gigabytes_of(STORE_LIMIT_VARIABLE, DEFAULT_STORE_GIGABYTES)
end

function store_stamp()
    return STORE_STAMP
end

function pins(base)
    local pinned = {}
    for _, file in ipairs(os.files(path.join(base, "roots", "*.txt"))) do
        for line in io.readfile(file):gmatch("[^\n]+") do
            local named = line:match("^%s*([^#%s][^%s]*)")
            if named then
                pinned[path.join(base, "xmake-global", ".xmake", "packages", named)] = true
            end
        end
    end
    return pinned
end

local function pinned_by(members, fixed)
    for _, member in ipairs(members) do
        if fixed[member] then
            return true
        end
    end
    return false
end

function human(bytes)
    if bytes >= GIGABYTE then
        return string.format("%.2f GB", bytes / GIGABYTE)
    elseif bytes >= 1000 * 1000 then
        return string.format("%.1f MB", bytes / 1000 / 1000)
    end
    return string.format("%d KB", bytes // 1000)
end

function bytes_of(folder)
    if not (os.exists(folder) or os.islink(folder)) then
        return 0
    end
    local out = try { function () return os.iorunv("du", {"-sk", folder}) end }
    return (tonumber(out and out:match("^(%d+)")) or 0) * 1024
end

function last_used(folder)
    local newest = 0
    local out = try { function () return os.iorunv("find", {folder, "-exec", "stat", "-f", "%m", "{}", "+"}) end }
    for line in (out or ""):gmatch("[^\n]+") do
        newest = math.max(newest, tonumber(line) or 0)
    end
    return newest
end

local function generation_base(name)
    return name:match("^(.-)%.g%x+$")
end

local function kept_release(release)
    return table.contains(RELEASES, release)
end

local function packages_root(folder)
    local dir = path.directory(folder)
    while #dir > 1 do
        if path.filename(dir) == "packages" then
            return dir
        end
        dir = path.directory(dir)
    end
end

local function prune_empty(folder)
    local root = packages_root(folder)
    if not root then
        return
    end
    local dir = path.directory(folder)
    while #dir > #root do
        if os.execv("rmdir", {dir}, {try = true, stderr = os.nuldev()}) ~= 0 then
            return
        end
        dir = path.directory(dir)
    end
end

local function remove(members)
    for _, member in ipairs(members) do
        if os.islink(member) then
            os.execv("rm", {"-f", member})
        else
            generations.discard(member)
        end
        prune_empty(member)
    end
end

local function unlock_members(held)
    for _, lock in ipairs(held) do
        lock:unlock()
        lock:close()
    end
end

local function lock_members(members)
    local held = {}
    for _, member in ipairs(members) do
        if member:endswith(".lock") and os.isfile(member) then
            local lock = io.openlock(member)
            if lock and lock:trylock() then
                table.insert(held, lock)
            else
                if lock then
                    lock:close()
                end
                unlock_members(held)
                return nil
            end
        end
    end
    return held
end

local function with_locks(members)
    local found = {}
    for _, member in ipairs(members) do
        table.insert(found, member)
        if os.isfile(member .. ".lock") then
            table.insert(found, member .. ".lock")
        end
    end
    return found
end

local function entry(base, folder, class, members)
    return {folder = folder, class = class, name = path.relative(folder, base), members = with_locks(members or {folder})}
end

local function children(folder)
    return os.filedirs(path.join(folder, "*"))
end

local function package_entries(base, found)
    local store = path.join(base, "xmake-global", ".xmake", "packages")
    for _, folder in ipairs(os.filedirs(path.join(store, "*", "*", "*", "*"))) do
        if not generation_base(path.filename(folder)) and (os.islink(folder) or os.isdir(folder)) then
            local current = generations.resolve(folder)
            local members = os.islink(folder) and {folder, current} or {folder}
            local listed = entry(base, folder, "package", members)
            listed.touched = current or folder
            table.insert(found, listed)
            for _, generation in ipairs(os.dirs(folder .. ".g*")) do
                if generation ~= current then
                    local listed = entry(base, generation, "generation")
                    listed.published = folder
                    table.insert(found, listed)
                end
            end
        end
    end
end

local function dyld_entries(base, found)
    for _, folder in ipairs(os.dirs(path.join(base, "dyld", "*"))) do
        local class = kept_release(path.filename(folder)) and "kept" or "scratch"
        table.insert(found, entry(base, folder, class))
    end
end

local function firmware_entries(base, found)
    for _, folder in ipairs(os.dirs(path.join(base, "firmware", "rootfs", "*", "*"))) do
        local release = path.filename(folder):match("^(.-)_")
        local class = release and kept_release(release) and "kept" or "scratch"
        table.insert(found, entry(base, folder, class))
    end
    for _, folder in ipairs(children(path.join(base, "firmware", "work"))) do
        table.insert(found, entry(base, folder, "scratch"))
    end
    for _, folder in ipairs(children(path.join(base, "firmware"))) do
        if path.filename(folder) ~= "rootfs" and path.filename(folder) ~= "work" then
            table.insert(found, entry(base, folder, "kept"))
        end
    end
end

local function xmake_binaries(base, found)
    for _, folder in ipairs(children(path.join(base, "xmake"))) do
        local name = path.filename(folder)
        local class = (name:find(".build.", 1, true) or name:match("%.log$")) and "scratch" or "kept"
        table.insert(found, entry(base, folder, class))
    end
end

local function source_entries(base, found)
    for _, folder in ipairs(os.dirs(path.join(base, "xmake-global", ".xmake", "cache", "packages", "*", "*", "*"))) do
        table.insert(found, entry(base, folder, "source"))
    end
end

local function xmake_store(base, found)
    package_entries(base, found)
    source_entries(base, found)
    for _, folder in ipairs(children(path.join(base, "xmake-global", ".xmake"))) do
        local name = path.filename(folder)
        if name == "cache" then
            for _, cached in ipairs(children(folder)) do
                if path.filename(cached) ~= "packages" then
                    table.insert(found, entry(base, cached, "scratch"))
                end
            end
        elseif name ~= "packages" then
            table.insert(found, entry(base, folder, "kept"))
        end
    end
end

local function emulator_entries(base, found)
    for _, folder in ipairs(os.dirs(path.join(base, "emulator", "images.noindex", "*", "*"))) do
        table.insert(found, entry(base, folder, "scratch"))
    end
    for _, name in ipairs({"cache.noindex", "tmp.noindex"}) do
        for _, folder in ipairs(children(path.join(base, "emulator", name))) do
            table.insert(found, entry(base, folder, "scratch"))
        end
    end
    for _, folder in ipairs(children(path.join(base, "emulator"))) do
        local name = path.filename(folder)
        if name ~= "images.noindex" and name ~= "cache.noindex" and name ~= "tmp.noindex" then
            table.insert(found, entry(base, folder, "kept"))
        end
    end
end

local function modcache_entries(base, found)
    for _, folder in ipairs(children(path.join(base, "modcache"))) do
        table.insert(found, entry(base, folder, "scratch"))
    end
end

local function lowered_entries(base, found)
    for _, folder in ipairs(children(path.join(base, "lowered"))) do
        if not folder:endswith(".lock") then
            table.insert(found, entry(base, folder, "scratch"))
        end
    end
end

local function own_children(base)
    local found = {}
    for _, folder in ipairs(children(base)) do
        local name = path.filename(folder)
        if not (os.islink(folder) and (name == "xmake" or name == "xmake-global")) then
            table.insert(found, folder)
        end
    end
    return found
end

function entries(base)
    local found = {}
    for _, folder in ipairs(own_children(base)) do
        local name = path.filename(folder)
        if name == "scratch" then
            for _, task in ipairs(children(folder)) do
                table.insert(found, entry(base, task, "scratch"))
            end
        elseif name == "modcache" then
            modcache_entries(base, found)
        elseif name == "lowered" then
            lowered_entries(base, found)
        elseif name == "device-baselines" then
            for _, device in ipairs(children(folder)) do
                table.insert(found, entry(base, device, "kept"))
            end
        elseif name == "xmake" then
            xmake_binaries(base, found)
        elseif name == "xmake-global" then
            xmake_store(base, found)
        elseif name == "dyld" then
            dyld_entries(base, found)
        elseif name == "firmware" then
            firmware_entries(base, found)
        elseif name == "emulator" then
            emulator_entries(base, found)
        else
            table.insert(found, entry(base, folder, "kept"))
        end
    end
    local fixed = pins(base)
    for _, listed in ipairs(found) do
        listed.pinned = pinned_by(listed.members, fixed)
    end
    return found
end

local function worktrees_of(from)
    local roots = {}
    local out = try { function () return os.iorunv("git", {"-C", from, "worktree", "list", "--porcelain"}) end }
    for line in (out or ""):gmatch("[^\n]+") do
        local listed = line:match("^worktree (.+)$")
        if listed and os.isdir(listed) then
            table.insert(roots, listed)
        end
    end
    if #roots == 0 then
        table.insert(roots, from)
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

function build_outputs(from)
    local found = {}
    for _, root in ipairs(worktrees_of(checkout(from))) do
        local parents = {root}
        for _, member in ipairs(os.dirs(path.join(root, "*"))) do
            table.insert(parents, member)
        end
        for _, framework in ipairs(os.dirs(path.join(root, "frameworks", "*"))) do
            table.insert(parents, framework)
        end
        for _, parent in ipairs(parents) do
            for _, name in ipairs(BUILD_OUTPUTS) do
                local folder = path.join(parent, name)
                if os.isdir(folder) and ignored(root, folder) then
                    table.insert(found, {folder = folder, worktree = root})
                end
            end
        end
    end
    return found
end

local function build_name(build)
    return path.filename(build.worktree) .. "/" .. path.relative(build.folder, build.worktree)
end

local function build_entries(builds)
    local found = {}
    for _, build in ipairs(builds) do
        table.insert(found, {folder = build.folder, class = "build", name = build_name(build), members = {build.folder}})
    end
    return found
end

local function build_bytes(builds)
    local total = 0
    for _, build in ipairs(builds) do
        total = total + bytes_of(build.folder)
    end
    return total
end

local function held_by(members, paths)
    if not paths then
        return true
    end
    for _, member in ipairs(members) do
        local real = path.absolute(member)
        for _, name in ipairs(paths) do
            if name == real or name:startswith(real .. "/") then
                return true
            end
        end
    end
    return false
end

local function entry_bytes(listed)
    local total = 0
    for _, member in ipairs(listed.members) do
        total = total + bytes_of(member)
    end
    return total
end

function reserve(bytes, what, opt)
    opt = opt or {}
    local base = opt.root or root()
    if not opt.shared then
        refuse_store(base, "the cache to trim")
    end
    local cap = opt.limit or limit()
    local builds = opt.builds or build_outputs()
    os.mkdir(base)
    local used = bytes_of(base) + build_bytes(builds)
    if used + bytes <= cap then
        return {evicted = {}, used = used, limit = cap}
    end
    local paths = (opt.open_paths or retention.open_paths)()
    local variable = opt.variable or LIMIT_VARIABLE
    local label = opt.label or "cache"
    local all = table.join(entries(base), build_entries(builds))
    local candidates, freeable = {}, 0
    for _, listed in ipairs(all) do
        listed.bytes = entry_bytes(listed)
        if ORDER[listed.class] and not listed.pinned and not held_by(listed.members, paths) then
            table.insert(candidates, listed)
            freeable = freeable + listed.bytes
        end
    end
    if used - freeable + bytes > cap then
        table.sort(all, function (a, b) return a.bytes > b.bytes end)
        local lines = {}
        for index = 1, math.min(5, #all) do
            table.insert(lines, string.format("  %10s  %-10s %s", human(all[index].bytes), all[index].class, all[index].name))
        end
        raise("cache: %s needs %s, which would take the %s at %s and the build outputs of its worktrees past its %s cap (%s); no entry that is not in use can be evicted to make room, so nothing was removed. Biggest entries:\n%s",
              what, human(bytes), label, base, human(cap), variable, table.concat(lines, "\n"))
    end
    for _, listed in ipairs(candidates) do
        listed.used = last_used(listed.touched or listed.folder)
    end
    table.sort(candidates, function (a, b)
        if ORDER[a.class] ~= ORDER[b.class] then
            return ORDER[a.class] < ORDER[b.class]
        end
        return a.used < b.used
    end)
    local evicted = {}
    for _, listed in ipairs(candidates) do
        if used + bytes <= cap then
            break
        end
        local held = lock_members(listed.members)
        if held then
            remove(listed.members)
            unlock_members(held)
            used = used - listed.bytes
            table.insert(evicted, listed)
        end
    end
    if used + bytes > cap then
        raise("cache: %s needs %s, which would take the %s at %s past its %s cap (%s); the entries that can go were evicted and the rest is being installed or built by another process",
              what, human(bytes), label, base, human(cap), variable)
    end
    return {evicted = evicted, used = used, limit = cap}
end

function enforce(opt)
    return reserve(0, "keeping the cache within its cap", opt)
end

local function real(from)
    return retention.real_path(from or checkout())
end

local function sizes_file(base, from)
    return path.join(base, "sizes", (real(from):gsub("/", "_")))
end

local function own_bytes(from, builds)
    local selected = {}
    for _, build in ipairs(builds) do
        if build.worktree == real(from) then
            table.insert(selected, build)
        end
    end
    return build_bytes(selected)
end

function growth(from, opt)
    opt = opt or {}
    local base = opt.root or root()
    local builds = opt.builds or build_outputs(from)
    local file = sizes_file(base, from)
    local recorded = os.isfile(file) and tonumber(io.readfile(file))
    if not recorded then
        return DEFAULT_GROWTH
    end
    return math.max(0, recorded - own_bytes(from, builds))
end

function record(from, opt)
    opt = opt or {}
    local base = opt.root or root()
    local builds = opt.builds or build_outputs(from)
    local bytes = own_bytes(from, builds)
    os.mkdir(path.join(base, "sizes"))
    io.writefile(sizes_file(base, from), tostring(bytes))
    return bytes
end

function guard(from, opt)
    opt = opt or {}
    local worktree = real(from)
    local builds = opt.builds or build_outputs(worktree)
    local expected = growth(worktree, {root = opt.root, builds = builds})
    local result = reserve(expected, "the build in " .. worktree, {root = opt.root, limit = opt.limit, builds = builds})
    local shared = opt.store or store()
    local stamp = path.join(shared, STORE_STAMP)
    local interval = opt.store_interval or STORE_CHECK_SECONDS
    local function due()
        return not os.isfile(stamp) or os.time() - os.mtime(stamp) >= interval
    end
    if due() then
        exclusive.attempt(path.join(shared, STORE_TRIM_LOCK), function ()
            if not due() then
                return
            end
            try {
                function ()
                    local trimmed = reserve(0, "keeping the shared store within its cap",
                                            {root = shared, limit = opt.store_limit or store_limit(), builds = {}, variable = STORE_LIMIT_VARIABLE, label = "shared store", shared = true})
                    result.evicted = table.join(result.evicted, trimmed.evicted)
                end,
                catch {
                    function (errors)
                        result.store_error = tostring(errors)
                        print("%s", result.store_error)
                    end
                }
            }
            io.writefile(stamp, tostring(os.time()))
        end)
    end
    return result
end

local function drop(members, removed, dry, paths)
    if held_by(members, paths) then
        return
    end
    if not dry then
        local held = lock_members(members)
        if not held then
            return
        end
        remove(members)
        unlock_members(held)
    end
    table.insert(removed, members[1])
end

function prune_generations(base, opt)
    opt = opt or {}
    local removed = {}
    local paths = retention.open_paths()
    local byname = {}
    for _, listed in ipairs(entries(base)) do
        if listed.class == "generation" and not listed.pinned and not held_by(listed.members, paths) then
            byname[listed.published] = byname[listed.published] or {}
            table.insert(byname[listed.published], listed)
        end
    end
    for _, list in pairs(byname) do
        for _, listed in ipairs(list) do
            listed.used = last_used(listed.touched or listed.folder)
        end
        table.sort(list, function (a, b) return a.used > b.used end)
        for index = 2, #list do
            drop(list[index].members, removed, opt.dry, paths)
        end
    end
    return removed
end

function prune_firmware(base, opt)
    opt = opt or {}
    local removed = {}
    local paths = retention.open_paths()
    for _, folder in ipairs(os.dirs(path.join(base, "dyld", "*"))) do
        if kept_release(path.filename(folder)) then
            for _, file in ipairs(children(folder)) do
                local architecture = path.filename(file):match("_(armv%w*)$") or path.filename(file):match("_(arm64e?)$")
                if architecture and architecture ~= ARCHITECTURE then
                    drop({file}, removed, opt.dry, paths)
                end
            end
        else
            drop({folder}, removed, opt.dry, paths)
        end
    end
    for _, folder in ipairs(os.dirs(path.join(base, "firmware", "rootfs", "*", "*"))) do
        local release = path.filename(folder):match("^(.-)_")
        if not release or not kept_release(release) then
            drop({folder}, removed, opt.dry, paths)
        end
    end
    for _, folder in ipairs(children(path.join(base, "firmware", "work"))) do
        drop({folder}, removed, opt.dry, paths)
    end
    return removed
end

function prune(base, opt)
    return prune_generations(base, opt), prune_firmware(base, opt)
end

function status(base, opt)
    opt = opt or {}
    local builds = opt.builds or build_outputs()
    local rows = {}
    local paths = retention.open_paths()
    for _, listed in ipairs(table.join(entries(base), build_entries(builds))) do
        listed.bytes = entry_bytes(listed)
        listed.used = last_used(listed.touched or listed.folder)
        listed.held = held_by(listed.members, paths)
        table.insert(rows, listed)
    end
    table.sort(rows, function (a, b) return a.bytes > b.bytes end)
    return rows, bytes_of(base) + build_bytes(builds)
end

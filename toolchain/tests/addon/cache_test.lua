import("fixtures")

local MEGABYTE = 1000 * 1000
local CAP = 10 * MEGABYTE
local ROOT_VARIABLE = "REVENANT_CACHE"
local LIMIT_VARIABLE = "REVENANT_CACHE_GB"
local OLD, OLDER, OLDEST = "202001010000", "201901010000", "201801010000"
local RECENT = "202610010000"

local function with_env(name, value, action)
    local saved = os.getenv(name)
    os.setenv(name, value)
    local result
    local message = fixtures.refusal(function () result = action() end)
    os.setenv(name, saved or "")
    if message then
        raise(message)
    end
    return result
end

local function real(folder)
    return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
end

local function aged(folder, stamp)
    os.vrunv("find", {folder, "-exec", "touch", "-t", stamp, "{}", "+"})
end

local function folder_of(folder, bytes, stamp)
    os.mkdir(folder)
    io.writefile(path.join(folder, "data"), string.rep("x", bytes))
    aged(folder, stamp or RECENT)
    return folder
end

local function file_of(file, bytes)
    os.mkdir(path.directory(file))
    io.writefile(file, string.rep("x", bytes))
    return file
end

local function exists(folder)
    return os.isdir(folder) or os.isfile(folder) or os.islink(folder)
end

local function names(list, base)
    local found = {}
    for _, listed in ipairs(list.evicted) do
        table.insert(found, path.relative(listed.folder, base))
    end
    return table.concat(found, ",")
end

local function package_of(root, name)
    return path.join(root, "xmake-global", ".xmake", "packages", "t", name, "1.0", name)
end

local function source_of(root, name, bytes, stamp)
    local package = path.join(root, "xmake-global", ".xmake", "cache", "packages", "2601", name:sub(1, 1), name)
    file_of(path.join(package, "1.0", "source", "data"), bytes)
    aged(package, stamp or RECENT)
    return package
end

local function classes(list)
    local found = {}
    for _, listed in ipairs(list.evicted) do
        table.insert(found, listed.class)
    end
    return table.concat(found, ",")
end

function failures(arguments)
    local found = {}
    local cache = import("cache", {rootdir = arguments.modules, anonymous = true})
    local folder = fixtures.scratch()

    local repository = fixtures.empty_repository(folder)
    local linked = path.join(folder, "linked")
    os.vrunv("git", {"-C", repository, "worktree", "add", "-q", linked, "-b", "linked"})
    if real(cache.checkout(linked)) ~= real(repository) then
        table.insert(found, "a worktree finds the main checkout's cache: " .. cache.checkout(linked) .. " against " .. repository)
    end

    local named = path.join(folder, "named-cache")
    local root = with_env(ROOT_VARIABLE, named, function () return cache.root() end)
    if root ~= named then
        table.insert(found, "REVENANT_CACHE names the cache root: " .. tostring(root))
    end
    root = with_env(ROOT_VARIABLE, "", function () return cache.root() end)
    if root ~= path.join(cache.checkout(), ".cache") then
        table.insert(found, "without REVENANT_CACHE the cache is .cache of the main checkout: " .. tostring(root))
    end
    local repo = path.directory(path.directory(path.absolute(arguments.modules)))
    if os.execv("git", {"-C", repo, "check-ignore", "-q", ".cache/probe"}, {try = true}) ~= 0 then
        table.insert(found, ".cache is git-ignored")
    end

    local limit = with_env(LIMIT_VARIABLE, "", function () return cache.limit() end)
    if limit ~= 15 * 1000 * 1000 * 1000 then
        table.insert(found, "the cap is 15 GB by default: " .. tostring(limit))
    end
    limit = with_env(LIMIT_VARIABLE, "0.5", function () return cache.limit() end)
    if limit ~= 500 * 1000 * 1000 then
        table.insert(found, "REVENANT_CACHE_GB sets the cap in gigabytes: " .. tostring(limit))
    end
    local refusal = fixtures.refusal(function () with_env(LIMIT_VARIABLE, "many", function () return cache.limit() end) end)
    if not refusal or not refusal:find("REVENANT_CACHE_GB", 1, true) then
        table.insert(found, "a cap that is not a number is refused by name: " .. tostring(refusal))
    end

    local tree = path.join(folder, "cache")
    local package = package_of(tree, "bbb")
    file_of(path.join(tree, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    folder_of(package .. ".g1", MEGABYTE, OLDEST)
    folder_of(package .. ".g2", MEGABYTE, OLDER)
    folder_of(package .. ".g3", MEGABYTE, OLD)
    os.execv("ln", {"-s", "bbb.g3", package})
    folder_of(path.join(tree, "scratch", "old-task"), 2 * MEGABYTE, OLDER)
    folder_of(path.join(tree, "scratch", "new-task"), MEGABYTE, RECENT)

    local first = cache.reserve(2.5 * MEGABYTE, "the first write", {root = tree, limit = CAP, builds = {}})
    if names(first, tree) ~= "xmake-global/.xmake/packages/t/bbb/1.0/bbb.g1" then
        table.insert(found, "the oldest package generation goes first: " .. names(first, tree))
    end
    local second = cache.reserve(3.5 * MEGABYTE, "the second write", {root = tree, limit = CAP, builds = {}})
    if names(second, tree) ~= "xmake-global/.xmake/packages/t/bbb/1.0/bbb.g2" then
        table.insert(found, "the next generation goes before any unused package: " .. names(second, tree))
    end
    local third = cache.reserve(4.5 * MEGABYTE, "the third write", {root = tree, limit = CAP, builds = {}})
    if names(third, tree) ~= "scratch/old-task" or not exists(package) or not exists(package .. ".g3") then
        table.insert(found, "scratch goes before an installed package, which keeps its link and its generation: " .. names(third, tree))
    end
    local fourth = cache.reserve(6.5 * MEGABYTE, "the fourth write", {root = tree, limit = CAP, builds = {}})
    if names(fourth, tree) ~= "scratch/new-task" or not exists(package) then
        table.insert(found, "the remaining scratch goes before the installed package: " .. names(fourth, tree))
    end
    if not os.isfile(path.join(tree, "dyld", "6.0", "dyld_shared_cache_armv7")) then
        table.insert(found, "the shared cache of a configured release is never evicted")
    end

    local message = fixtures.refusal(function () cache.reserve(20 * MEGABYTE, "an oversized write", {root = tree, limit = CAP, builds = {}}) end)
    if not message or not message:find("an oversized write", 1, true) or not message:find("dyld/6.0", 1, true) then
        table.insert(found, "a write past the cap fails naming the write and the biggest entries: " .. tostring(message))
    end
    if not os.isfile(path.join(tree, "dyld", "6.0", "dyld_shared_cache_armv7")) or not exists(package) then
        table.insert(found, "a write past the cap removed something before it failed")
    end

    local store = path.join(folder, "generations")
    local ccc = package_of(store, "ccc")
    folder_of(ccc .. ".g1", MEGABYTE, OLDEST)
    folder_of(ccc .. ".g2", MEGABYTE, OLDER)
    folder_of(ccc .. ".g3", MEGABYTE, OLD)
    folder_of(ccc .. ".g4", MEGABYTE, RECENT)
    os.execv("ln", {"-s", "ccc.g4", ccc})
    local pruned = cache.prune_generations(store)
    if #pruned ~= 2 or exists(ccc .. ".g1") or exists(ccc .. ".g2") or not exists(ccc .. ".g3") or not exists(ccc .. ".g4") then
        table.insert(found, "the package store keeps one previous generation: " .. #pruned .. " pruned")
    end

    local firmware = path.join(folder, "firmware-cache")
    file_of(path.join(firmware, "dyld", "5.1", "dyld_shared_cache_armv7"), MEGABYTE)
    file_of(path.join(firmware, "dyld", "6.0", "dyld_shared_cache_arm64"), MEGABYTE)
    file_of(path.join(firmware, "dyld", "6.0", "dyld_shared_cache_armv7"), MEGABYTE)
    folder_of(path.join(firmware, "dyld", "6.1.3", "libraries_armv7"), MEGABYTE)
    folder_of(path.join(firmware, "firmware", "rootfs", "iPhone4,1", "5.1_9B176"), MEGABYTE)
    folder_of(path.join(firmware, "firmware", "rootfs", "iPhone4,1", "6.1.3_10B329"), MEGABYTE)
    folder_of(path.join(firmware, "firmware", "work", "iPhone4,1_10B329"), MEGABYTE)
    cache.prune_firmware(firmware)
    if exists(path.join(firmware, "dyld", "5.1")) or exists(path.join(firmware, "dyld", "6.0", "dyld_shared_cache_arm64"))
       or not os.isfile(path.join(firmware, "dyld", "6.0", "dyld_shared_cache_armv7")) or not exists(path.join(firmware, "dyld", "6.1.3"))
       or exists(path.join(firmware, "firmware", "rootfs", "iPhone4,1", "5.1_9B176"))
       or not exists(path.join(firmware, "firmware", "rootfs", "iPhone4,1", "6.1.3_10B329"))
       or exists(path.join(firmware, "firmware", "work", "iPhone4,1_10B329")) then
        table.insert(found, "the firmware keeps the configured releases for armv7 only")
    end

    local rows, total = cache.status(tree, {builds = {}})
    local kept = false
    for _, row in ipairs(rows) do
        if row.name == path.join("dyld", "6.0") and row.class == "kept" then
            kept = true
        end
    end
    if not kept or total <= 0 then
        table.insert(found, "status lists the shared cache as kept, and the total under the cache")
    end

    local outputs = fixtures.empty_repository(path.join(folder, "outputs"))
    io.writefile(path.join(outputs, ".gitignore"), "build/\n.xmake/\n")
    os.vrunv("git", {"-C", outputs, "add", ".gitignore"})
    os.vrunv("git", {"-C", outputs, "-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid", "commit", "-q", "-m", "ignore build outputs"})
    local side = path.join(folder, "side-of-outputs")
    os.vrunv("git", {"-C", outputs, "worktree", "add", "-q", side, "-b", "side"})
    local main_build = path.join(outputs, "build")
    local side_build = path.join(side, "build")
    os.mkdir(main_build)
    os.mkdir(side_build)
    local found_builds = {}
    for _, build in ipairs(cache.build_outputs(outputs)) do
        found_builds[real(build.folder)] = real(build.worktree)
    end
    if found_builds[real(main_build)] ~= real(outputs) or found_builds[real(side_build)] ~= real(side) then
        table.insert(found, "build outputs are listed per worktree, and only the ignored ones: " .. tostring(found_builds[real(side_build)]))
    end

    local wide = path.join(folder, "wide-cache")
    file_of(path.join(wide, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    local early = folder_of(path.join(folder, "early", "build"), 3 * MEGABYTE, OLDER)
    local late = folder_of(path.join(folder, "late", "build"), 3 * MEGABYTE, RECENT)
    local builds = {
        {folder = early, worktree = path.join(folder, "early")},
        {folder = late, worktree = path.join(folder, "late")},
    }
    local listed_rows, listed_total = cache.status(wide, {builds = builds})
    local listed_build = false
    for _, row in ipairs(listed_rows) do
        if row.name == "early/build" and row.class == "build" then
            listed_build = true
        end
    end
    if not listed_build or listed_total < 7 * MEGABYTE then
        table.insert(found, "status counts the build outputs of each worktree against the cap: " .. tostring(listed_total))
    end
    local shared = cache.reserve(4 * MEGABYTE, "a write beside the builds", {root = wide, limit = CAP, builds = builds})
    if names(shared, folder) ~= "early/build" or exists(early) or not exists(late) then
        table.insert(found, "the least recently used build output goes first: " .. names(shared, folder))
    end

    local full = path.join(folder, "full-cache")
    file_of(path.join(full, "dyld", "6.0", "dyld_shared_cache_armv7"), 12 * MEGABYTE)
    local overflow = fixtures.refusal(function () cache.enforce({root = full, limit = CAP, builds = {}}) end)
    if not overflow or not overflow:find("keeping the cache within its cap", 1, true) or not overflow:find("dyld/6.0", 1, true)
       or not os.isfile(path.join(full, "dyld", "6.0", "dyld_shared_cache_armv7")) then
        table.insert(found, "a cache filled past its cap by kept data fails the enforcement and removes nothing: " .. tostring(overflow))
    end

    local worktree = path.join(folder, "worktree")
    os.mkdir(worktree)
    local refused = fixtures.refusal(function () cache.guard(worktree, {root = full, limit = CAP, builds = {}}) end)
    if not refused or not refused:find("the build in", 1, true) then
        table.insert(found, "a build that cannot make its room does not start: " .. tostring(refused))
    end

    local built = path.join(folder, "built")
    os.mkdir(built)
    built = real(built)
    local output = folder_of(path.join(built, "build"), 4 * MEGABYTE)
    local recorded = cache.record(built, {root = wide, builds = {{folder = output, worktree = built}}})
    if recorded < 4 * MEGABYTE or cache.growth(built, {root = wide, builds = {{folder = output, worktree = built}}}) ~= 0
       or cache.growth(built, {root = wide, builds = {}}) ~= recorded or cache.growth(worktree, {root = wide, builds = {}}) ~= 2 * 1000 * 1000 * 1000 then
        table.insert(found, "a build expects the size its last run left, less what is already there: " .. tostring(recorded))
    end

    local emulated = path.join(folder, "emulated")
    folder_of(path.join(emulated, "emulator", "cache.noindex", "iPhone4,1_10B329"), MEGABYTE)
    folder_of(path.join(emulated, "emulator", "tmp.noindex", "old"), MEGABYTE)
    local emulator_rows = cache.status(emulated, {builds = {}})
    local scratch_cache = false
    for _, row in ipairs(emulator_rows) do
        if row.name == path.join("emulator", "cache.noindex", "iPhone4,1_10B329") and row.class == "scratch" then
            scratch_cache = true
        end
    end
    if not scratch_cache then
        table.insert(found, "a host cache of an emulator image is scratch, so the cap can evict it")
    end

    local sources = path.join(folder, "sources")
    file_of(path.join(sources, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    local installed = folder_of(package_of(sources, "bbb"), MEGABYTE, OLDEST)
    local zlib = source_of(sources, "zlib", 2 * MEGABYTE, OLDER)
    local png = source_of(sources, "png", 2 * MEGABYTE, RECENT)
    local sourced = cache.reserve(4 * MEGABYTE, "a write beside the sources", {root = sources, limit = CAP, builds = {}})
    if classes(sourced) ~= "source" or names(sourced, sources) ~= "xmake-global/.xmake/cache/packages/2601/z/zlib" or exists(zlib) or not exists(png) or not exists(installed) then
        table.insert(found, "a source tree goes before an installed package, least recently used first: " .. names(sourced, sources))
    end

    local ordered = path.join(folder, "ordered")
    file_of(path.join(ordered, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    local shipped = folder_of(package_of(ordered, "ccd"), 2 * MEGABYTE, OLDEST)
    local scratch = folder_of(path.join(ordered, "scratch", "task"), 2 * MEGABYTE, OLDER)
    local worked = path.join(folder, "worked")
    local output = folder_of(path.join(worked, "build"), 3 * MEGABYTE, OLD)
    local swept = cache.reserve(5 * MEGABYTE, "a write beside scratch and builds", {root = ordered, limit = CAP, builds = {{folder = output, worktree = worked}}})
    if classes(swept) ~= "scratch,build" or exists(scratch) or exists(output) or not exists(shipped) then
        table.insert(found, "scratch and build outputs go before an installed package: " .. classes(swept))
    end

    local last = path.join(folder, "last")
    file_of(path.join(last, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    local lone = folder_of(package_of(last, "eee"), 3 * MEGABYTE, OLDEST)
    local spare = folder_of(path.join(last, "scratch", "spare"), MEGABYTE, OLDER)
    local origin = source_of(last, "origin", MEGABYTE, RECENT)
    local unfit = fixtures.refusal(function () cache.reserve(9 * MEGABYTE, "a write past every entry", {root = last, limit = CAP, builds = {}}) end)
    if not unfit or not unfit:find("a write past every entry", 1, true) or not exists(lone) or not exists(spare) or not exists(origin) then
        table.insert(found, "a write that nothing can make room for removes no installed package: " .. tostring(unfit))
    end
    local every = cache.reserve(7.5 * MEGABYTE, "a write that needs every entry", {root = last, limit = CAP, builds = {}})
    if classes(every) ~= "source,scratch,package" or exists(lone) or exists(origin) or exists(spare)
       or not os.isfile(path.join(last, "dyld", "6.0", "dyld_shared_cache_armv7")) then
        table.insert(found, "an installed package is evicted only after the source, scratch and build entries: " .. classes(every))
    end

    local left = path.join(folder, "left")
    file_of(path.join(left, "dyld", "6.0", "dyld_shared_cache_armv7"), 2 * MEGABYTE)
    local leaving = package_of(left, "ggg")
    folder_of(leaving .. ".g1", MEGABYTE, OLDEST)
    file_of(leaving .. ".g1.lock", 0)
    folder_of(leaving .. ".g2", MEGABYTE, OLD)
    file_of(leaving .. ".g2.lock", 0)
    os.execv("ln", {"-s", "ggg.g2", leaving})
    file_of(leaving .. ".lock", 0)
    local gone = cache.reserve(7.5 * MEGABYTE, "a write that evicts a package", {root = left, limit = CAP, builds = {}})
    local remnants = {}
    for _, item in ipairs({leaving, leaving .. ".g1", leaving .. ".g2", leaving .. ".lock", leaving .. ".g1.lock", leaving .. ".g2.lock",
                           path.join(left, "xmake-global", ".xmake", "packages", "t", "ggg")}) do
        if exists(item) then
            table.insert(remnants, path.relative(item, left))
        end
    end
    if classes(gone) ~= "generation,package" or #remnants > 0 or not os.isfile(path.join(left, "dyld", "6.0", "dyld_shared_cache_armv7")) then
        table.insert(found, "an evicted package leaves no published path, generation, lock or empty folder: " .. classes(gone) .. " " .. table.concat(remnants, ","))
    end

    os.tryrm(folder)
    return found
end

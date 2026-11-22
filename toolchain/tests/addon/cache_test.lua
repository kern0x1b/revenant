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
    if limit ~= 50 * 1000 * 1000 * 1000 then
        table.insert(found, "the cap is 50 GB by default: " .. tostring(limit))
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

    local models = path.join(folder, "models")
    folder_of(path.join(models, "modcache", "old-sdk"), MEGABYTE, OLDER)
    local model_scratch = false
    for _, row in ipairs(cache.status(models, {builds = {}})) do
        if row.name == path.join("modcache", "old-sdk") and row.class == "scratch" then
            model_scratch = true
        end
    end
    if not model_scratch then
        table.insert(found, "a module cache of one SDK is scratch, so the cap can evict it")
    end

    local compiled = path.join(folder, "compiled")
    folder_of(path.join(compiled, "ccache", "cache"), MEGABYTE, OLDER)
    folder_of(path.join(compiled, "ccache", "shim", "0123"), 1, OLDER)
    local compiled_classes = {}
    for _, row in ipairs(cache.status(compiled, {builds = {}})) do
        compiled_classes[row.name] = row.class
    end
    if compiled_classes[path.join("ccache", "cache")] ~= "scratch" or compiled_classes[path.join("ccache", "shim")] ~= "kept" then
        table.insert(found, "the objects of the compile cache are scratch, so the cap can evict them, and its shims are kept, because a running build executes them: "
                            .. tostring(compiled_classes[path.join("ccache", "cache")]) .. ", " .. tostring(compiled_classes[path.join("ccache", "shim")]))
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

    local named_store = path.join(folder, "named-store")
    local shared_root = with_env("REVENANT_STORE", named_store, function () return cache.store() end)
    if shared_root ~= named_store then
        table.insert(found, "REVENANT_STORE names the shared store: " .. tostring(shared_root))
    end
    shared_root = with_env("REVENANT_STORE", "", function () return cache.store() end)
    if shared_root ~= path.join(os.getenv("HOME"), ".revenant", "store") then
        table.insert(found, "without REVENANT_STORE the shared store is ~/.revenant/store: " .. tostring(shared_root))
    end
    local relative = fixtures.refusal(function () with_env("REVENANT_STORE", "relative/store", function () return cache.store() end) end)
    if not relative or not relative:find("REVENANT_STORE", 1, true) then
        table.insert(found, "a relative REVENANT_STORE is refused by name: " .. tostring(relative))
    end
    if with_env("REVENANT_STORE_GB", "", function () return cache.store_limit() end) ~= 80 * 1000 * 1000 * 1000
       or with_env("REVENANT_STORE_GB", "0.5", function () return cache.store_limit() end) ~= 500 * 1000 * 1000 then
        table.insert(found, "the store's cap is 80 GB by default and REVENANT_STORE_GB sets it")
    end

    local shared = path.join(folder, "shared")
    local pinned_package = package_of(shared, "ppp")
    folder_of(pinned_package .. ".g1", MEGABYTE, OLDEST)
    folder_of(pinned_package .. ".g2", MEGABYTE, OLDER)
    folder_of(pinned_package .. ".g3", MEGABYTE, OLD)
    folder_of(pinned_package .. ".g4", MEGABYTE, RECENT)
    os.execv("ln", {"-s", "ppp.g4", pinned_package})
    local roots = path.join(shared, "roots")
    os.mkdir(roots)
    io.writefile(path.join(roots, "telegram-build.txt"), "# the installs the Bazel build links\n\nt/ppp/1.0/ppp.g1  \n")
    local kept = cache.prune_generations(shared)
    if #kept ~= 1 or exists(pinned_package .. ".g2") or not exists(pinned_package .. ".g1") or not exists(pinned_package .. ".g3") or not exists(pinned_package .. ".g4") then
        table.insert(found, "pruning generations keeps the oldest one a roots file names, and removes the others: " .. #kept .. " pruned")
    end

    local fixed = package_of(shared, "qqq")
    folder_of(fixed .. ".g1", 2 * MEGABYTE, OLDEST)
    os.execv("ln", {"-s", "qqq.g1", fixed})
    local loose = package_of(shared, "rrr")
    folder_of(loose .. ".g1", 2 * MEGABYTE, OLD)
    os.execv("ln", {"-s", "rrr.g1", loose})
    io.writefile(path.join(roots, "another-checkout.txt"), "t/qqq/1.0/qqq\n")
    local pinned_rows = cache.status(shared, {builds = {}})
    local pinned_names = {}
    for _, row in ipairs(pinned_rows) do
        if row.pinned then
            table.insert(pinned_names, row.name)
        end
    end
    table.sort(pinned_names)
    if table.concat(pinned_names, ",") ~= "xmake-global/.xmake/packages/t/ppp/1.0/ppp.g1,xmake-global/.xmake/packages/t/qqq/1.0/qqq" then
        table.insert(found, "status marks what the roots files pin, a generation by its name and a package by its published path: " .. table.concat(pinned_names, ","))
    end
    local trimmed = cache.reserve(3.5 * MEGABYTE, "a write into the shared store", {root = shared, limit = 8 * MEGABYTE, builds = {}})
    if classes(trimmed) ~= "generation,package" or exists(loose) or not exists(fixed) or not exists(pinned_package .. ".g1") then
        table.insert(found, "an eviction from the store takes the install no roots file names, and keeps the pinned ones: " .. classes(trimmed))
    end
    local blocked = fixtures.refusal(function () cache.reserve(20 * MEGABYTE, "a write that needs the pinned installs", {root = shared, limit = 8 * MEGABYTE, builds = {}}) end)
    if not blocked or not exists(fixed) or not exists(pinned_package .. ".g1") then
        table.insert(found, "a write that would need a pinned install fails and removes nothing of it: " .. tostring(blocked))
    end

    local overlays = path.join(folder, "overlay-store")
    local stale = folder_of(path.join(overlays, "lowered", "aaaa"), 2 * MEGABYTE, OLDEST)
    local fresh = folder_of(path.join(overlays, "lowered", "bbbb"), 2 * MEGABYTE, RECENT)
    local stale_lock = file_of(path.join(overlays, "lowered", "aaaa.lock"), 0)
    local unpinned = package_of(overlays, "sss")
    folder_of(unpinned, 2 * MEGABYTE, OLD)
    local overlay_rows = {}
    for _, row in ipairs(cache.status(overlays, {builds = {}})) do
        overlay_rows[row.name] = row.class
    end
    if overlay_rows["lowered/aaaa"] ~= "scratch" or overlay_rows["lowered/bbbb"] ~= "scratch" or overlay_rows["lowered/aaaa.lock"] then
        table.insert(found, "each overlay folder under the store's lowered/ is an entry that can be evicted, and its lock file is a member of it, not an entry: " .. tostring(overlay_rows["lowered/aaaa"]) .. ", " .. tostring(overlay_rows["lowered/aaaa.lock"]))
    end
    local made_room
    local not_made = fixtures.refusal(function ()
        made_room = cache.reserve(3.5 * MEGABYTE, "a write into the shared store", {root = overlays, limit = 6 * MEGABYTE, builds = {}})
    end)
    if not_made or classes(made_room) ~= "scratch,scratch" or exists(stale) or exists(fresh) or not exists(unpinned) or exists(stale_lock) then
        table.insert(found, "an eviction from the store takes the overlays, oldest first, with their locks, before any installed package: " .. tostring(not_made or classes(made_room)))
    end

    stale = folder_of(path.join(overlays, "lowered", "aaaa"), 2 * MEGABYTE, OLDEST)
    fresh = folder_of(path.join(overlays, "lowered", "bbbb"), 2 * MEGABYTE, OLD)
    stale_lock = file_of(path.join(overlays, "lowered", "aaaa.lock"), 0)
    local building = io.openlock(stale_lock)
    if not building or not building:trylock() then
        table.insert(found, "the test could not take the lock of an overlay that is being built")
    else
        local kept_building
        local failed = fixtures.refusal(function ()
            kept_building = cache.reserve(3.5 * MEGABYTE, "a write into the shared store", {root = overlays, limit = 6 * MEGABYTE, builds = {}})
        end)
        building:unlock()
        building:close()
        if failed or classes(kept_building) ~= "scratch,package" or not exists(stale) or exists(fresh) or exists(unpinned) then
            table.insert(found, "an eviction from the store leaves the overlay whose lock another process holds, and takes the next entries: " .. tostring(failed or classes(kept_building)))
        end
    end

    local home = path.join(folder, "linking-cache")
    os.mkdir(home)
    file_of(path.join(home, "dyld", "6.0", "dyld_shared_cache_armv7"), MEGABYTE)
    os.vrunv("ln", {"-s", path.join(shared, "xmake-global"), path.join(home, "xmake-global")})
    os.vrunv("ln", {"-s", path.join(shared, "xmake"), path.join(home, "xmake")})
    for _, row in ipairs(cache.status(home, {builds = {}})) do
        if row.name:find("xmake", 1, true) then
            table.insert(found, "a cache that links to the shared store does not list or count its packages as its own: " .. row.name)
        end
    end
    local _, own_total = cache.status(home, {builds = {}})
    if own_total > 2 * MEGABYTE then
        table.insert(found, "the size of a cache that links to the shared store is its own: " .. own_total)
    end

    local guarded = fixtures.empty_repository(path.join(folder, "guarded"))
    cache.record(guarded, {root = home, builds = {}})
    local early = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = shared, store_limit = 3.5 * MEGABYTE, store_interval = 3600})
    local store_trimmed = #early.evicted > 0
    if not store_trimmed or not exists(path.join(shared, cache.store_stamp())) then
        table.insert(found, "guard keeps the shared store within its cap and records when it did")
    end
    folder_of(package_of(shared, "sss") .. ".g1", 6 * MEGABYTE, OLD)
    os.execv("ln", {"-s", "sss.g1", package_of(shared, "sss")})
    local again = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = shared, store_limit = 3.5 * MEGABYTE, store_interval = 3600})
    if #again.evicted > 0 or not exists(package_of(shared, "sss")) then
        table.insert(found, "guard looks at the shared store once in its interval, not before every build")
    end
    local after = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = shared, store_limit = 3.5 * MEGABYTE, store_interval = 0})
    if #after.evicted == 0 then
        table.insert(found, "guard looks at the shared store again when the interval has passed")
    end

    local capped = path.join(folder, "capped-store")
    folder_of(package_of(capped, "aaa"), 6 * MEGABYTE, OLD)
    file_of(path.join(capped, "roots", "all.txt"), 10)
    io.writefile(path.join(capped, "roots", "all.txt"), "t/aaa/1.0/aaa\n")
    local unbound
    local stopped = fixtures.refusal(function ()
        unbound = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = capped, store_limit = 3 * MEGABYTE, store_interval = 0})
    end)
    if stopped then
        table.insert(found, "a store that nothing in it can be evicted from does not stop the build of a worktree that has room: " .. stopped)
    elseif not unbound.store_error or not unbound.store_error:find("REVENANT_STORE_GB", 1, true) or unbound.store_error:find("REVENANT_CACHE_GB", 1, true) then
        table.insert(found, "the store's own cap is the one the report names: " .. tostring(unbound.store_error))
    end
    if not exists(package_of(capped, "aaa")) then
        table.insert(found, "the pinned install stays when the store cannot be brought under its cap")
    end

    local leased = path.join(folder, "leased-store")
    for _, name in ipairs({"bbb", "ccc", "ddd"}) do
        folder_of(package_of(leased, name), 3 * MEGABYTE, name == "ccc" and OLDER or OLD)
    end
    local installing = io.openlock(file_of(package_of(leased, "ccc") .. ".lock", 1))
    installing:lock()
    local stale_snapshot = function () return {} end
    cache.reserve(3.5 * MEGABYTE, "a write while ccc is being installed", {root = leased, limit = 8 * MEGABYTE, builds = {}, open_paths = stale_snapshot})
    if not exists(package_of(leased, "ccc")) then
        table.insert(found, "an install that holds its lock is not evicted, even when the list of open files was taken before it took the lock")
    end
    if exists(package_of(leased, "bbb")) or exists(package_of(leased, "ddd")) then
        table.insert(found, "the entries nobody holds are evicted instead of the one that is held")
    end
    installing:unlock()
    installing:close()
    folder_of(package_of(leased, "eee"), 3 * MEGABYTE, OLD)
    cache.reserve(3.5 * MEGABYTE, "a write after ccc was installed", {root = leased, limit = 8 * MEGABYTE, builds = {}, open_paths = stale_snapshot})
    if exists(package_of(leased, "ccc")) then
        table.insert(found, "an install whose lock is free is evicted again")
    end

    local trimming = path.join(folder, "trimming-store")
    folder_of(package_of(trimming, "fff"), 6 * MEGABYTE, OLD)
    local other = io.openlock(file_of(path.join(trimming, ".trim.lock"), 1))
    other:lock()
    local skipped = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = trimming, store_limit = 3 * MEGABYTE, store_interval = 0})
    if #skipped.evicted > 0 or not exists(package_of(trimming, "fff")) or exists(path.join(trimming, cache.store_stamp())) then
        table.insert(found, "a process that finds another trimming the store leaves the trim to it and does not record one")
    end
    other:unlock()
    other:close()
    local trimmed_here = cache.guard(guarded, {root = home, limit = CAP, builds = {}, store = trimming, store_limit = 3 * MEGABYTE, store_interval = 0})
    if #trimmed_here.evicted == 0 or exists(package_of(trimming, "fff")) then
        table.insert(found, "the trim runs once the other process has finished")
    end

    os.tryrm(folder)
    return found
end

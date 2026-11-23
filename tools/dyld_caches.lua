local caches = import("@addon.revenant.apple.dyld_caches", {anonymous = true})

local USAGE = [=[usage: ./xmakew l -P . tools/dyld_caches.lua [clone | test]

clone  (the default) gives this checkout every device cache a checkout of this repository holds and this one lacks: each
       release folder of a .cache*/dyld folder of the main checkout or of another worktree is cloned copy-on-write
       into this checkout's .cache/dyld; a folder this checkout already has is left alone, and so is one that holds no cache
test   runs the checks of the cloning on fixtures]=]

local function lines_of(cloned, skipped)
    local lines = {}
    for _, entry in ipairs(cloned) do
        table.insert(lines, string.format("dyld caches: cloned iOS %s from %s (copy on write, no disk)", entry.release, entry.from))
    end
    for _, release in ipairs(table.orderkeys(skipped)) do
        table.insert(lines, string.format("dyld caches: %s holds no cache, so iOS %s was not cloned over it; remove the folder to clone it", skipped[release], release))
    end
    if #lines == 0 then
        table.insert(lines, "dyld caches: nothing to clone, this checkout holds every cache the others hold")
    end
    return lines
end

local function report(cloned, skipped)
    for _, line in ipairs(lines_of(cloned, skipped)) do
        print("%s", line)
    end
end

local function write(file, text)
    os.mkdir(path.directory(file))
    io.writefile(file, text)
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local base = path.join(os.tmpdir(), "dyld-caches-" .. hash.uuid())
    os.mkdir(base)
    local function cache(folder, release, files)
        for name, text in pairs(files) do
            write(path.join(base, folder, release, name), text)
        end
    end
    local function names(entries)
        local found = {}
        for _, entry in ipairs(entries) do
            table.insert(found, entry.release)
        end
        table.sort(found)
        return table.concat(found, " ")
    end
    local function exists(folder, release, name)
        return os.isfile(path.join(base, folder, release, name))
    end

    check("a shared cache without its source note is not complete, the harvest has not finished", (function () cache("m", "6.0", {dyld_shared_cache_armv7 = "a"}) return caches.complete(path.join(base, "m", "6.0")) end)(), false)
    check("a folder with a shared cache and its source note is complete", (function () cache("m", "6.0", {["dyld_shared_cache_armv7.source"] = "iPhone a"}) return caches.complete(path.join(base, "m", "6.0")) end)(), true)
    check("a folder with only the source note is not", (function () cache("m", "7.0", {["dyld_shared_cache_armv7.source"] = "x"}) return caches.complete(path.join(base, "m", "7.0")) end)(), false)
    check("a folder with a libraries folder is complete", (function () cache("m", "2.0", {["libraries_armv7/libSystem.dylib"] = "l"}) return caches.complete(path.join(base, "m", "2.0")) end)(), true)
    check("a folder that does not exist is not", caches.complete(path.join(base, "m", "9.9")), false)

    local listing = table.concat({"worktree /a/main", "HEAD 1111", "detached", "", "worktree /a/main/.claude/worktrees/one", "HEAD 2222", "branch refs/heads/x", ""}, "\n")
    local listed = caches.worktrees(listing)
    check("the listing names every worktree, the main one first", table.concat(listed, " "), "/a/main /a/main/.claude/worktrees/one")

    os.mkdir(path.join(base, "main", ".cache", "dyld"))
    os.mkdir(path.join(base, "wt", ".cache", "dyld"))
    os.mkdir(path.join(base, "wt", ".cache-pp", "dyld"))
    os.mkdir(path.join(base, "wt", ".cache-pp", "other"))
    os.mkdir(path.join(base, "bare"))
    local own = path.join(base, "wt", ".cache", "dyld")
    local order = caches.sources(own, table.concat({"worktree " .. path.join(base, "main"), "worktree " .. path.join(base, "wt"), "worktree " .. path.join(base, "bare")}, "\n"))
    local relative = {}
    for _, folder in ipairs(order) do
        table.insert(relative, path.relative(folder, base))
    end
    check("the sources are the main checkout's caches, then the others', and never this one", table.concat(relative, " "), path.join("main", ".cache", "dyld") .. " " .. path.join("wt", ".cache-pp", "dyld"))

    cache("a", "6.0", {dyld_shared_cache_armv7 = "from a", ["dyld_shared_cache_armv7.source"] = "iPhone a", ["classes_armv7.json"] = "{a}", ["outside_armv7/libX.dylib"] = "x"})
    cache("a", "6.1.3", {dyld_shared_cache_armv7 = "a 613", ["dyld_shared_cache_armv7.source"] = "iPhone a"})
    cache("a", "7.0", {["dyld_shared_cache_armv7.source"] = "partial"})
    cache("a", ".hidden", {dyld_shared_cache_armv7 = "hidden"})
    cache("b", "6.0", {dyld_shared_cache_armv7 = "from b", ["dyld_shared_cache_armv7.source"] = "iPhone b"})
    cache("b", "5.0", {["libraries_armv7/libSystem.dylib"] = "old"})
    cache("b", "7.0", {dyld_shared_cache_armv7 = "b 70", ["dyld_shared_cache_armv7.source"] = "iPhone b"})
    cache("b", "8.0", {dyld_shared_cache_armv7 = "unfinished"})
    cache("here", "6.1.3", {dyld_shared_cache_armv7 = "mine", ["dyld_shared_cache_armv7.source"] = "iPhone here"})
    cache("here", "7.0", {["notes.txt"] = "unfinished"})
    local here = path.join(base, "here")
    local sources = {path.join(base, "a"), path.join(base, "b")}
    local before = caches.identity(here)
    local cloned, skipped = caches.provision({here = here, sources = sources})
    check("the releases this checkout lacked were cloned, each from the first source that held it", names(cloned), "5.0 6.0")
    check("a release both sources hold comes from the first source", io.readfile(path.join(here, "6.0", "dyld_shared_cache_armv7")), "from a")
    check("the whole release folder is cloned, its inventory and outside libraries too", exists("here", "6.0", "classes_armv7.json") and exists("here", "6.0", "outside_armv7/libX.dylib"), true)
    check("an old release with a libraries folder is cloned", exists("here", "5.0", "libraries_armv7/libSystem.dylib"), true)
    check("a release this checkout already holds is left as it is", io.readfile(path.join(here, "6.1.3", "dyld_shared_cache_armv7")), "mine")
    check("a release a source holds without a cache is not cloned", os.exists(path.join(here, "7.0", "dyld_shared_cache_armv7.source")), false)
    check("a folder of this checkout that holds no cache is reported and left alone", skipped["7.0"] == path.join(here, "7.0") and exists("here", "7.0", "notes.txt"), true)
    check("a hidden folder is not a release", os.exists(path.join(here, ".hidden")), false)
    check("no staging folder is left behind", #os.dirs(path.join(base, ".dyld-clone-*")), 0)
    local again = caches.provision({here = here, sources = sources})
    check("a second run clones nothing", #again, 0)
    check("a release whose harvest has not finished is not cloned", os.exists(path.join(here, "8.0")), false)
    check("a warm run says that there is nothing to clone", table.concat(lines_of(again, {}), "\n"), "dyld caches: nothing to clone, this checkout holds every cache the others hold")
    check("a skipped folder is named, with its release", table.concat(lines_of({}, {["7.0"] = "/x/7.0"}), "\n"):find("/x/7.0 holds no cache, so iOS 7.0 was not cloned over it", 1, true) ~= nil, true)
    check("a cloned release is named with its source", table.concat(lines_of({{release = "6.0", from = "/y"}}, {}), "\n"), "dyld caches: cloned iOS 6.0 from /y (copy on write, no disk)")
    local stale, fresh = path.join(base, ".dyld-clone-stale"), path.join(base, ".dyld-clone-fresh")
    os.mkdir(stale)
    os.mkdir(fresh)
    os.vrunv("touch", {"-t", "200001010000", stale})
    caches.provision({here = here, sources = sources})
    check("a staging folder left long ago is removed", os.isdir(stale), false)
    check("a recent staging folder is left to the process that made it", os.isdir(fresh), true)
    local after = caches.identity(here)
    check("the identity changes when a release arrives", before ~= after, true)
    check("the identity of the same content is the same", caches.identity(here), after)
    write(path.join(here, "6.0", "classes_armv7.json"), "{changed}")
    check("the identity changes when a file of a release changes", caches.identity(here) ~= after, true)
    check("the identity names the release and the file", caches.identity(here):find("6.0 classes_armv7.json", 1, true) ~= nil, true)
    check("an incomplete folder is not part of the identity", caches.identity(here):find("7.0", 1, true) == nil, true)

    os.tryrm(base)
    print("dyld_caches: %d tests passed", count)
end

function main(command)
    if command == "test" then
        test_suite()
        return
    end
    if command and command ~= "clone" then
        raise("%s", USAGE)
    end
    report(caches.provision())
end

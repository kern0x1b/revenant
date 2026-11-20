import("fixtures")
import("core.base.bytes")

local COMMIT = string.rep("ab", 20)
local RECIPE = "package(\"xmake\")\n    add_urls(\"file:///nonexistent/xmake.git\")\n    add_versions(\"v0\", \"" .. COMMIT .. "\")\n"
local STUB = "#!/bin/sh\necho \"globaldir=$XMAKE_GLOBALDIR store=$REVENANT_STORE cache=$REVENANT_CACHE args=$*\" >> \"$STUB_LOG\"\n"

local function git(folder, arguments)
    os.vrunv("git", table.join({"-C", folder, "-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid"}, arguments))
end

local function checkout_of(folder, launcher)
    local root = path.join(folder, "checkout")
    os.mkdir(path.join(root, "packages", "x", "xmake"))
    local script = path.join(root, "xmakew")
    os.cp(launcher, script)
    os.vrunv("chmod", {"755", script})
    io.writefile(path.join(root, "packages", "x", "xmake", "xmake.lua"), RECIPE)
    git(root, {"init", "-q"})
    git(root, {"symbolic-ref", "HEAD", "refs/heads/master"})
    git(root, {"add", "-A"})
    git(root, {"commit", "-q", "-m", "launcher"})
    return root
end

local function store_with_xmake(folder, launcher)
    local store = path.join(folder, "store")
    local key = hash.sha256(bytes(COMMIT .. "\n\n" .. io.readfile(launcher))):sub(1, 16)
    local binary = path.join(store, "xmake", key, "bin", "xmake")
    os.mkdir(path.directory(binary))
    io.writefile(binary, STUB)
    os.vrunv("chmod", {"755", binary})
    return store
end

local function launch(root, envs, log)
    local status = os.execv(path.join(root, "xmakew"), {"l", "-P", root, "probe.lua"},
                            {try = true, curdir = root, stdout = log, stderr = log, envs = envs})
    return status, io.readfile(log) or ""
end

local function real(folder)
    return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
end

local function target(link)
    return os.islink(link) and os.iorunv("readlink", {link}):trim() or nil
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local launcher = path.join(path.directory(path.directory(path.absolute(opt.modules))), "xmakew")
    local root = checkout_of(folder, launcher)
    local store = store_with_xmake(folder, launcher)
    local trail = path.join(folder, "trail.txt")
    local log = path.join(folder, "launch.log")
    local function envs(cache, extra)
        return table.join({REVENANT_STORE = store, REVENANT_CACHE = cache or "", STUB_LOG = trail}, extra or {})
    end

    local main_cache = path.join(root, ".cache")
    local status, output = launch(root, envs(), log)
    if status ~= 0 then
        table.insert(found, "the main checkout starts with the xmake of the shared store: " .. output)
    end
    local ran = os.isfile(trail) and io.readfile(trail) or ""
    if ran:find("globaldir=" .. store .. "/xmake-global ", 1, true) == nil then
        table.insert(found, "xmake runs with XMAKE_GLOBALDIR in the shared store: " .. ran)
    end
    for _, part in ipairs({"xmake", "xmake-global"}) do
        if target(path.join(main_cache, part)) ~= path.join(store, part) then
            table.insert(found, "the cache holds a link to " .. part .. " of the shared store: " .. tostring(target(path.join(main_cache, part))))
        end
    end

    local linked = path.join(folder, "linked")
    git(root, {"worktree", "add", "-q", linked, "-b", "linked"})
    status, output = launch(linked, envs(), log)
    if status ~= 0 then
        table.insert(found, "a linked worktree without REVENANT_CACHE starts, with a cache of its own: " .. output)
    end
    if target(path.join(linked, ".cache", "xmake-global")) ~= path.join(store, "xmake-global") then
        table.insert(found, "a linked worktree's own cache links to the shared store: " .. tostring(target(path.join(linked, ".cache", "xmake-global"))))
    end
    if os.isdir(path.join(main_cache, "scratch")) and real(path.join(linked, ".cache")) == real(main_cache) then
        table.insert(found, "a linked worktree does not fall back to the main checkout's cache")
    end

    local fresh = path.join(folder, "fresh-cache")
    status, output = launch(linked, envs(fresh), log)
    if status ~= 0 then
        table.insert(found, "an empty folder with no marker is a cache of a linked worktree, whose packages are in the store: " .. output)
    end
    if target(path.join(fresh, "xmake-global")) ~= path.join(store, "xmake-global") then
        table.insert(found, "the empty cache links to the shared store")
    end

    local legacy = path.join(folder, "legacy-cache")
    os.mkdir(path.join(legacy, "xmake-global", ".xmake", "packages"))
    status, output = launch(linked, envs(legacy), log)
    if status == 0 or not output:find("tools/private_cache.lua " .. store .. " --from " .. legacy, 1, true) then
        table.insert(found, "a cache with a package store of its own is refused with the command that makes it the shared store: " .. output)
    end
    if os.isdir(path.join(legacy, "xmake-global", ".xmake", "packages")) == false then
        table.insert(found, "the refusal leaves the package store of the old cache in place")
    end

    status, output = launch(linked, envs(path.join(folder, "relative-store-cache"), {REVENANT_STORE = "relative/store"}), log)
    if status == 0 or not output:find("not an absolute path", 1, true) then
        table.insert(found, "a relative REVENANT_STORE is refused: " .. output)
    end

    os.tryrm(folder)
    return found
end

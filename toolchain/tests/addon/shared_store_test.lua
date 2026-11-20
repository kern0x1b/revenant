import("fixtures")
import("core.base.bytes")
import("core.base.process")

local COMMIT = string.rep("ab", 20)
local RECIPE = "package(\"xmake\")\n    add_urls(\"file:///nonexistent/xmake.git\")\n    add_versions(\"v0\", \"" .. COMMIT .. "\")\n"
local STUB = "#!/bin/sh\necho \"globaldir=$XMAKE_GLOBALDIR store=$REVENANT_STORE cache=$REVENANT_CACHE args=$*\" >> \"$STUB_LOG\"\n"
local PROJECT = "add_addons(\"revenant\", {sourcedir = \"toolchain\"})\n"

local function git(folder, arguments)
    os.vrunv("git", table.join({"-C", folder, "-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid"}, arguments))
end

local function checkout_of(folder, repository, recipe)
    local root = path.join(folder, "checkout")
    os.mkdir(path.join(root, "packages", "x", "xmake"))
    os.mkdir(path.join(root, "tools"))
    local script = path.join(root, "xmakew")
    os.cp(path.join(repository, "xmakew"), script)
    os.vrunv("chmod", {"755", script})
    os.cp(path.join(repository, "tools", "private_cache.lua"), path.join(root, "tools", "private_cache.lua"))
    os.ln(path.join(repository, "toolchain"), path.join(root, "toolchain"))
    io.writefile(path.join(root, "xmake.lua"), PROJECT)
    io.writefile(path.join(root, "packages", "x", "xmake", "xmake.lua"), recipe or RECIPE)
    git(root, {"init", "-q"})
    git(root, {"symbolic-ref", "HEAD", "refs/heads/master"})
    git(root, {"add", "-A"})
    git(root, {"commit", "-q", "-m", "launcher"})
    return root
end

local function key_of(commit, launcher)
    return hash.sha256(bytes(commit .. "\n\n" .. io.readfile(launcher))):sub(1, 16)
end

local function stub_into(store, commit, launcher)
    local binary = path.join(store, "xmake", key_of(commit, launcher), "bin", "xmake")
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

local function exists(file)
    return os.isdir(file) or os.isfile(file) or os.islink(file)
end

local function upstream_of(folder)
    local source = path.join(folder, "upstream")
    os.mkdir(path.join(source, "core", "src", "lua", "lua"))
    io.writefile(path.join(source, "core", "src", "lua", "lua", "main.c"), "#include \"lua.h\"\nint main(void) { return LUA_FIXTURE; }\n")
    io.writefile(path.join(source, "core", "src", "lua", "lua", "lua.h"), "#define LUA_FIXTURE 0\n")
    io.writefile(path.join(source, "configure"), table.concat({
        "#!/bin/sh",
        "for argument in \"$@\"; do",
        "    case $argument in --prefix=*) prefix=${argument#--prefix=} ;; esac",
        "done",
        "echo \"PREFIX = $prefix\" > config.mk",
        "echo configured >> \"$BUILD_COUNTER\"",
        ""
    }, "\n"))
    os.vrunv("chmod", {"755", path.join(source, "configure")})
    io.writefile(path.join(source, "Makefile"), table.concat({
        "include config.mk",
        "all:",
        "\tsleep $${BUILD_SECONDS:-3}",
        "install:",
        "\tmkdir -p $(PREFIX)/bin",
        "\tprintf '#!/bin/sh\\n' > $(PREFIX)/bin/xmake",
        "\tchmod 755 $(PREFIX)/bin/xmake",
        ""
    }, "\n"))
    git(source, {"init", "-q"})
    git(source, {"add", "-A"})
    git(source, {"commit", "-q", "-m", "xmake"})
    return "file://" .. source, os.iorunv("git", {"-C", source, "rev-parse", "HEAD"}):trim()
end

local function spawn(folder, root, envs, name)
    local done = path.join(folder, name .. ".done")
    local log = path.join(folder, name .. ".log")
    local wrapper = path.join(folder, name .. ".sh")
    io.writefile(wrapper, "#!/bin/sh\n\"$@\"\necho $? > \"$DONE\"\n")
    os.vrunv("chmod", {"755", wrapper})
    local environment = {}
    for key, value in pairs(table.join(os.getenvs(), envs, {DONE = done})) do
        table.insert(environment, key .. "=" .. value)
    end
    local child = process.openv(wrapper, {path.join(root, "xmakew"), "l", "-P", root, "probe.lua"},
                                {envs = environment, curdir = root, stdout = log, stderr = log})
    return {child = child, done = done, log = log}
end

local function waited_for(file, limit)
    local waited = 0
    while not os.isfile(file) and waited < limit do
        os.sleep(100)
        waited = waited + 100
    end
    return os.isfile(file)
end

local function finish(run, limit)
    local ended = waited_for(run.done, limit)
    run.child:close()
    return ended and io.readfile(run.done):trim() or nil, io.readfile(run.log) or ""
end

local function count_lines(file)
    local count = 0
    for _ in (io.readfile(file) or ""):gmatch("[^\n]+") do
        count = count + 1
    end
    return count
end

local function concurrent_builds(folder, repository, found)
    local url, commit = upstream_of(folder)
    local recipe = "package(\"xmake\")\n    add_urls(\"" .. url .. "\")\n    add_versions(\"v0\", \"" .. commit .. "\")\n"
    local race = path.join(folder, "race")
    os.mkdir(race)
    local root = checkout_of(race, repository, recipe)
    local store = path.join(race, "store")
    local counter = path.join(race, "builds.txt")
    local envs = {REVENANT_STORE = store, BUILD_COUNTER = counter, STUB_LOG = path.join(race, "trail.txt")}
    local first = spawn(race, root, table.join(envs, {REVENANT_CACHE = path.join(race, "cache-a")}), "a")
    if not waited_for(counter, 120000) then
        table.insert(found, "the first launcher did not start building the xmake: " .. (io.readfile(first.log) or ""))
    end
    local second = spawn(race, root, table.join(envs, {REVENANT_CACHE = path.join(race, "cache-b")}), "b")
    local first_status, first_log = finish(first, 120000)
    local second_status, second_log = finish(second, 120000)
    if first_status ~= "0" or second_status ~= "0" then
        local logs = {}
        for _, kept in ipairs(os.files(path.join(store, "xmake", "*.log"))) do
            table.insert(logs, io.readfile(kept))
        end
        table.insert(found, "two launchers that ask for the same xmake at once both succeed: " .. tostring(first_status) .. " " .. tostring(second_status) .. "\n" .. first_log .. "\n" .. second_log .. "\n" .. table.concat(logs, "\n"))
    end
    if count_lines(counter) ~= 1 then
        table.insert(found, "the xmake of a key is built once for the machine, however many launchers ask at once: " .. count_lines(counter) .. " builds")
    end
    local keys = os.dirs(path.join(store, "xmake", "*"))
    if #keys ~= 1 or not os.isfile(path.join(keys[1], "bin", "xmake")) or exists(path.join(keys[1], "install")) then
        table.insert(found, "the store holds one xmake install of the key and none nested in another: " .. table.concat(keys, ","))
    end
    if #os.files(path.join(store, "xmake", "*.log")) > 0 or #os.dirs(path.join(store, "xmake", "*.build.*")) > 0 then
        table.insert(found, "a finished build leaves no log and no working folder behind")
    end
end

local function hung_build(folder, repository, found)
    local hung = path.join(folder, "hung")
    os.mkdir(hung)
    local url, commit = upstream_of(hung)
    local recipe = "package(\"xmake\")\n    add_urls(\"" .. url .. "\")\n    add_versions(\"v0\", \"" .. commit .. "\")\n"
    local root = checkout_of(hung, repository, recipe)
    local store = path.join(hung, "store")
    local counter = path.join(hung, "builds.txt")
    local key = key_of(commit, path.join(root, "xmakew"))
    local envs = {REVENANT_STORE = store, BUILD_COUNTER = counter, STUB_LOG = path.join(hung, "trail.txt"), BUILD_SECONDS = "12"}
    local builder = spawn(hung, root, table.join(envs, {REVENANT_CACHE = path.join(hung, "cache-a")}), "a")
    if not waited_for(counter, 120000) then
        table.insert(found, "the first launcher did not start building the xmake: " .. (io.readfile(builder.log) or ""))
    end
    local holder_file = path.join(store, "xmake", key .. ".holder")
    local holder = os.isfile(holder_file) and io.readfile(holder_file) or ""
    local pid = holder:match("^(%d+) %d+")
    if not pid then
        table.insert(found, "a launcher that builds the xmake records its process and its start where the others can read them: " .. holder)
    end
    local waiter = spawn(hung, root, table.join(envs, {REVENANT_CACHE = path.join(hung, "cache-b"), REVENANT_XMAKE_BUILD_WAIT = "4", REVENANT_XMAKE_BUILD_POLL = "2"}), "b")
    local status, output = finish(waiter, 9000)
    if not status or status == "0" then
        table.insert(found, "a launcher that waits longer than REVENANT_XMAKE_BUILD_WAIT for another's build stops with an error and does not hang: " .. tostring(status) .. "\n" .. output)
    end
    if not output:find("xmake " .. key, 1, true) or not output:find("REVENANT_XMAKE_BUILD_WAIT", 1, true) or not (pid and output:find("process " .. pid, 1, true)) then
        table.insert(found, "the waiting launcher prints the key, who holds the lock and the variable that sets the limit: " .. output)
    end
    if not output:find("waited 2 s", 1, true) then
        table.insert(found, "the waiting launcher says each time it has waited, not only at the end: " .. output)
    end
    local built, built_log = finish(builder, 60000)
    if built ~= "0" then
        table.insert(found, "the build the other launcher gave up on finishes: " .. tostring(built) .. "\n" .. built_log)
    end
    if count_lines(counter) ~= 1 then
        table.insert(found, "the launcher that gave up built nothing: " .. count_lines(counter) .. " builds")
    end
    if exists(holder_file) then
        table.insert(found, "a finished build leaves no record of a holder behind")
    end
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local repository = path.directory(path.directory(path.absolute(opt.modules)))
    local launcher = path.join(repository, "xmakew")
    local root = checkout_of(folder, repository)
    local store = stub_into(path.join(folder, "store"), COMMIT, launcher)
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
    local installed = path.join(legacy, "xmake-global", ".xmake", "packages", "t", "pkg", "1.0", "abc")
    os.mkdir(installed)
    io.writefile(path.join(installed, "data"), "installed")
    os.mkdir(path.join(legacy, "xmake", "old", "bin"))
    os.ln(os.programfile(), path.join(legacy, "xmake", "old", "bin", "xmake"))
    local seeded = path.join(folder, "seeded-store")
    status, output = launch(linked, envs(legacy, {REVENANT_STORE = seeded}), log)
    if status == 0 then
        table.insert(found, "a cache with a package store of its own is refused: " .. output)
    end
    if exists(seeded) then
        table.insert(found, "the refusal creates no store: " .. seeded)
    end
    if os.islink(path.join(legacy, "xmake-global")) or os.islink(path.join(legacy, "xmake")) or not os.isfile(path.join(installed, "data")) then
        table.insert(found, "the refusal leaves the package store of the old cache as it was")
    end
    local seed = output:match("xmakew: seed: ([^\n]+)")
    if not seed then
        table.insert(found, "the refusal prints the command that makes the old cache the store: " .. output)
    else
        local seeding = os.execv("sh", {"-c", seed}, {try = true, stdout = log, stderr = log,
                                                         envs = {XMAKE_GLOBALDIR = path.join(folder, "seeding-globaldir")}})
        if seeding ~= 0 then
            table.insert(found, "the command the refusal prints seeds the store from the old cache (" .. tostring(seeding) .. "): " .. (io.readfile(log) or ""))
        end
        local copy = path.join(seeded, "xmake-global", ".xmake", "packages", "t", "pkg", "1.0", "abc", "data")
        if not os.isfile(copy) or io.readfile(copy) ~= "installed" then
            table.insert(found, "the seeded store holds the installs of the old cache")
        end
        if not os.isfile(path.join(installed, "data")) then
            table.insert(found, "seeding leaves the old cache in place")
        end
        os.tryrm(path.join(legacy, "xmake-global"))
        os.tryrm(path.join(legacy, "xmake"))
        stub_into(seeded, COMMIT, launcher)
        status, output = launch(linked, envs(legacy, {REVENANT_STORE = seeded}), log)
        if status ~= 0 or target(path.join(legacy, "xmake-global")) ~= path.join(seeded, "xmake-global") then
            table.insert(found, "after seeding and removing the old folders the cache links to the seeded store: " .. output)
        end
    end

    local partial = path.join(folder, "partial-cache")
    os.mkdir(path.join(partial, "xmake-global", ".xmake", "packages"))
    local untouched = path.join(folder, "untouched-store")
    status, output = launch(linked, envs(partial, {REVENANT_STORE = untouched}), log)
    if status == 0 or exists(untouched) or exists(path.join(partial, "xmake")) then
        table.insert(found, "a cache whose xmake-global is a real folder is refused before anything is made for it, not after the xmake link: " .. output)
    end

    status, output = launch(linked, envs(path.join(folder, "relative-store-cache"), {REVENANT_STORE = "relative/store"}), log)
    if status == 0 or exists(path.join(linked, "relative")) then
        table.insert(found, "a relative REVENANT_STORE is refused and makes no folder: " .. output)
    end

    concurrent_builds(folder, repository, found)
    hung_build(folder, repository, found)

    os.tryrm(folder)
    return found
end

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
    local pid = holder:match("^(%d+) ")
    if not pid then
        table.insert(found, "a launcher that builds the xmake records its process and its start where the others can read them: " .. holder)
    end
    local recorded_start = holder:match("^%d+ (%d+)")
    local alive = pid and os.execv("/bin/kill", {"-0", pid}, {try = true}) == 0
    if not recorded_start or not alive then
        table.insert(found, "the holder file records a live process and when it started, so a number that another process has taken later is told from the builder: " .. holder)
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
    if exists(holder_file) or #os.files(path.join(store, "xmake", "*.holder.*")) > 0 then
        table.insert(found, "a finished build leaves no record of a holder behind, and none half written")
    end
    if not output:find("has held for", 1, true) or output:find("has ended", 1, true) then
        table.insert(found, "a builder that is running is not reported as ended: " .. output)
    end
end

local function stale_holder(folder, repository, found)
    local stale = path.join(folder, "stale")
    os.mkdir(stale)
    local launcher = path.join(repository, "xmakew")
    local root = checkout_of(stale, repository)
    local store = path.join(stale, "store")
    local xmakes = path.join(store, "xmake")
    os.mkdir(xmakes)
    local key = key_of(COMMIT, launcher)
    local lockfile = path.join(xmakes, key .. ".lock")
    local holding = process.openv("sh", {"-c", "if command -v flock >/dev/null 2>&1; then exec flock \"$1\" sleep 8; else exec lockf -k \"$1\" sleep 8; fi", "sh", lockfile},
                                  {stdout = path.join(stale, "holding.log"), stderr = path.join(stale, "holding.log")})
    local waited = 0
    while waited < 5000 do
        local probe = io.openlock(lockfile)
        local free = probe and probe:trylock()
        if probe then
            if free then
                probe:unlock()
            end
            probe:close()
        end
        if not free then
            break
        end
        os.sleep(100)
        waited = waited + 100
    end
    io.writefile(path.join(xmakes, key .. ".holder"), "1 1\n")
    local status, output = launch(root, {REVENANT_STORE = store, REVENANT_CACHE = path.join(stale, "cache"), REVENANT_XMAKE_BUILD_WAIT = "2", REVENANT_XMAKE_BUILD_POLL = "1"}, path.join(stale, "launch.log"))
    holding:close()
    if status == 0 or not output:find("process 1 held", 1, true) or not output:find("has ended", 1, true) then
        table.insert(found, "a holder file whose process number is alive but started at another time is told from the builder, and the wait still ends: " .. tostring(status) .. "\n" .. output)
    end
end

local function wait_limits(folder, repository, found)
    local limits = path.join(folder, "limits")
    os.mkdir(limits)
    local root = checkout_of(limits, repository)
    for index, setting in ipairs({{"0", "30", "REVENANT_XMAKE_BUILD_WAIT"}, {"1800", "0", "REVENANT_XMAKE_BUILD_POLL"}, {"many", "30", "whole numbers"}}) do
        local store = path.join(limits, "store" .. index)
        local status, output = launch(root, {REVENANT_STORE = store, REVENANT_CACHE = path.join(limits, "cache" .. index), REVENANT_XMAKE_BUILD_WAIT = setting[1], REVENANT_XMAKE_BUILD_POLL = setting[2]}, path.join(limits, "launch.log"))
        if status == 0 or not output:find(setting[3], 1, true) or #os.dirs(path.join(store, "xmake", "*.build.*")) > 0 then
            table.insert(found, "a wait of " .. setting[1] .. " s with a poll of " .. setting[2] .. " s is refused by name before anything is built: " .. tostring(status) .. "\n" .. output)
        end
    end
end

local function lock_of(entries)
    local lines = {"{", "    __meta__ = {", "        version = \"1.0\"", "    },", "    [\"iphoneos|arm64\"] = {"}
    for _, entry in ipairs(entries) do
        table.insert(lines, "        [\"" .. entry.name .. "\"] = {")
        table.insert(lines, "            repo = {")
        if entry.branch then
            table.insert(lines, "                branch = \"" .. entry.branch .. "\",")
        end
        if entry.commit then
            table.insert(lines, "                commit = \"" .. entry.commit .. "\",")
        end
        table.insert(lines, "                url = \"" .. entry.url .. "\"")
        table.insert(lines, "            },")
        table.insert(lines, "            version = \"" .. (entry.version or "1.0") .. "\"")
        table.insert(lines, "        },")
    end
    table.insert(lines, "    }")
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

local function pinned_lock(folder, repository, found)
    local locked = path.join(folder, "locked")
    os.mkdir(locked)
    local root = checkout_of(locked, repository)
    local launcher = path.join(repository, "xmakew")
    local store = stub_into(path.join(locked, "store"), COMMIT, launcher)
    local trail = path.join(locked, "trail.txt")
    local head = os.iorunv("git", {"-C", root, "rev-parse", "HEAD"}):trim()
    local other_commit = string.rep("0", 40)
    local through_link = path.join(locked, "link-to-checkout")
    os.ln(root, through_link)
    local remote = "https://example.invalid/revenant.git"
    local gitlab = {name = "cmake#f56260b5", branch = "master", commit = other_commit, url = "https://gitlab.com/tboox/xmake-repo.git"}
    local function revenant(url, commit)
        return {name = "revenant@llvm 23.1.3#f56260b5", commit = commit, url = url}
    end
    local function local_entries(url, count)
        local entries = {}
        for index = 1, count or 1 do
            table.insert(entries, {name = string.format("revenant@package%02d#f56260b5", index), url = url, version = "latest"})
        end
        return entries
    end
    local function run(label, entries, arguments)
        local project = path.join(locked, "project-" .. label)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake-requires.lock"), lock_of(entries))
        local before = os.isfile(trail) and io.readfile(trail) or ""
        local invoked = arguments and arguments(project) or {"l", "-P", project, "probe.lua"}
        local status = os.execv(path.join(root, "xmakew"), invoked,
                                {try = true, curdir = root, stdout = path.join(locked, "out.log"), stderr = path.join(locked, "out.log"),
                                 envs = {REVENANT_STORE = store, REVENANT_CACHE = path.join(locked, "cache"), STUB_LOG = trail}})
        local output = io.readfile(path.join(locked, "out.log")) or ""
        local after = os.isfile(trail) and io.readfile(trail) or ""
        return status, output, after ~= before, project
    end
    local refused = {
        {"another checkout", {revenant(path.join(locked, "elsewhere"), head)}, {path.join(locked, "elsewhere"), head}},
        {"this checkout at another commit", {revenant(real(root), other_commit)}, {real(root), other_commit}},
        {"the published repository at another commit", {revenant(remote, other_commit)}, {remote, other_commit}},
        {"one good entry beside a stale one", {revenant(real(root), head), {name = "revenant@openssl#f56260b5", commit = head, url = path.join(locked, "elsewhere")}},
         {path.join(locked, "elsewhere"), head}}
    }
    for index, case in ipairs(refused) do
        local status, output, started = run("refused" .. index, case[2])
        if status == 0 or started or not output:find("names the revenant package repository " .. case[3][1] .. " at commit " .. case[3][2], 1, true)
           or not output:find("Nothing was started", 1, true) or not output:find("delete ", 1, true) or not output:find(real(root), 1, true) then
            table.insert(found, "a project whose lock names " .. case[1] .. " is refused, naming the lock's repository and commit and this checkout, before xmake starts: "
                         .. tostring(status) .. " started=" .. tostring(started) .. "\n" .. output)
        end
    end
    local elsewhere = path.join(locked, "elsewhere")
    local uncommitted_refused = {
        {"another checkout by its path", local_entries(elsewhere, 1), 1},
        {"28 packages of another checkout", local_entries(elsewhere, 28), 28},
        {"one stale entry beside a good one", table.join(local_entries(real(root), 1), {{name = "revenant@openssl#f56260b5", url = elsewhere, version = "latest"}}), 1}
    }
    for index, case in ipairs(uncommitted_refused) do
        local status, output, started = run("uncommitted-refused" .. index, case[2])
        if status == 0 or started or not output:find("names the revenant package repository " .. elsewhere .. " with no commit recorded for " .. case[3] .. " package entries", 1, true)
           or not output:find("Nothing was started", 1, true) or not output:find("delete ", 1, true) or not output:find(real(root), 1, true) then
            table.insert(found, "a project whose lock names " .. case[1] .. " with no commit recorded is refused by its path, naming the lock's repository and this checkout, before xmake starts: "
                         .. tostring(status) .. " started=" .. tostring(started) .. "\n" .. output)
        end
    end
    local accepted = {
        {"this checkout", {revenant(real(root), head)}},
        {"this checkout through a link", {revenant(through_link, head)}},
        {"the published repository at this commit", {revenant(remote, head)}},
        {"no revenant package", {gitlab}},
        {"no package", {}},
        {"this checkout by its path with no commit recorded, as xmake writes it for a local repository", local_entries(real(root), 1)},
        {"this checkout through a link with no commit recorded", local_entries(through_link, 1)},
        {"the shape of a real lock: 28 local entries with no commit beside entries of the xmake repository that have one", table.join(local_entries(real(root), 28), {gitlab})},
        {"an entry with no commit beside one with this checkout's commit", table.join(local_entries(real(root), 1), {revenant(real(root), head)})}
    }
    for index, case in ipairs(accepted) do
        local status, output, started = run("accepted" .. index, case[2])
        if status ~= 0 or not started then
            table.insert(found, "a project whose lock names " .. case[1] .. " starts: " .. tostring(status) .. "\n" .. output)
        end
    end
    local status, output, started, project = run("loop", local_entries(elsewhere, 3))
    if status == 0 or started or not output:find("delete " .. path.join(project, "xmake-requires.lock"), 1, true) then
        table.insert(found, "the lock of another checkout is refused with the advice to delete it: " .. tostring(status) .. "\n" .. output)
    end
    os.rm(path.join(project, "xmake-requires.lock"))
    status, output, started = run("loop", table.join(local_entries(real(root), 3), {gitlab}))
    if status ~= 0 or not started then
        table.insert(found, "after the advice (the lock deleted and the lock xmake writes for this checkout, a local path with no commit, in its place) the project starts and is not refused again: " .. tostring(status) .. "\n" .. output)
    end
    local forms = {
        ["--project=DIR"] = function (project) return {"l", "--project=" .. project, "probe.lua"} end,
        ["--project DIR"] = function (project) return {"l", "--project", project, "probe.lua"} end,
        ["-PDIR"] = function (project) return {"l", "-P" .. project, "probe.lua"} end
    }
    for form, arguments in pairs(forms) do
        local status, output, started = run("form-" .. form:gsub("[^%w]", ""), {revenant(path.join(locked, "elsewhere"), head)}, arguments)
        if status == 0 or started or not output:find("Nothing was started", 1, true) then
            table.insert(found, "the project named as " .. form .. " has its lock checked: " .. tostring(status) .. "\n" .. output)
        end
    end
    local stale_cwd = path.join(locked, "stale-cwd")
    os.mkdir(stale_cwd)
    io.writefile(path.join(stale_cwd, "xmake-requires.lock"), lock_of({revenant(path.join(locked, "elsewhere"), head)}))
    local clean = path.join(locked, "clean-project")
    os.mkdir(clean)
    local before = os.isfile(trail) and io.readfile(trail) or ""
    local status = os.execv(path.join(root, "xmakew"), {"l", "-P", clean, "probe.lua"},
                            {try = true, curdir = stale_cwd, stdout = path.join(locked, "out.log"), stderr = path.join(locked, "out.log"),
                             envs = {REVENANT_STORE = store, REVENANT_CACHE = path.join(locked, "cache"), STUB_LOG = trail}})
    if status ~= 0 or (os.isfile(trail) and io.readfile(trail) or "") == before then
        table.insert(found, "only the lock of the project that is built is read, not one in the folder the command runs in: " .. tostring(status) .. "\n" .. (io.readfile(path.join(locked, "out.log")) or ""))
    end
    if #os.dirs(path.join(store, "xmake", "*.build.*")) > 0 then
        table.insert(found, "the refusals leave no build of xmake behind")
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

    local function listing(base)
        local names = {}
        for _, entry in ipairs(os.filedirs(path.join(base, "**"))) do
            table.insert(names, path.relative(entry, base))
        end
        table.sort(names)
        return table.concat(names, "\n")
    end
    local before = listing(store)
    local through_link = path.join(folder, "link-to-store")
    os.ln(store, through_link)
    for label, cache in pairs({["the shared store itself"] = store, ["a folder inside it"] = path.join(store, "inner", "cache"), ["a link to it"] = through_link,
                               ["a folder inside it through a link"] = path.join(through_link, "inner")}) do
        status, output = launch(linked, envs(cache), log)
        if status == 0 or not output:find("REVENANT_CACHE", 1, true) or not output:find("shared store", 1, true) then
            table.insert(found, "REVENANT_CACHE that is " .. label .. " is refused, naming REVENANT_CACHE and the shared store: " .. tostring(status) .. "\n" .. output)
        end
        if listing(store) ~= before or exists(path.join(store, "xmake", "xmake")) then
            table.insert(found, "the refusal of REVENANT_CACHE that is " .. label .. " leaves the store as it was: " .. listing(store))
        end
    end
    local sibling = path.join(folder, "store-sibling")
    status, output = launch(linked, envs(sibling), log)
    if status ~= 0 then
        table.insert(found, "a cache beside the store, whose name starts with the store's, is not mistaken for a folder inside it: " .. output)
    end

    concurrent_builds(folder, repository, found)
    hung_build(folder, repository, found)
    stale_holder(folder, repository, found)
    wait_limits(folder, repository, found)
    pinned_lock(folder, repository, found)

    os.tryrm(folder)
    return found
end

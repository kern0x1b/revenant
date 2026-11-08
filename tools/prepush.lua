local bytes = import("core.base.bytes")

local root = path.absolute(path.directory(os.scriptdir()))

local CODE = {m = true, mm = true, c = true, cpp = true}

local VOLATILE = {PWD = true, OLDPWD = true, SHLVL = true, ["_"] = true, TERM_SESSION_ID = true,
                  SECURITYSESSIONID = true, COLUMNS = true, LINES = true}

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function digest(text)
    return hash.sha256(bytes(text))
end

local function git(folder, args)
    return os.iorunv("git", table.join({"-C", folder}, args))
end

local function tracked(pattern)
    local files = {}
    for file in git(root, {"ls-files", "--", pattern}):gmatch("[^\n]+") do
        table.insert(files, file)
    end
    return files
end

local function budgeted(command)
    local args = table.join({"l", "-P", root, path.join(root, "tools", "budget.lua"), "run", "--class", "critical", "--jobs", "2", "--"}, command)
    return os.execv(os.programfile(), args, {try = true, curdir = root}) == 0
end

local function lua(script, ...)
    return budgeted(table.join({os.programfile(), "l", "-P", root, path.join(root, script)}, {...}))
end

local function declared(xmake, name)
    return xmake:find("[%s{,]" .. name .. " = {") ~= nil
end

local function backports_negative()
    local xmake = io.readfile(path.join(root, "frameworks", "Backports", "xmake.lua"))
    local files = {}
    for _, file in ipairs(tracked("frameworks/Backports/tests")) do
        local stem, extension = file:match("([%w_]+)_test%.(%w+)$")
        if stem and CODE[extension] and declared(xmake, stem) then
            table.insert(files, file)
        end
    end
    return files
end

local function emulator_negative(xmake)
    local files = {}
    for block in xmake:gmatch("target%(.-target_end%(%)") do
        if block:find('add_tests("negative"', 1, true) then
            for file in block:gmatch('add_files%("([^"]+)"%)') do
                table.insert(files, path.join("emulator", file))
            end
        end
    end
    return files
end

local function shape(file, text)
    local errors = {}
    if not text:find("revenant_read_arguments(", 1, true) and not text:find('"--negative"', 1, true) then
        table.insert(errors, file .. " never reads --negative, so its negative run is its positive run")
    end
    if text:find('"check.h"', 1, true) and not text:find("return revenant_finish()", 1, true) then
        table.insert(errors, file .. " uses check.h but does not return revenant_finish(), so a failed check exits 0")
    end
    return errors
end

local function negative_errors()
    local emulator = io.readfile(path.join(root, "emulator", "xmake.lua"))
    local errors = {}
    for _, file in ipairs(table.join(backports_negative(), emulator_negative(emulator))) do
        for _, message in ipairs(shape(file, io.readfile(path.join(root, file)))) do
            table.insert(errors, message)
        end
    end
    return errors
end

local function negative_shape()
    local errors = negative_errors()
    for _, message in ipairs(errors) do
        print(message)
    end
    return #errors == 0
end

local function digests_stable()
    if not lua("toolchain/tools/recipe_digests.lua") then
        return false
    end
    local stable = true
    for line in git(root, {"status", "--porcelain", "--untracked-files=no", "--", "packages"}):gmatch("[^\n]+") do
        if line:find("/port/digest.lua$") then
            print("regenerated digest differs from the committed one: %s", line:sub(4))
            stable = false
        end
    end
    return stable
end

local function dirty_entries(folder)
    local tokens, entries = {}, {}
    for token in git(folder, {"status", "--porcelain=v1", "--untracked-files=all", "-z"}):gmatch("[^\0]+") do
        table.insert(tokens, token)
    end
    local index = 1
    while index <= #tokens do
        local status = tokens[index]:sub(1, 2)
        table.insert(entries, {status = status, file = tokens[index]:sub(4)})
        if status:find("[RC]") then
            index = index + 1
        end
        index = index + 1
    end
    return entries
end

local function manifest(folder)
    local current = {}
    for line in git(folder, {"ls-files", "-s"}):gmatch("[^\n]+") do
        local mode, sha, file = line:match("^(%d+) (%x+) %d\t(.+)$")
        current[file] = mode .. " " .. sha
    end
    local pending = {}
    for _, entry in ipairs(dirty_entries(folder)) do
        local full = path.join(folder, entry.file)
        if os.islink(full) then
            current[entry.file] = "link " .. os.readlink(full)
        elseif os.isfile(full) then
            table.insert(pending, entry.file)
        else
            current[entry.file] = "deleted"
        end
    end
    if #pending > 0 then
        local digests = {}
        for line in git(folder, table.join({"hash-object", "--"}, pending)):gmatch("[^\n]+") do
            table.insert(digests, line)
        end
        for index, file in ipairs(pending) do
            current[file] = "file " .. digests[index]
        end
    end
    local lines = {}
    for file, value in pairs(current) do
        table.insert(lines, file .. " " .. value)
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function inputs(folder)
    local environment = {}
    for name, value in pairs(os.getenvs()) do
        if not VOLATILE[name] then
            table.insert(environment, name .. "=" .. value)
        end
    end
    table.sort(environment)
    return {
        folder = folder,
        head = git(folder, {"rev-parse", "HEAD"}):trim(),
        tree = digest(manifest(folder)),
        environment = digest(table.concat(environment, "\n")),
        tool = digest(os.iorunv(os.programfile(), {"--version"})),
        host = os.host() .. "/" .. os.arch(),
    }
end

local function key_of(input, name)
    return digest(table.concat({"prepush 1", name, input.folder, input.head, input.tree, input.environment, input.tool, input.host}, "\n"))
end

local function remembered(store, name)
    local file = path.join(store, (name:gsub("%s+", "-")))
    return os.isfile(file) and io.readfile(file):trim() or nil
end

local function remember(store, name, key)
    os.mkdir(store)
    io.writefile(path.join(store, (name:gsub("%s+", "-"))), key .. "\n")
end

local function run_steps(steps, opt)
    local failed = {}
    for _, step in ipairs(steps) do
        local started = os.time()
        local key = step.cache ~= false and opt.key(step.name) or nil
        if key and remembered(opt.store, step.name) == key then
            print("ok %s cached", step.name)
        else
            local ok = step.run()
            if ok and key then
                remember(opt.store, step.name, key)
            end
            print("%s %s %ds", ok and "ok" or "FAIL", step.name, os.time() - started)
            if not ok then
                table.insert(failed, step.name)
            end
        end
    end
    return failed
end

local STEPS = {
    {name = "comments", run = function () return lua("tools/comments.lua", "check") end},
    {name = "comments test", run = function () return lua("tools/comments.lua", "test") end},
    {name = "private cache test", run = function () return lua("tools/private_cache.lua", "test") end},
    {name = "layout", run = function () return lua("tools/layout.lua") end},
    {name = "docs_commands", run = function () return lua("tools/docs_commands.lua") end},
    {name = "open_gaps", run = function () return lua("tools/open_gaps.lua") end},
    {name = "credentials", run = function () return lua("agent-skills/tests/credentials.lua", "test") end},
    {name = "copied_text", run = function () return lua("agent-skills/tests/copied_text.lua", "test") end},
    {name = "recipe digests", cache = false, run = digests_stable},
    {name = "lowered members", run = function () return lua("frameworks/Backports/tests/lowered_members_test.lua") end},
    {name = "lowered exports", run = function () return lua("frameworks/Backports/tests/lowered_exports_test.lua") end},
    {name = "negative shape", run = negative_shape},
    {name = "ci errors test", run = function () return lua("tools/ci_errors.lua", "test") end},
    {name = "ci replay test", run = function () return lua("tools/ci_swiftc_replay.lua", "test") end},
    {name = "light suites", run = function () return lua("toolchain/tests/light_suites.lua") end},
    {name = "host install test", run = function () return lua("frameworks/ReactNative/tests/host_install_test.lua") end},
}

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end

    check("a program that ignores the flag is reported", #shape("a_test.m", "int main(void) { assert(1); return 0; }"), 1)
    check("a program that reads the flag itself is clean", #shape("b_test.c", 'int main(int argc, char **argv) { return argc > 1 && strcmp(argv[1], "--negative") == 0; }'), 0)
    check("a check.h program that returns its failures is clean", #shape("c_test.m", '#import "check.h"\nint main(int argc, char **argv) { revenant_read_arguments(argc, argv); return revenant_finish(); }'), 0)
    check("a check.h program that drops its failures is reported", #shape("d_test.m", '#import "check.h"\nint main(int argc, char **argv) { revenant_read_arguments(argc, argv); return 0; }'), 1)
    check("a stem that a host test table names is declared", declared('host_tests("Foundation", {progress = {"A.m"}})', "progress"), true)
    check("a stem no table names is not declared", declared("local x = {}", "json_sorted_keys"), false)

    local emulator = 'target("a")\n    add_files("tests/unit/a_test.cpp")\n    add_tests("default")\ntarget_end()\n'
        .. 'target("b")\n    add_files("tests/unit/b_test.cpp")\n    add_tests("negative", {runargs = {"--negative"}, expect_failure = true})\ntarget_end()\n'
    check("only a target that declares a negative run is a negative source", table.concat(emulator_negative(emulator), ","), "emulator/tests/unit/b_test.cpp")

    print("prepush: %d tests passed", count)
end

local function test_cache()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("prepush cache test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local function commit(folder, message)
        git(folder, {"-c", "user.name=prepush", "-c", "user.email=prepush@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", message})
    end

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local repo = path.join(base, "repo")
    local store = path.join(base, "store")
    os.mkdir(repo)
    git(repo, {"init", "-q"})
    io.writefile(path.join(repo, "a.txt"), "one\n")
    git(repo, {"add", "a.txt"})
    commit(repo, "one")
    os.setenv("PREPUSH_TEST_KEY", "0")

    local function key(name)
        return key_of(inputs(repo), name)
    end
    local base_key = key("step")
    check("the same inputs give the same key", key("step"), base_key)
    check("the step's name is part of the key", key("other") ~= base_key, true)
    io.writefile(path.join(repo, "a.txt"), "two\n")
    check("a changed tracked file changes the key", key("step") ~= base_key, true)
    io.writefile(path.join(repo, "a.txt"), "one\n")
    check("the same content again gives the same key", key("step"), base_key)
    io.writefile(path.join(repo, "b.txt"), "new\n")
    check("an untracked file changes the key", key("step") ~= base_key, true)
    os.rm(path.join(repo, "b.txt"))
    check("removing the untracked file restores the key", key("step"), base_key)
    os.rm(path.join(repo, "a.txt"))
    check("a deleted tracked file changes the key", key("step") ~= base_key, true)
    io.writefile(path.join(repo, "a.txt"), "one\n")
    check("restoring the deleted file restores the key", key("step"), base_key)
    os.setenv("PREPUSH_TEST_KEY", "1")
    check("an environment variable changes the key", key("step") ~= base_key, true)
    os.setenv("PREPUSH_TEST_KEY", "0")
    check("restoring the variable restores the key", key("step"), base_key)
    commit(repo, "empty")
    check("a new commit changes the key", key("step") ~= base_key, true)

    local runs = {a = 0, b = 0, c = 0}
    local steps = {
        {name = "a", run = function () runs.a = runs.a + 1; return true end},
        {name = "b", run = function () runs.b = runs.b + 1; return false end},
        {name = "c", cache = false, run = function () runs.c = runs.c + 1; return true end},
    }
    local function pass()
        return run_steps(steps, {store = store, key = function (name) return key_of(inputs(repo), name) end})
    end
    check("a failing step is reported", table.concat(pass(), ","), "b")
    pass()
    check("a passing step is not run again on unchanged inputs", runs.a, 1)
    check("a failing step is run again, since it is not remembered", runs.b, 2)
    check("a step outside the cache runs every time", runs.c, 2)
    io.writefile(path.join(repo, "a.txt"), "two\n")
    pass()
    check("a changed input runs the step again", runs.a, 2)

    os.rm(base)
    print("prepush cache: %d tests passed", count)
end

function main(command)
    if command == "test" then
        test_suite()
        test_cache()
        return
    end
    local input = inputs(root)
    local failed = run_steps(STEPS, {store = path.join(cache().root(), "prepush"), key = function (name) return key_of(input, name) end})
    if #failed > 0 then
        raise("%d of %d checks failed: %s", #failed, #STEPS, table.concat(failed, ", "))
    end
    print("prepush: %d checks passed", #STEPS)
end

local root = path.absolute(path.directory(os.scriptdir()))

local CODE = {m = true, mm = true, c = true, cpp = true}

local function tracked(pattern)
    local files = {}
    for file in os.iorunv("git", {"-C", root, "ls-files", "--", pattern}):gmatch("[^\n]+") do
        table.insert(files, file)
    end
    return files
end

local function lua(script, ...)
    local args = table.join({"l", "-P", root, path.join(root, script)}, {...})
    return os.execv(os.programfile(), args, {try = true, curdir = root}) == 0
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
    for line in os.iorunv("git", {"-C", root, "status", "--porcelain", "--untracked-files=no", "--", "packages"}):gmatch("[^\n]+") do
        if line:find("/port/digest.lua$") then
            print("regenerated digest differs from the committed one: %s", line:sub(4))
            stable = false
        end
    end
    return stable
end

local STEPS = {
    {name = "comments", run = function () return lua("tools/comments.lua", "check") end},
    {name = "comments test", run = function () return lua("tools/comments.lua", "test") end},
    {name = "layout", run = function () return lua("tools/layout.lua") end},
    {name = "docs_commands", run = function () return lua("tools/docs_commands.lua") end},
    {name = "open_gaps", run = function () return lua("tools/open_gaps.lua") end},
    {name = "credentials", run = function () return lua("agent-skills/tests/credentials.lua", "test") end},
    {name = "copied_text", run = function () return lua("agent-skills/tests/copied_text.lua", "test") end},
    {name = "recipe digests", run = digests_stable},
    {name = "lowered members", run = function () return lua("frameworks/Backports/tests/lowered_members_test.lua") end},
    {name = "negative shape", run = negative_shape},
    {name = "ci errors test", run = function () return lua("tools/ci_errors.lua", "test") end},
    {name = "ci replay test", run = function () return lua("tools/ci_swiftc_replay.lua", "test") end},
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

function main(command)
    if command == "test" then
        test_suite()
        return
    end
    local failed = {}
    for _, step in ipairs(STEPS) do
        local started = os.time()
        local ok = step.run()
        print("%s %s %ds", ok and "ok" or "FAIL", step.name, os.time() - started)
        if not ok then
            table.insert(failed, step.name)
        end
    end
    if #failed > 0 then
        raise("%d of %d checks failed: %s", #failed, #STEPS, table.concat(failed, ", "))
    end
    print("prepush: %d checks passed", #STEPS)
end

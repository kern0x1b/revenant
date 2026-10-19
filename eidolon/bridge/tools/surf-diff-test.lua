-- surf-diff-test.lua: the reader refuses a file that is not three columns, rather than reading it as nothing.
--
--     xmake l surf-diff-test.lua
--
-- Each case writes its two files under .agent-work/runs/surf-diff-test/ and runs surf-diff.lua through /bin/sh, so the
-- exit code and the stderr are the ones a reader of the tool sees.

local root = path.join(os.scriptdir(), "..", "..")
local scratch = path.join(root, ".agent-work", "runs", "surf-diff-test")
local script = path.join(os.scriptdir(), "surf-diff.lua")

local THREE = "Image\tvar\talpha\nText\tfunc\tbold\n"
local TWO = "Image\talpha\nText\tbold\n"
local ONE = "Image#alpha\n"
local FOUR = "Image\tvar\talpha\tABI.swift\n"

-- runs surf-diff.lua on the two texts with the flags given, and returns the exit code and the stderr
local function run(old, new, flags)
    os.mkdir(scratch)
    local a, b = path.join(scratch, "old.tsv"), path.join(scratch, "new.tsv")
    local err = path.join(scratch, "stderr.txt")
    io.writefile(a, old)
    io.writefile(b, new)
    local args = {"-c", 'xmake l "$@" 2>"$ERRFILE"; echo "exit=$?"', "sh", script}
    for _, flag in ipairs(flags) do
        args[#args + 1] = flag
    end
    args[#args + 1] = a
    args[#args + 1] = b
    local out = os.iorunv("/bin/sh", args, {envs = {ERRFILE = err}})
    local code = tonumber(string.match(out, "exit=(%d+)"))
    return code, io.readfile(err)
end

local function case(name, old, new, flags, want_code, must_quote)
    local code, stderr = run(old, new, flags)
    local problems = {}
    if code ~= want_code then
        problems[#problems + 1] = string.format("exit %s, wanted %d", tostring(code), want_code)
    end
    for _, text in ipairs(must_quote) do
        if not string.find(stderr, text, 1, true) then
            problems[#problems + 1] = string.format("stderr does not say %q", text)
        end
    end
    print(string.format("%s %s%s", #problems == 0 and "ok  " or "FAIL", name,
        #problems == 0 and "" or (": " .. table.concat(problems, "; "))))
    return #problems == 0
end

function main(...)
    local results = {}
    -- the defect: a two-column file read as the empty set, every identity holding at 0 == 0
    results[#results + 1] = case("a 2-column NEW is a hard error naming the file and the count",
        THREE, TWO, {}, 1, {"new.tsv", "has 2 tab-separated column(s)", "the 3 this diff reads", "owner/kind/name"})
    -- a 4-column file - the shape ours.lua writes - is refused the same way
    results[#results + 1] = case("a 4-column NEW is refused with the count it found",
        THREE, FOUR, {}, 1, {"new.tsv", "has 4 tab-separated column(s)"})
    -- and the OLD side too: a diff of two wrong-shaped files must not print a partition
    results[#results + 1] = case("a 1-column OLD is refused as well",
        ONE, THREE, {}, 1, {"old.tsv", "has 1 tab-separated column(s)"})
    -- the empty NEW the flag is for
    results[#results + 1] = case("an empty NEW is refused without the flag", THREE, "", {}, 1,
        {"new.tsv", "no rows", "--allow-empty-new"})
    local code, stderr = run(THREE, "", {"--allow-empty-new"})
    local ran = code == 0 or string.find(stderr, "no rows", 1, true) ~= nil
    print(string.format("%s --allow-empty-new lets an empty NEW through%s", ran and "ok  " or "FAIL",
        ran and "" or string.format(" (exit %s)", tostring(code))))
    results[#results + 1] = ran

    local passed = 0
    for _, ok in ipairs(results) do
        if ok then
            passed = passed + 1
        end
    end
    print(string.format("\n%d/%d cases", passed, #results))
    os.exit(passed == #results and 0 or 1)
end

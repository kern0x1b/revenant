local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
local script = path.join(os.scriptdir(), "surf-diff.lua")
local scratch = nil

local THREE = "Image\tvar\talpha\nText\tfunc\tbold\n"
local TWO = "Image\talpha\nText\tbold\n"
local ONE = "Image#alpha\n"
local FOUR = "Image\tvar\talpha\tABI.swift\n"

local function run(old, new, flags)
    scratch = scratch or tree.fresh("surf-diff-test")
    local a, b = path.join(scratch, "old.tsv"), path.join(scratch, "new.tsv")
    local err = path.join(scratch, "stderr.txt")
    io.writefile(a, old)
    io.writefile(b, new)
    local args = table.join({"l", script}, flags, {a, b})
    local stderr = io.open(err, "w")
    local stdout = io.open(path.join(scratch, "stdout.txt"), "w")
    local code = os.execv(os.programfile(), args, {stdout = stdout, stderr = stderr, try = true})
    stderr:close()
    stdout:close()
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
    results[#results + 1] = case("a 2-column NEW is a hard error naming the file and the count",
        THREE, TWO, {}, 1, {"new.tsv", "has 2 tab-separated column(s)", "the 3 this diff reads", "owner/kind/name"})
    results[#results + 1] = case("a 4-column NEW is refused with the count it found",
        THREE, FOUR, {}, 1, {"new.tsv", "has 4 tab-separated column(s)"})
    results[#results + 1] = case("a 1-column OLD is refused as well",
        ONE, THREE, {}, 1, {"old.tsv", "has 1 tab-separated column(s)"})
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
    os.tryrm(scratch)
    os.exit(passed == #results and 0 or 1)
end

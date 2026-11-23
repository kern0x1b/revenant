function failures(opt)
    local light = import("light_suites", {rootdir = path.join(opt.modules, "..", "tests"), anonymous = true})
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: got %s, wanted %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end
    local function shape(groups)
        local lines = {}
        for _, group in ipairs(groups) do
            table.insert(lines, table.concat(group, ","))
        end
        return table.concat(lines, " | ")
    end

    local slow = {"digest_test", "golden_generation_test", "shared_store_test", "store_race_test", "compat_test", "cache_test", "a_test", "b_test"}
    local groups = light.partition(slow, 4)
    check("the four slowest suites each start a group of their own", shape(groups), "digest_test | golden_generation_test,a_test,b_test | shared_store_test,cache_test | store_race_test,compat_test")

    local seen, count = {}, 0
    for _, group in ipairs(groups) do
        for _, suite in ipairs(group) do
            seen[suite] = (seen[suite] or 0) + 1
            count = count + 1
        end
    end
    local once = true
    for _, suite in ipairs(slow) do
        once = once and seen[suite] == 1
    end
    check("every suite is in exactly one group", once and count == #slow, true)
    check("the same suites give the same groups", shape(light.partition(slow, 4)), shape(groups))
    check("one worker gets every suite in one group", #light.partition(slow, 1), 1)
    check("fewer suites than workers leave no empty group", #light.partition({"x_test", "y_test"}, 4), 2)
    check("no suites give no group", #light.partition({}, 4), 0)

    check("a missing grant means one worker", light.workers(nil), 1)
    check("a grant of three tokens is three workers", light.workers("3"), 3)
    check("a grant above the limit is the limit", light.workers("12"), 4)
    check("a grant of zero is one worker", light.workers("0"), 1)
    check("a grant that is no number is one worker", light.workers("many"), 1)

    local merged = {}
    for _, entry in ipairs(light.environment({TMPDIR = "/own", REVENANT_PROBE = "set"})) do
        local name, value = entry:match("^([^=]+)=(.*)$")
        merged[name] = (merged[name] or 0) + 1
        merged[name .. "="] = value
    end
    check("the environment of a child names TMPDIR once", merged.TMPDIR, 1)
    check("the environment of a child gives TMPDIR the folder asked for", merged["TMPDIR="], "/own")
    check("the environment of a child adds a new variable", merged["REVENANT_PROBE="], "set")
    check("the environment of a child keeps PATH", merged["PATH="], os.getenv("PATH"))
    return failures == 0 and {} or {string.format("%d checks failed", failures)}
end

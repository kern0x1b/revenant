function failures(opt)
    local light = import("light_suites", {rootdir = path.join(opt.modules, "..", "tests"), anonymous = true})
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: got %s, wanted %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end
    check("the orchestrator finds the checkout from its own file", light.checkout(), path.normalize(path.absolute(path.join(opt.modules, "..", ".."))))
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

    local memo = import("memo", {rootdir = opt.modules, anonymous = true})
    local suite_reads = import("suite_reads", {rootdir = path.join(opt.modules, "..", "tests"), anonymous = true})
    local input = {tool = "xmake", host = "host", files = {
        ["toolchain/tests/addon/cache_test.lua"] = "file a",
        ["toolchain/tests/addon/store_test.lua"] = "file b",
        ["toolchain/modules/cache.lua"] = "file c",
    }}
    local cache_step = {name = "cache_test", reads = suite_reads.of("cache_test")}
    local store_step = {name = "store_test", reads = suite_reads.of("store_test")}
    local version = "light suite memo 1"
    local cache_key = memo.key_of(input, cache_step, version)
    local store_key = memo.key_of(input, store_step, version)
    check("the declaration names its own suite", memo.matches("toolchain/tests/addon/cache_test.lua", cache_step.reads), true)
    check("the same inputs give the same suite key", memo.key_of(input, cache_step, version), cache_key)
    check("two suites have different keys", cache_key ~= store_key, true)
    local only_cache = table.clone(input.files)
    only_cache["toolchain/tests/addon/cache_test.lua"] = "file changed"
    check("a file only one suite reads moves only that suite's key", memo.key_of({tool = input.tool, host = input.host, files = only_cache}, cache_step, version) ~= cache_key, true)
    check("the other suite keeps its key", memo.key_of({tool = input.tool, host = input.host, files = only_cache}, store_step, version), store_key)
    local shared = table.clone(input.files)
    shared["toolchain/modules/cache.lua"] = "file changed"
    check("a shared module moves every suite that reads it", memo.key_of({tool = input.tool, host = input.host, files = shared}, cache_step, version) ~= cache_key, true)
    check("and the other suite too", memo.key_of({tool = input.tool, host = input.host, files = shared}, store_step, version) ~= store_key, true)
    check("a suite without a declaration reads the whole tree", table.concat(memo.reads_of({name = "unknown"})), "**")

    local host_input = {tool = "xmake", host = "host", files = {
        ["xmake.lua"] = "file a",
        ["toolchain/tests/addon/host_load_test.lua"] = "file b",
        ["toolchain/modules/workspace.lua"] = "file c",
    }}
    local host_key = light.key_for(host_input, "host_load_test")
    local child_changed = table.clone(host_input.files)
    child_changed["xmake.lua"] = "file changed"
    check("the root xmake.lua that the child xmake loads is in the suite's key", light.key_for({tool = host_input.tool, host = host_input.host, files = child_changed}, "host_load_test") ~= host_key, true)
    local nested_changed = table.clone(host_input.files)
    nested_changed["toolchain/modules/workspace.lua"] = "file changed"
    check("a module loaded through an import moves the suite's key", light.key_for({tool = host_input.tool, host = host_input.host, files = nested_changed}, "host_load_test") ~= host_key, true)
    check("an unchanged tree keeps the suite's key", light.key_for(host_input, "host_load_test"), host_key)

    local workspace = import("@addon.revenant.workspace", {anonymous = true})
    local logs = path.join(workspace.run(), "light-suites.abcdef")
    local task = light.children_task(logs)
    check("the scratch of the children lies inside the folder of the run", task, path.join(workspace.task(), "light-suites.abcdef", "scratch"))
    check("the scratch of the children is a task name under the scratch, not an absolute path", path.is_absolute(task), false)

    local leaked = {}
    for _, folder in ipairs(os.dirs(path.join(workspace.run(), "light-suites.*"))) do
        leaked[folder] = true
    end
    local root = path.absolute(path.join(opt.modules, "..", ".."))
    local nested = os.iorunv(os.programfile(), {"l", "-P", root, path.join(root, "toolchain", "tests", "light_suites.lua"), "tmp_use_test"},
                             {envs = {REVENANT_LIGHT_CHILD = ""}})
    check("a run of the orchestrator reports its suites", nested:find("light suites: 1 passed", 1, true) ~= nil, true)
    for _, folder in ipairs(os.dirs(path.join(workspace.run(), "light-suites.*"))) do
        check("the orchestrator removes its folder and the scratch of its children " .. path.filename(folder), leaked[folder], true)
    end

    local merged = {}
    for _, entry in ipairs(light.environment({TMPDIR = "/own", XMAKE_TMPDIR = "/own-xmake", REVENANT_PROBE = "set"})) do
        local name, value = entry:match("^([^=]+)=(.*)$")
        merged[name] = (merged[name] or 0) + 1
        merged[name .. "="] = value
    end
    check("the environment of a child names TMPDIR once", merged.TMPDIR, 1)
    check("the environment of a child gives TMPDIR the folder asked for", merged["TMPDIR="], "/own")
    check("the environment of a child names XMAKE_TMPDIR once", merged.XMAKE_TMPDIR, 1)
    check("the environment of a child gives XMAKE_TMPDIR the folder asked for", merged["XMAKE_TMPDIR="], "/own-xmake")
    check("the environment of a child adds a new variable", merged["REVENANT_PROBE="], "set")
    check("the environment of a child keeps PATH", merged["PATH="], os.getenv("PATH"))
    return failures == 0 and {} or {string.format("%d checks failed", failures)}
end

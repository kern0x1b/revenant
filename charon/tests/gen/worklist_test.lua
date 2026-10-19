-- The work list (tools/gen/worklist.lua): design_of maps each scope state to the design's state (or "-"), scope_counts_of reads the scope's
-- v-gen-scope.tsv (tests/gen/worklist_fixture), and difference_of ties the work list's counts to it: equal counts tie, a planted
-- difference in one state is named. totals_line writes the totals' columns in their order. The worklist's own run reads an SDK and is
-- not here. A mutant (design_of maps "generable stub" to "overridden", or difference_of stops at the first state) must make this test fail.
-- Run: xmake l tests/gen/worklist_test.lua (exits 1 on failure). Pure Lua: no SDK, no clang, no heavy job.

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local wl = import("gen.worklist", {rootdir = TOOLS, anonymous = true})

    -- the design's four states, each from the scope states it reads; a scope state the design names no category for is "-"
    local cases = {
        {"implemented at 6.1.3: the release answers", "in 6.1.3"},
        {"overridden", "overridden"},
        {"registry decision", "overridden"},
        {"hand implementation (no registry row)", "overridden"},
        {"class object: hand code covers it (not generated)", "overridden"},
        {"protocol member: declared by a hand header (no generator)", "overridden"},
        {"generable stub", "generated stub"},
        {"C function: generable stub (trace layer)", "generated stub"},
        {"generable constant", "generated stub"},
        {"swift: rendered by the Swift skeleton (generated stub)", "generated stub"},
        {"class object: generated (trace layer; every member a stub)", "generated stub"},
        {"protocol member: in the transcribed protocol header", "generated stub"},
        {"header-only (lift): no symbol to generate", "header only"},
        {"not generated: missing", "-"},
        {"open state, no queue entry names it", "-"},
        {"no snapshot: no Swift shard", "-"},
    }
    for _, case in ipairs(cases) do
        local got = wl.design_of(case[1])
        check(got == case[2], "design_of '" .. case[1] .. "' is '" .. case[2] .. "', got '" .. got .. "'")
    end

    -- the scope's counts: the fixture's rows per framework (the surface_rows of its kinds) and each state's count
    local scope = wl.scope_counts_of(path.join(ROOT, "tests", "gen", "worklist_fixture", "v-gen-scope.tsv"))
    check(scope.Foo ~= nil and scope.Foo.rows == 4, "scope_counts_of sums the kinds of a framework")
    check(scope.Foo and scope.Foo.states["implemented at 6.1.3: the release answers"] == 2, "scope_counts_of reads a state's count")
    check(scope.Foo and scope.Foo.states["generable stub"] == 1, "scope_counts_of reads a state after another")
    -- a state whose own text holds "; " is one state, not two pieces
    local semicolon = "class object: generated (trace layer; every member a stub)"
    check(scope.Foo and scope.Foo.states[semicolon] == 1 and scope.Foo.states["every member a stub)"] == nil,
          "scope_counts_of keeps a state with \"; \" in its text whole")
    check(scope.Bar ~= nil and scope.Bar.rows == 1 and scope.Bar.states["no snapshot"] == 1, "scope_counts_of reads a second framework")

    -- the work list's counts that equal the scope's tie
    local same = {Foo = {rows = 4, states = {["implemented at 6.1.3: the release answers"] = 2, ["generable stub"] = 1, [semicolon] = 1}},
                  Bar = {rows = 1, states = {["no snapshot"] = 1}}}
    check(wl.difference_of(same, scope) == nil, "equal counts tie")

    -- a planted difference in one state is named, whichever side has it
    local off = {Foo = {rows = 4, states = {["implemented at 6.1.3: the release answers"] = 2, ["generable stub"] = 0, [semicolon] = 2}},
                 Bar = {rows = 1, states = {["no snapshot"] = 1}}}
    local difference = wl.difference_of(off, scope)
    check(difference ~= nil and string.find(difference, "Foo", 1, true) ~= nil and string.find(difference, semicolon, 1, true) ~= nil,
          "a state that differs is named: " .. tostring(difference))
    local missing_fw = {Foo = same.Foo}
    check(wl.difference_of(missing_fw, scope) ~= nil, "a framework the scope counts and the work list lacks is named")

    -- totals_line: name, rows, the four design states, not named, queued, by_hand (generated stubs and queued rows)
    local line = wl.totals_line("Foo", {rows = 4, queued = 1, states = {}, design = {["in 6.1.3"] = 1, overridden = 1,
                                                                                ["generated stub"] = 1, ["header only"] = 0, ["-"] = 1}})
    check(line == "Foo\t4\t1\t1\t1\t0\t1\t1\t2", "totals_line columns: " .. line)

    print("worklist test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end

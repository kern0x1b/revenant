-- The check's protocol-set rule (review r4 F16): a protocol-set record must not name a protocol a registry row implements. The fixture is
-- a small tree under .agent-work/runs (removed at the start and at the end); nothing is read from the corpus. Run:
-- xmake l tests/gen/protocol_set_test.lua (exits 1 on failure).

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")
local FIXTURE = path.join(ROOT, ".agent-work", "runs", "protocol-set-test")
local FW = "Fixture"

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local cmd_check = import("gen.cmd_check", {rootdir = TOOLS, anonymous = true})

    os.tryrm(FIXTURE)
    local registry = path.join(FIXTURE, "packages", "a", "apple-backports", "registry", FW)
    local sets = path.join(FIXTURE, "packages", "a", "apple-backports", "overrides", "protocol-sets")
    os.mkdir(registry)
    os.mkdir(sets)
    io.writefile(path.join(registry, "one.json"), '{"entries": [{"api": "MTLNamed", "kind": "protocol"}]}')

    check(#cmd_check.record_conflicts(FIXTURE, FW) == 0, "no record: no conflict")

    io.writefile(path.join(sets, FW .. ".tsv"), "protocol\treason\nMTLNamed\tnamed by a row\nCHUnlisted\tnamed by no row\n")
    local conflicts = cmd_check.record_conflicts(FIXTURE, FW)
    check(#conflicts == 1 and conflicts[1] == "MTLNamed", "a record that names a registry protocol conflicts with it")

    io.writefile(path.join(sets, FW .. ".tsv"), "protocol\treason\nCHUnlisted\tnamed by no row\n")
    check(#cmd_check.record_conflicts(FIXTURE, FW) == 0, "a record of protocols no row implements has no conflict")

    os.tryrm(FIXTURE)
    print("protocol set test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end

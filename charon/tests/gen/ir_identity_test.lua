-- The extractor's libclang identity rule (review F8), through tools/found/ir.lua: a shard whose recorded identity (the libclang version,
-- the SHA-256 of its dylib, the target) is not the extractor's own is refused by check and by write, and write re-records it only with
-- IR_REPIN. The rule compares the recorded identity line with what `decls --version` prints, so the extractor here is a stand-in
-- (fake_decls.lua) that prints a chosen identity and one row: no build of the real extractor, no libclang of this machine and no digest
-- of it is involved, and the run does not depend on the folder it starts from. The real extractor's own identity line is checked by
-- tools/found/tests/run.lua. Run: xmake l tests/gen/ir_identity_test.lua (exits 1 on failure).

local REPO = path.absolute(path.join(os.scriptdir(), "..", ".."))
local IR = path.join(REPO, "tools", "found", "ir.lua")
local RUN = path.join(REPO, ".agent-work", "runs", "ir-identity-test")
local fake = import("fake_decls", {rootdir = os.scriptdir(), anonymous = true})

-- Two identities that differ in the digest of the dylib alone, which is the case the rule exists for.
local VERSION = "Apple clang version 21.0.0 (clang-2100.3.34.2)"
local RECORDED = VERSION .. " dylib-sha256=" .. string.rep("0", 64) .. " target=arm64-apple-ios26.4"
local CURRENT = VERSION .. " dylib-sha256=" .. string.rep("1", 64) .. " target=arm64-apple-ios26.4"

-- One function of the framework Fixture: the eighteen cells of the IR (the extractor's row) and the line the shard keeps for it.
local IR_ROW = {"Fixture", "function", "c:@F@FixtureSum", "-", "FixtureSum", "-", "-", "-", "-", "-", "int", "int a | int b", "-", "-",
                "49740040529ed9bb", "-", "-", "-", "-", "-", "-"}
local SHARD_ROW = "function\tc:@F@FixtureSum\t-\t\t\tint\tint a | int b\t-\t-\t-\t49740040529ed9bb\t-\n"
local SHARD_COLUMNS = "kind,usr,container,name,side,type,params,attrs,availability,message,declhash,value"

-- The shard of Fixture as the driver writes it for an extractor with the given identity.
local function shard_text(identity)
    return "#libclang=" .. identity .. "\tsdk=iPhoneOS-fixture\tcolumns=" .. SHARD_COLUMNS .. "\n" .. SHARD_ROW
end

-- Runs the driver on the stand-in in one mode. Returns true, or false and the message the run raised.
local function run_ir(p, mode, repin)
    local envs = {IR_DECLS = p.decls, IR_SDK = p.sdk, IR_SPEC = p.spec, IR_UNPARSED = p.unparsed, IR_CONFLICTS = p.conflicts,
                  IR_NO_SHARD = p.no_shard, IR_MODE = mode, IR_TIMEOUT = "5"}
    if repin then
        envs.IR_REPIN = "1"
    end
    local ok, message = true, ""
    try {
        function () os.iorunv(os.programfile(), {"l", IR}, {envs = envs}) end,
        catch {
            function (errors)
                ok = false
                message = tostring(errors)
            end
        }
    }
    return ok, message
end

local function cases()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.mkdir(path.join(RUN, "spec", "Fixture"))
    local p = {spec = path.join(RUN, "spec"), sdk = path.join(RUN, "iPhoneOS-fixture.sdk"), decls = path.join(RUN, "decls"),
               unparsed = path.join(RUN, "unparsed.tsv"), conflicts = path.join(RUN, "conflicts.tsv"), no_shard = path.join(RUN, "no-shard.tsv")}
    local shard = path.join(p.spec, "Fixture", "declarations.tsv")
    fake.write(p.decls, fake.rows_body({IR_ROW}), CURRENT)
    -- no framework of this fixture is without a shard, and nothing is unparsed: the lists the driver checks are empty
    io.writefile(p.unparsed, "# the frameworks of the SDK with no declaration the extractor reads, and why: one line each\n")
    io.writefile(p.no_shard, "# the frameworks of the sweep with no shard that declare nothing of their own: computed by the sweep from the extractor's census\n")
    local recorded = shard_text(RECORDED)
    io.writefile(shard, recorded)

    local ok, message = run_ir(p, "check", false)
    check(not ok and string.find(message, "libclang identity differs", 1, true) ~= nil,
          "check refuses a shard recorded by another libclang identity (" .. message:sub(1, 160) .. ")")

    ok, message = run_ir(p, "write", false)
    check(not ok and string.find(message, "libclang identity differs", 1, true) ~= nil,
          "write refuses it without IR_REPIN (" .. message:sub(1, 160) .. ")")
    check(io.readfile(shard) == recorded, "the refused write left the shard as it was")

    ok, message = run_ir(p, "write", true)
    check(ok, "write with IR_REPIN re-records the shard (" .. message:sub(1, 160) .. ")")
    check(io.readfile(shard) == shard_text(CURRENT), "the re-recorded shard is the extractor's rows under the extractor's identity")

    ok, message = run_ir(p, "check", false)
    check(ok, "check accepts the shard once it records the extractor's identity (" .. message:sub(1, 160) .. ")")
    return failures, count
end

function main()
    os.tryrm(RUN)
    local failures, count, crashed = 0, 0, nil
    try {
        function ()
            failures, count = cases()
        end,
        catch {
            function (errors)
                crashed = errors
            end
        }
    }
    os.tryrm(RUN)
    if crashed then
        raise("%s", tostring(crashed))
    end
    print(string.format("ir identity test: %s (%d checks)", failures == 0 and "OK" or ("FAIL " .. failures), count))
    if failures > 0 then
        os.exit(1)
    end
end

-- The dump step is time-bounded with a reported failure (tools/gen/swift_shard.lua dump_command, cached_root; tools/gen/heavy_batch.lua
-- bound_prefix). gtimeout without -k sends SIGTERM only: a child that ignores SIGTERM ran on (two dumps of the coordinator's sdk run,
-- AdAttributionKit and AppIntents, ran 10 to 13 hours). Checked here: the command text carries -k (the escalation to SIGKILL), a
-- status of 124 or 137 (stopped by the bound) is reported as such, and a child that ignores SIGTERM is killed by the bound (the real
-- gtimeout, a 2-second bound with a 1-second escalation: it must end well inside 15 seconds, with status 137).
-- Run: xmake l tests/gen/dump_bound_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "dump-bound-test")

function main()
    local heavy_batch = import("gen.heavy_batch", {rootdir = TOOLS, anonymous = true})
    local swift_shard = import("gen.swift_shard", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    check(heavy_batch.bound_prefix(1800) == "gtimeout -k 30 1800", "the batch's bound text: " .. heavy_batch.bound_prefix(1800))

    local command = swift_shard.dump_command("/sdk", "arm64e-apple-ios26.2", "Fix", "", SCRATCH .. "/Fix", "shard")
    check(string.sub(command, 1, #"gtimeout -k 30 1800 xcrun ") == "gtimeout -k 30 1800 xcrun ",
          "a dump is bounded by -k (SIGKILL after 30 s more): " .. string.sub(command, 1, 60))

    -- a dump the bound stopped (124 after SIGTERM, 137 after SIGKILL) is a reported failure, not a missing JSON
    local folder = path.join(SCRATCH, "cache")
    os.rm(folder)
    for _, status in ipairs({"124", "137"}) do
        local base = path.join(folder, "shard", "api", "Fix")
        os.mkdir(path.directory(base))
        io.writefile(base .. ".status", status .. "\n")
        local root, reason = swift_shard.cached_root(folder, "shard", "Fix", "")
        check(root == nil and string.find(reason or "", "stopped at its time bound", 1, true) ~= nil,
              "status " .. status .. " is reported as stopped at the time bound: " .. tostring(reason))
    end

    -- the real mechanism: TERM is ignored by the child (exec: the sleep itself), so only the escalation ends it
    local started = os.time()
    local output = os.iorunv("sh", {"-c", "gtimeout -k 1 2 sh -c 'trap \"\" TERM; exec sleep 60'; echo $?"})
    local elapsed = os.time() - started
    check(string.match(output, "(%d+)%s*$") == "137", "a child that ignores SIGTERM is killed (status 137): " .. tostring(output))
    check(elapsed < 15, "the bound ends the child well inside 15 seconds: " .. elapsed .. " s")

    print("dump bound test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

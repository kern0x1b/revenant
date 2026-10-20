local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "dump-bound-test")

function main()
    local batch = import("gen.batch", {rootdir = TOOLS, anonymous = true})
    local swift_shard = import("gen.swift_shard", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    check(batch.bound_prefix(1800) == "gtimeout -k 30 1800", "the batch's bound text: " .. batch.bound_prefix(1800))

    local command = swift_shard.dump_command("/sdk", "arm64e-apple-ios26.2", "Fix", "", SCRATCH .. "/Fix", "shard")
    check(string.sub(command, 1, #"gtimeout -k 30 1800 xcrun ") == "gtimeout -k 30 1800 xcrun ",
          "a dump is bounded by -k (SIGKILL after 30 s more): " .. string.sub(command, 1, 60))

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

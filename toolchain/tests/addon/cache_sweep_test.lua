local function write_checkout(dir)
    os.mkdir(dir)
    os.mkdir(path.join(dir, "modules"))
    os.mkdir(path.join(dir, "modules", "apple"))
    io.writefile(path.join(dir, "modules", "apple", "dyld.lua"),
        "return {\n"
        .. "    held_ladder = function () return {} end,\n"
        .. "    kept_files = function (sdks, ladders, under) return { path.join(under or '.', 'kept.tsv') } end,\n"
        .. "    root = function () return '.' end,\n"
        .. "}\n")
    io.writefile(path.join(dir, "modules", "apple", "architectures.lua"),
        "return {\n"
        .. "    names = function () return {\"arm64\"} end,\n"
        .. "}\n")
    io.writefile(path.join(dir, "modules", "apple", "backports.lua"),
        "-- a module the sweep must survive\nfunction (\n")
end

function failures(opts)
    local out = {}
    local function fail(fmt, ...)
        print(string.format("  cache_sweep_test FAIL: " .. fmt, ...))
        out[#out + 1] = string.format(fmt, ...)
    end
    print("  cache_sweep_test: a checkout that does not load is named, skipped, and its cache kept")

    local sweep = import("cache-sweep", {rootdir = path.join(opts.modules, "..", "tools"), anonymous = true})
    if type(sweep) ~= "table" or type(sweep.sweep_checkout) ~= "function" then
        fail("tools/cache-sweep.lua must expose sweep_checkout for a caller to test, and it exposes %s",
             type(sweep) == "table" and type(sweep.sweep_checkout) or "no module")
        return out
    end

    local scratch = path.join(os.tmpdir(), "revenant-cache-sweep-test-" .. os.getpid())
    if os.isdir(scratch) then os.tryrm(scratch) end
    local checkout = path.join(scratch, "broken")
    local cache = path.join(scratch, "cache")
    write_checkout(checkout)
    os.mkdir(cache)

    local outcome, raised
    try {
        function ()
            outcome = sweep.sweep_checkout(checkout, {}, cache)
        end,
        catch {
            function (errors)
                raised = tostring(errors)
            end
        }
    }

    if raised then
        fail("a checkout whose modules do not load must be skipped, not raise, and it raised: %s", raised)
    else
        if type(outcome) ~= "table" then
            fail("sweep_checkout must return a table naming what it did, and it returned %s", type(outcome))
        else
            if not outcome.reason or not tostring(outcome.reason):find("backports.lua", 1, true) then
                fail("the checkout must be named with the load's first error line, and it said: %s",
                     tostring(outcome.reason))
            end
            if outcome.checkout ~= checkout then
                fail("the outcome must carry the checkout's own path, and it carried: %s", tostring(outcome.checkout))
            end
            if outcome.files then
                fail("a checkout that could not be read must keep its cache, and it reported %s file(s) to keep",
                     tostring(outcome.files and #outcome.files))
            end
        end
    end

    os.tryrm(scratch)
    if os.isdir(scratch) then
        fail("the suite must remove the scratch it made, and it is still there: %s", scratch)
    end
    return out
end

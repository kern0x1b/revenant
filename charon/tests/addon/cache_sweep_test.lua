-- A checkout whose own backports.lua does not load must be named, skipped, and its cache left whole: the
-- sweep cannot know what a checkout it cannot read needs, so it must neither guess nor delete. The other
-- two modules of the fixture are written by this suite and do load, so the broken backports.lua is the only
-- thing that can fail - otherwise the catch would pass for the wrong reason and prove nothing. The cache
-- root is a directory of this suite's own under the temp dir, never the sweep's ~/.charon, and it goes when
-- the run does.

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
    -- the one that does not load: a function that is never closed, so importing it is a syntax error
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

    -- The run's own folder: this suite writes a checkout and a cache under it and removes the folder when it is done,
    -- so a name two concurrent runs agree on is one run's files gone (a deleted test of that shape, measured
    -- 2026-10-04: eight of nine concurrent runs red with clang unable to open the fixture under its path).
    local scratch = path.join(os.tmpdir(), "charon-cache-sweep-test-" .. os.getpid())
    if os.isdir(scratch) then os.tryrm(scratch) end
    local checkout = path.join(scratch, "broken")
    local cache = path.join(scratch, "cache")
    write_checkout(checkout)
    os.mkdir(cache)

    -- no pcall in the xmake sandbox: a checkout that raises must come back as a value, not as a failed
    -- run of this suite, or the check cannot tell the two apart
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

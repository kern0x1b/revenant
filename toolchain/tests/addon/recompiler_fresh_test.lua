function failures(opts)
    local root = path.directory(path.directory(path.directory(os.scriptdir())))
    local fresh = import("fresh", {rootdir = path.join(root, "recompiler", "tools"), anonymous = true})
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: %s, not %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end
    local dir = path.join(os.tmpdir(), "recompiler-fresh-" .. os.time() .. "-" .. math.random(100000))
    os.mkdir(dir)
    local now = os.time()
    local function make(name, age)
        local file = path.join(dir, name)
        io.writefile(file, name)
        os.touch(file, {mtime = now - age, atime = now - age})
        return file
    end
    local binary = make("xlgen", 100)
    local old = make("old.cpp", 200)
    local same = make("same.cpp", 100)
    local newer = make("newer.cpp", 50)
    local newest = make("newest.cpp", 10)
    check("a tool built after its sources is fresh", fresh.newer_source(binary, {old}), nil)
    check("a source with the tool's own time is not newer", fresh.newer_source(binary, {old, same}), nil)
    check("a source changed after the tool was built is named", fresh.newer_source(binary, {old, newer}), newer)
    check("of several changed sources the newest is named", fresh.newer_source(binary, {newer, old, newest}), newest)
    check("a source that is not there is skipped", fresh.newer_source(binary, {path.join(dir, "gone.cpp"), old}), nil)
    check("no sources leave the tool fresh", fresh.newer_source(binary, {}), nil)
    os.rm(dir)
    local out = {}
    if failures > 0 then
        out[#out + 1] = string.format("%d failures", failures)
    end
    return out
end

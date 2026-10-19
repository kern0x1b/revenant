local REPO = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(REPO, "tools")
local ROOT = path.join(REPO, ".agent-work", "runs", "atomic-test")

local function raises(fn)
    local raised = false
    try {
        fn,
        catch {
            function() raised = true end
        }
    }
    return raised
end

local function names_in(dir)
    local out = {}
    for _, file in ipairs(os.files(path.join(dir, "*"))) do
        table.insert(out, path.filename(file))
    end
    table.sort(out)
    return out
end

local function same_names(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function test_foreign_siblings(check)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local dir = path.join(ROOT, "foreign")
    os.mkdir(dir)
    local target = path.join(dir, "out.txt")
    io.writefile(target, "old\n")
    local foreign, expected = {}, {"out.txt"}
    table.insert(foreign, target .. ".revenant-new")
    for n = 1, 64 do
        table.insert(foreign, target .. ".revenant-new." .. os.getpid() .. "." .. n)
    end
    for _, file in ipairs(foreign) do
        io.writefile(file, "foreign " .. path.filename(file))
        table.insert(expected, path.filename(file))
    end
    table.sort(expected)
    check(emit.file(target, "new\n") == true, "foreign siblings: the write is made")
    check(io.readfile(target) == "new\n", "foreign siblings: the target holds the new bytes")
    local intact = true
    for _, file in ipairs(foreign) do
        if not os.isfile(file) or io.readfile(file) ~= "foreign " .. path.filename(file) then
            intact = false
        end
    end
    check(intact, "foreign siblings: no other writer's sibling is overwritten")
    check(same_names(names_in(dir), expected), "foreign siblings: the write leaves no sibling of its own")
end

local function test_emit(check)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local dir = path.join(ROOT, "emit")
    os.mkdir(dir)
    local target = path.join(dir, "out.txt")
    local before = emit.count()
    check(emit.file(target, "same\n") == true, "emit: a new file is written")
    check(emit.count() == before + 1, "emit: the write is counted")
    check(emit.file(target, "same\n") == false, "emit: the same bytes are a no-op")
    check(emit.count() == before + 1, "emit: a no-op is not counted")
    check(io.readfile(target) == "same\n", "emit: the file holds the bytes")
    check(raises(function() emit.file(path.join(dir, "bad.txt"), "caf\195\169\n") end), "emit: non-ASCII text is refused")
    check(same_names(names_in(dir), {"out.txt"}), "emit: a refused write leaves nothing behind")
end

local function test_atomic(check)
    local atomic = import("atomic", {rootdir = TOOLS, anonymous = true})
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local dir = path.join(ROOT, "atomic")
    os.mkdir(dir)
    local target = path.join(dir, "out.txt")
    check(atomic.write(target, "same\n") == true, "atomic: a new file is written")
    check(atomic.write(target, "same\n") == false, "atomic: the same bytes are a no-op")
    check(atomic.write(target, "other\n") == true, "atomic: changed bytes are written")
    check(emit.file(target, "last\n") == true, "two writers of one path: the second writer writes")
    check(io.readfile(target) == "last\n", "two writers of one path: the last bytes are on disk")
    check(same_names(names_in(dir), {"out.txt"}), "two writers of one path leave no sibling")

    local ro = path.join(ROOT, "readonly")
    os.mkdir(ro)
    local kept = path.join(ro, "out.txt")
    io.writefile(kept, "old\n")
    os.execv("chmod", {"555", ro}, {try = true})
    local failed = raises(function() atomic.write(kept, "new\n") end)
    os.execv("chmod", {"755", ro}, {try = true})
    check(failed, "a write into a read-only directory raises")
    check(io.readfile(kept) == "old\n", "a failed write leaves the old file intact")
    check(same_names(names_in(ro), {"out.txt"}), "a failed write leaves no sibling")
end

function main()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.tryrm(ROOT)
    local crashed
    try {
        function()
            test_foreign_siblings(check)
            test_emit(check)
            test_atomic(check)
        end,
        catch {
            function(err)
                crashed = err
            end
        }
    }
    if os.isdir(path.join(ROOT, "readonly")) then
        os.execv("chmod", {"755", path.join(ROOT, "readonly")}, {try = true})
    end
    os.tryrm(ROOT)
    if crashed then
        raise("%s", crashed)
    end
    print("atomic test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

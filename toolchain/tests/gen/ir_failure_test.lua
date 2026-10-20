local REPO = path.absolute(path.join(os.scriptdir(), "..", ".."))
local RUNS = import("workspace", {rootdir = path.join(REPO, "modules"), anonymous = true}).run("ir-failure-test")
local fake = import("fake_decls", {rootdir = os.scriptdir(), anonymous = true})

local SHARD = table.concat({
    "#libclang=libclang-fixture\tsdk=iPhoneOS-fixture\tcolumns=kind,usr,container,name,side,type,params,attrs,availability,message,declhash",
    "function\tc:@F@Fixture\t-\t-\t-\tint\tvoid\t-\t-\t-\t1111111111111111",
    ""}, "\n")

local FAIL_BODY = "echo 'decls: Fixture: killed by SIGALRM' >&2; exit 142"

local UNPARSED_BODY
do
    local cells = {"Fixture", "unparsed", "-", "-", "no public header and no module map header"}
    for _ = #cells + 1, 21 do
        table.insert(cells, "-")
    end
    UNPARSED_BODY = "printf '" .. table.concat(cells, "\\t") .. "\\n'"
end

local function build(name, with_shard)
    local root = path.join(RUNS, name)
    os.tryrm(root)
    local spec = path.join(root, "spec")
    os.mkdir(path.join(spec, "Gone"))
    io.writefile(path.join(spec, "Gone", "declarations.tsv"), SHARD)
    if with_shard then
        os.mkdir(path.join(spec, "Fixture"))
        io.writefile(path.join(spec, "Fixture", "declarations.tsv"), SHARD)
    end
    local p = {root = root, spec = spec, sdk = path.join(root, "iPhoneOS-fixture.sdk"), decls = path.join(root, "decls"),
        unparsed = path.join(root, "unparsed.tsv"), conflicts = path.join(root, "conflicts.tsv"), full = path.join(root, "full-ir.tsv"),
        no_shard = path.join(root, "no-shard.tsv")}
    io.writefile(p.unparsed, "# the frameworks of the SDK with no declaration the extractor reads, and why: one line each\nOld\told reason\n")
    io.writefile(p.no_shard, "# the frameworks of the sweep with no shard that declare nothing of their own: computed by the sweep from the extractor's census\n")
    return p
end

local function snapshot(p)
    local state = {}
    for _, file in ipairs(os.files(path.join(p.spec, "**"))) do
        state[file] = io.readfile(file)
    end
    state[p.unparsed] = io.readfile(p.unparsed)
    return state
end

local function differences(before, after, root)
    local function rel(file)
        return file:sub(#root + 2)
    end
    local out = {}
    for file, bytes in pairs(before) do
        if after[file] == nil then
            table.insert(out, "removed " .. rel(file))
        elseif after[file] ~= bytes then
            table.insert(out, "changed " .. rel(file))
        end
    end
    for file in pairs(after) do
        if before[file] == nil then
            table.insert(out, "added " .. rel(file))
        end
    end
    table.sort(out)
    return out
end

local function run_driver(p, mode)
    local output, failure
    try {
        function ()
            output = os.iorunv("xmake", {"l", "./tools/found/ir.lua"}, {curdir = REPO, envs = {IR_DECLS = p.decls, IR_SDK = p.sdk,
                IR_SPEC = p.spec, IR_UNPARSED = p.unparsed, IR_CONFLICTS = p.conflicts, IR_FULL = p.full, IR_MODE = mode,
                IR_NO_SHARD = p.no_shard, IR_TIMEOUT = "5"}})
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    return failure, output
end

local function names_the_framework(failure)
    return failure ~= nil and failure:find("Fixture: decls did not finish", 1, true) ~= nil
end

function main()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local function cases()
        local a = build("write-fails", true)
        fake.write(a.decls, FAIL_BODY)
        local before = snapshot(a)
        local failure = run_driver(a, "write")
        check(names_the_framework(failure), "write mode raises, naming the framework, when decls fails")
        local diff = differences(before, snapshot(a), a.root)
        check(#diff == 0, "write mode leaves the tree unchanged when decls fails" .. (#diff > 0 and (": " .. table.concat(diff, ", ")) or ""))

        local b = build("check-fails", true)
        fake.write(b.decls, FAIL_BODY)
        before = snapshot(b)
        failure = run_driver(b, "check")
        check(names_the_framework(failure), "check mode raises, naming the framework, when decls fails")
        diff = differences(before, snapshot(b), b.root)
        check(#diff == 0, "check mode leaves the tree unchanged when decls fails" .. (#diff > 0 and (": " .. table.concat(diff, ", ")) or ""))

        local c = build("gives-no-shard", true)
        fake.write(c.decls, UNPARSED_BODY)
        before = snapshot(c)
        failure = run_driver(c, "write")
        check(failure ~= nil, "write mode raises when decls gives no shard for a framework that has a committed shard")
        diff = differences(before, snapshot(c), c.root)
        check(#diff == 0, "a committed shard is kept when decls gives it no shard" .. (#diff > 0 and (": " .. table.concat(diff, ", ")) or ""))

        local d = build("unparsed", false)
        fake.write(d.decls, UNPARSED_BODY)
        local output
        failure, output = run_driver(d, "write")
        check(failure == nil, "decls' own unparsed row is not a failure" .. (failure and (": " .. failure) or ""))
        check(io.readfile(d.unparsed):find("Fixture\tunparsed\tno public header and no module map header", 1, true) ~= nil,
            "decls' own unparsed row is recorded in unparsed.tsv")
        check(not os.isfile(path.join(d.spec, "Gone", "declarations.tsv")), "the shard of a framework decls no longer lists is removed")
        check(output ~= nil and output:find("removed 1 stale shards", 1, true) ~= nil, "the run reports the one stale shard it removed")
    end

    os.tryrm(RUNS)
    local crashed
    try {
        cases,
        catch {
            function (err)
                crashed = err
            end
        }
    }
    os.tryrm(RUNS)
    if crashed then
        raise("%s", crashed)
    end
    print("ir failure test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

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

function main()
    local headers = import("gen.headers", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local root = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true}).fresh("headers-test")
    local folder = path.join(root, "packages", "frameworks", "apple-backports", "spec", "Fixture")
    os.mkdir(folder)
    local shard = io.open(path.join(folder, "declarations.tsv"), "wb")
    shard:write("#libclang=test\tsdk=iPhoneOS26.2\tcolumns=declhash,usr,kind,side,name,container,availability,message\n")
    shard:write("1111111111111111\tc:objc(cs)Fixture(im)setLevel:\tmethod\t-\t\tFixture\tios=14.0/-/-/0\t-\n")
    shard:write("2222222222222222\tc:@T@FixtureFlag\ttypedef\t-\t\t-\t-\t-\n")
    shard:close()

    local rows = headers.shard_records(root, "Fixture")
    check(#rows == 2, "two rows are read from the fixture shard")
    check(rows[1].kind == "method" and rows[1].usr == "c:objc(cs)Fixture(im)setLevel:", "columns are read by their names, not by position")
    check(rows[1].name == "" and rows[1].side == "-" and rows[1].container == "Fixture", "an empty cell stays empty")
    check(rows[1].declhash == "1111111111111111" and rows[1].availability == "ios=14.0/-/-/0" and rows[1].message == "-",
          "the last cells read by name")
    check(rows[2].kind == "typedef" and rows[2].declhash == "2222222222222222", "a second row reads its own cells")
    check(#headers.shard_records(root, "NoSuchFramework") == 0, "a framework with no shard has no rows")

    local repo = path.join(os.scriptdir(), "..", "..")
    local real = headers.shard_facts(repo, "AVFAudio")
    local members, declared = 0, 0
    for _ in ipairs(real.members) do members = members + 1 end
    for _ in pairs(real.declared) do declared = declared + 1 end
    check(members == 656, "AVFAudio has 656 members (got " .. members .. ")")
    check(declared == 567, "AVFAudio has 567 declared names (got " .. declared .. ")")
    local empty = headers.shard_facts(repo, "NoSuchFramework")
    check(#empty.members == 0 and next_free_count(empty.declared) == 0, "a framework with no shard has no facts")

    os.rm(root)
    print("headers test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function next_free_count(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

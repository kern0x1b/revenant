-- The member rows built from shard facts (tools/gen/members.lua): the api, the key, the hash, the availability text and the tbd flag
-- of each row, on a fixture of the facts; and the real AVFAudio shard's member count through headers.shard_facts (656).
-- Run: xmake l tests/gen/members_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

function main()
    local members = import("gen.members", {rootdir = TOOLS, anonymous = true})
    local headers = import("gen.headers", {rootdir = TOOLS, anonymous = true})
    local byteorder = import("byteorder", {rootdir = path.join(TOOLS, "..", "modules"), anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local facts = {
        {cls = "Fixture", kind = "method", api = "-[Fixture setLevel:]", text = "API_AVAILABLE(ios(14.0))", hash = "aaaaaaaaaaaaaaaa"},
        {cls = "Fixture", kind = "property", api = "+[Fixture shared]", text = "", hash = "bbbbbbbbbbbbbbbb"},
        {cls = "Fixture", kind = "method", api = "-[Fixture setLevel:]", text = "dup", hash = "cccccccccccccccc"},
        {cls = "Other", kind = "method", api = "-[Other class]", text = "", hash = "dddddddddddddddd"},
    }
    local rows = members.rows(facts, {Fixture = true}, "Fixture")
    check(#rows == 3, "the first occurrence of each api is one row (got " .. #rows .. ")")
    check(rows[1].key == "Fixture_setLevel", "the instance key is the C identifier of the selector, with no trailing underscore (got " .. rows[1].key .. ")")
    check(rows[2].key == "class_Fixture_shared", "a class member's key starts with class_ (got " .. rows[2].key .. ")")
    check(rows[1].hash == "aaaaaaaaaaaaaaaa", "the hash is the declaration hash of the row")
    check(rows[1].availability == "API_AVAILABLE(ios(14.0))" and rows[2].availability == "-", "availability is the rendered text or -")
    check(rows[1].tbd == "class-exported" and rows[3].tbd == "class-not-exported", "tbd follows the class's export")
    check(rows[1].type == "-" and rows[1].decl == nil, "the spec row carries the member type, and no declaration text")

    check(members.rows(facts, nil, "Fixture")[1].tbd == "-", "without an SDK (no class set) the tbd column is -")

    local real = headers.shard_facts(path.join(TOOLS, ".."), "AVFAudio")
    check(#members.rows(real.members, {}, "AVFAudio") == 656, "AVFAudio's shard gives 656 member rows")

    -- the frameworks gen reads are the declaration shards, nested ones included, in byte order
    local snapshot = import("gen.spec", {rootdir = TOOLS, anonymous = true})
    local names = snapshot.frameworks(path.join(TOOLS, ".."))
    local found = {}
    for _, name in ipairs(names) do
        found[name] = true
    end
    check(found.AVFAudio and found["Accelerate/vImage"], "the shard list names AVFAudio and the nested Accelerate/vImage")
    local sorted = true
    for i = 2, #names do
        if byteorder.less(names[i], names[i - 1]) then
            sorted = false
        end
    end
    check(#names > 100 and sorted, "the shard list has every shard, in byte order (" .. #names .. " names)")

    print("members test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

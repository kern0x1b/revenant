-- The round trip's comparison and diagnostics (tools/gen/swift_roundtrip.lua), on our own fixture: the model of the fixture is the SDK's
-- side, and the other side is the same model with three known changes (one signature changed, one row dropped, one row added). A
-- compare that ignores a signature cell, or that loses a row, turns the test red. The compiler and the digester are not run here
-- (they need a toolchain); cmd_roundtrip runs them. Run: xmake l tests/gen/swift_roundtrip_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local json = import("core.base.json")

function main()
    local model = import("gen.swift_model", {rootdir = TOOLS, anonymous = true})
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local text = io.open(path.join(os.scriptdir(), "input", "fixtures", "swift", "model.json"), "rb"):read("a")
    local sdk_rows = assert(model.rows(json.decode(text).ABIRoot, "Fixture"))

    -- Ours is the same model with three changes: Box.describe() returns Int, Point.x is dropped, and a row nobody declared is added.
    local ours = {}
    for _, row in ipairs(sdk_rows) do
        if row.container == "Point" and row.name == "x" then
            -- dropped
        else
            local copy = {}
            for k, v in pairs(row) do
                copy[k] = v
            end
            if row.container == "Box" and row.name == "describe()" then
                copy.type = "Swift.Int"
            end
            table.insert(ours, copy)
        end
    end
    local extra = {}
    for k, v in pairs(sdk_rows[1]) do
        extra[k] = v
    end
    extra.usr, extra.container, extra.name, extra.kind = "s:7Fixture5ExtraV", "-", "Extra", "swift-struct"
    table.insert(ours, extra)

    local result = roundtrip.compare(sdk_rows, ours)
    check(result.sdk == #sdk_rows and result.ours == #ours, "the counts are the two sides' row counts")
    check(#result.missing == 1 and result.missing[1] == "swift-property Point.x", "a row the SDK has and ours lacks is missing")
    check(result.extra == 1, "a row ours has and the SDK lacks is extra")
    check(result.causes.type == 1 and string.find(result.examples.type, "Box.describe()", 1, true) ~= nil,
          "a changed result type is one cause, named by its row")
    check(result.equal == #sdk_rows - 2, "every matched row with no changed cell counts as equal")
    check(result.duplicates == 0, "no duplicate key is counted on a model without one")

    -- A duplicate key on our side is counted, not compared twice.
    local twice = {}
    for _, row in ipairs(sdk_rows) do
        table.insert(twice, row)
    end
    table.insert(twice, sdk_rows[1])
    check(roundtrip.compare(sdk_rows, twice).duplicates == 1, "a repeated key on our side is a duplicate")

    -- The measure: a list cell is a set (the dump's order and its repeated platform attribute do not count), and a stored property
    -- rendered computed is a by-design difference, counted apart; any other difference is still a mismatch.
    local function with(row, changes)
        local copy = {}
        for k, v in pairs(row) do
            copy[k] = v
        end
        for k, v in pairs(changes) do
            copy[k] = v
        end
        return copy
    end
    local base = sdk_rows[1]
    local listed = roundtrip.compare({with(base, {conformances = "Hashable,Equatable", attributes = "Available,Available,Final"})},
                                     {with(base, {conformances = "Equatable,Hashable", attributes = "Final,Available"})})
    check(listed.equal == 1 and listed.causes.conformances == nil and listed.causes.attributes == nil,
          "a list cell in another order, or with a repeated item, is equal")
    local stored = roundtrip.compare({with(base, {storage = "yes"})}, {with(base, {storage = "-"})})
    check(stored.by_design == 1 and stored.equal == 1 and stored.causes.storage == nil,
          "a stored property rendered computed is by design: counted apart, not a mismatch")
    -- a let is stored, and its storage attributes come with it: the same by-design difference, whatever the attribute order
    local let_rows = roundtrip.compare(
        {with(base, {storage = "yes", is_let = "yes", attributes = "HasInitialValue,HasStorage,Final"})},
        {with(base, {storage = "-", is_let = "-", attributes = "Final"})})
    check(let_rows.by_design == 1 and let_rows.equal == 1 and let_rows.causes.is_let == nil and let_rows.causes.attributes == nil,
          "a stored let rendered computed: its let and storage attributes are by design")
    local reversed = roundtrip.compare({with(base, {storage = "-"})}, {with(base, {storage = "yes"})})
    check(reversed.by_design == 0 and reversed.causes.storage == 1, "storage the SDK lacks and ours has is a mismatch")
    local attribute = roundtrip.compare({with(base, {attributes = "Final"})}, {with(base, {attributes = "ObjC"})})
    check(attribute.causes.attributes == 1 and attribute.equal == 0, "a different attribute is still a mismatch")

    -- The compiler's diagnostics: the count of errors and the first one, in order; a note is not an error.
    local count, first = roundtrip.diagnostics("a.swift:1:2: error: boom\nb.swift: note: here\nc.swift:3:4: error: second\n")
    check(count == 2 and first == "a.swift:1:2: error: boom", "the first error and the error count are read in order")
    count, first = roundtrip.diagnostics("")
    check(count == 0 and first == nil, "no output is no error")

    print("swift roundtrip test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

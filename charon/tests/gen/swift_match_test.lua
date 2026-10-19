-- The reconciliation of a module's Swift rows (tools/gen/swift_match.lua): the digester's rows (swift.tsv) with the interface text's
-- (swiftinterface.tsv). The rules under test: an exact match takes the interface's introduction, deprecation, obsoletion, unavailability
-- and via; a digester row the interface names under its outer types takes the qualified api when one fits; a digester row the interface
-- names with other labels takes the interface's labels when exactly one fits (and none when two do); an api the interface states twice
-- is one row with the earliest introduction; an interface api no digester row names is a row of its own (usr "-"); a digester row no
-- interface api fits keeps its own availability and takes nothing from a container. Run: xmake l tests/gen/swift_match_test.lua
-- (exits 1 on any failure).

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local match = import("gen.swift_match", {rootdir = TOOLS, anonymous = true})

-- A digester row of the Swift shard, as swift_model.lua's reader gives it to the model.
local function digester(kind, api, usr, introduced)
    return {framework = "Fixture", kind = kind, lang = "swift", api = api, usr = usr or "s:x", container = "-",
            introduced = introduced, deprecated = "-", obsoleted = "-", unavailable = "", getter = "-",
            via = introduced and "own" or "none"}
end

-- An interface row, as the interface shard's cells give it.
local function interface(kind, api, introduced, via, deprecated, unavailable)
    return {kind = kind, api = api, introduced = introduced or "", deprecated = deprecated or "", obsoleted = "",
            unavailable = unavailable or "", via = via or (introduced and "own" or "none")}
end

-- What a row reads as: kind, api, usr, introduced, via, deprecated, unavailable.
local function line_of(record)
    local function cell(value)
        return (value == nil or value == "") and "-" or value
    end
    return table.concat({record.kind, record.api, record.usr, cell(record.introduced), cell(record.via), cell(record.deprecated),
                         cell(record.unavailable)}, " ")
end

function main()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local digesters = {
        digester("method", "Exact.run()", "s:exact", "7.0"),
        digester("property", "Configuration.cornerStyle", "s:corner"),
        digester("property", "Twin.n", "s:twin"),
        digester("method", "Equal.==(_:_:)", "s:equal"),
        digester("method", "Tie.==(_:_:)", "s:tie"),
        digester("method", "Earliest.make()", "s:earliest"),
        digester("property", "Own.kept", "s:kept", "9.0"),
        digester("property", "Nothing.there"),
    }
    local interfaces = {
        interface("method", "Exact.run()", "9.0", "own", "10.0"),
        interface("property", "UIPasteControl.Configuration.cornerStyle", "16.0", "container"),
        interface("property", "A.Twin.n", "11.0", "own"),
        interface("property", "B.Twin.n", "12.0", "own"),
        interface("method", "Equal.==(a:b:)", "13.0", "own"),
        interface("method", "Tie.==(a:b:)", "13.0", "own"),
        interface("method", "Tie.==(x:y:)", "14.0", "own"),
        interface("method", "Earliest.make()", "17.0", "own"),
        interface("method", "Earliest.make()", "16.0", "own"),
        interface("property", "Extra.renamed", "18.0", "own"),
        interface("property", "Own.kept", nil),
    }

    local rows, counts = match.reconcile("Fixture", digesters, interfaces)
    local have = {}
    for _, record in ipairs(rows) do
        have[line_of(record)] = (have[line_of(record)] or 0) + 1
    end
    local want = {
        "method Exact.run() s:exact 9.0 own 10.0 -",
        "property UIPasteControl.Configuration.cornerStyle s:corner 16.0 container - -",
        "property Twin.n s:twin - none - -",
        "method Equal.==(a:b:) s:equal 13.0 own - -",
        "method Tie.==(_:_:) s:tie - none - -",
        "method Earliest.make() s:earliest 16.0 own - -",
        "property Own.kept s:kept 9.0 own - -",
        "property Nothing.there s:x - none - -",
        "property Extra.renamed - 18.0 own - -",
        -- Twin.n and Tie.==(_:_:) fit several interface apis: the digester row is kept, and each interface api is a row of its own
        "property A.Twin.n - 11.0 own - -",
        "property B.Twin.n - 12.0 own - -",
        "method Tie.==(a:b:) - 13.0 own - -",
        "method Tie.==(x:y:) - 14.0 own - -",
    }
    for _, text in ipairs(want) do
        check((have[text] or 0) == 1, "expected row " .. text)
        have[text] = nil
    end
    for text in pairs(have) do
        check(false, "unexpected row " .. text)
    end

    check(counts.exact == 3, "three digester rows match exactly (got " .. counts.exact .. ")")
    check(counts.qualified == 1, "one digester row matches by its qualified name (got " .. counts.qualified .. ")")
    check(counts.relabelled == 1, "one digester row matches by its labels (got " .. counts.relabelled .. ")")
    check(counts.digester_only == 3, "three digester rows match nothing (got " .. counts.digester_only .. ")")
    check(counts.ambiguous == 2, "two digester rows fit several interface apis, and are counted (got " .. counts.ambiguous .. ")")
    check(counts.interface_only == 5, "five interface apis are rows of their own (got " .. counts.interface_only .. ")")

    -- the module with no interface text: the digester's rows stand as they were, with their own availability only
    local alone, alone_counts = match.reconcile("Fixture", {digester("property", "Own.kept", "s:kept", "9.0")}, {})
    check(#alone == 1 and alone[1].api == "Own.kept" and alone[1].introduced == "9.0" and alone_counts.digester_only == 1,
          "a digester row with no interface text keeps its own introduction")

    print("swift match test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

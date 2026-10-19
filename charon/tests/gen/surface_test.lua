-- The surface computed from the model (tools/gen/surface_model.lua) on a fixture tree: which declarations arrived after iOS 6.1, with
-- the via, the unavailability, the getter and the deprecation each one gets. The rules under test: an own availability; a member's
-- class in the same framework (container); an ObjC category member's class floor, across frameworks (class-floor); a Swift row's
-- introduction from the interface text (its own, or its enclosing type's, through a nested type), with the interface's qualified name
-- and labels, a member only the interface has, and no introduction for a Swift row the text does not state; the boundary (6.1 is not
-- after 6.1); and the order of the rows. The fixture is
-- written into .agent-work/runs of this checkout with a copy of tools/, as gen_test does. Run: xmake l tests/gen/surface_test.lua
-- (exits 1 on any failure).

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local shards = import("surface_shards", {rootdir = os.scriptdir(), anonymous = true})
local decl, swift = shards.objc_row, shards.swift_row
-- The crash demand: FXNew by its api (telegram among its callers); FXFunction by its linker symbol, which has the underscore.
local DEMAND = "rank\tseverity\tapi\tkind\tframework\tapps\tcrash_callers\n"
    .. "3\tLOAD-FAIL\tFXNew\tclass\tFixAlpha\t2\tprovenance,telegram\n"
    .. "1\tCRASH\t_FXFunction\tfunction\tFixAlpha\t5\tfoo\n"

local ALPHA_OBJC = {
    decl("interface", "c:objc(cs)FXOld", nil, nil, nil, "ios=6.0/-/-/0"),
    decl("interface", "c:objc(cs)FXNew", nil, nil, nil, "ios=7.0/-/-/0,macos=10.9/-/-/0"),
    decl("method", "c:objc(cs)FXNew(im)doThing", nil, nil, nil, "-"),
    decl("method", "c:objc(cs)FXNew(cm)make", nil, nil, nil, "ios=9.0/-/-/0"),
    decl("method", "c:objc(cs)FXOld(im)legacy", nil, nil, nil, "-"),
    decl("property", "c:objc(cs)FXNew(py)label", nil, "", "nonatomic,getter=isLabelled", "-"),
    -- a class property and an instance property of one name: two declarations (two usrs), two rows
    decl("property", "c:objc(cs)FXNew(cpy)shared", nil, "", nil, "ios=12.0/-/-/0"),
    decl("property", "c:objc(cs)FXNew(py)shared", nil, "", nil, "ios=12.0/-/-/0"),
    -- an ObjC property the Swift property of the same name bridges to: the Swift one has no introduction of its own in the interface
    -- text, so it has none in the surface (no bridged fallback)
    decl("property", "c:objc(cs)FXNew(py)bridged", nil, "", nil, "ios=12.0/-/-/0"),
    -- a category that declares the label property again: the same usr, an exact repeat, dropped once
    decl("property", "c:objc(cs)FXNew(py)label", "FXNew@Ext3", "", nil, "ios=7.0/-/-/0"),
    decl("category", "c:objc(cy)FXOld@Ext", nil, nil, nil, "ios=9.0/-/-/0"),
    decl("method", "c:objc(cs)FXOld(im)extOld", "FXOld@Ext", nil, nil, "-"),
    decl("method", "c:objc(cs)FXNew(im)extNew", "FXNew@Ext2", nil, nil, "-"),
    decl("var", "c:@FXConstant", nil, nil, nil, "ios=8.0/-/-/0"),
    decl("var", "c:@FXOldConst", nil, nil, nil, "ios=5.0/-/-/0"),
    decl("function", "c:FXHeader.h@F@FXFunction", nil, nil, nil, "ios=10.0/-/-/0"),
    decl("interface", "c:objc(cs)FXGone", nil, nil, nil, "ios=-/-/-/1,macos=10.9/-/-/0"),
    decl("method", "c:objc(cs)FXNew(im)gone", nil, nil, nil, "ios=9.0/-/-/1"),
    decl("struct", "c:@S@FXStruct", nil, nil, nil, "ios=8.0/-/-/0"),
    decl("interface", "c:objc(cs)FXDep", nil, nil, nil, "ios=7.0/8.0/-/0"),
    decl("enum", "c:@E@FXEnum", nil, nil, nil, "ios=9.0/-/-/0"),
    decl("enumconst", "c:@E@FXEnum@FXEnum_A", "FXEnum", nil, nil, "-"),
    decl("protocol", "c:objc(pl)FXProto", nil, nil, nil, "ios=7.5/-/-/0"),
    decl("method", "c:objc(pl)FXProto(im)protoDo", nil, nil, nil, "-"),
    decl("interface", "c:objc(cs)FXEdge", nil, nil, nil, "ios=6.1/-/-/0"),
}

local BETA_OBJC = {
    decl("method", "c:objc(cs)FXNew(im)betaExt", "FXNew@BetaExt", nil, nil, "-"),
}

-- A nested framework's shard: its rows are the outer framework's.
local SUB_OBJC = {
    decl("interface", "c:objc(cs)FXSub", nil, nil, nil, "ios=8.0/-/-/0"),
}

local ALPHA_SWIFT = {
    swift("FixAlpha", "struct", "s:FXSwift", "-", "FXSwift", "ios=8.0,tvos=9.0"),
    swift("FixAlpha", "method", "s:FXSwift.doIt", "FXSwift", "doIt(x:)", "-"),
    swift("FixAlpha", "struct", "s:FXSwiftOld", "-", "FXSwiftOld", "ios=5.0"),
    swift("FixAlpha", "method", "s:FXSwiftOld.old", "FXSwiftOld", "old()", "-"),
    swift("FixAlpha", "struct", "s:FXSwift.Inner", "FXSwift", "Inner", "-"),
    swift("FixAlpha", "method", "s:FXSwift.Inner.run", "FXSwift.Inner", "run()", "-"),
    swift("FixAlpha", "function", "s:fxSwiftFunc", "-", "fxSwiftFunc(_:)", "ios=12.0"),
    swift("FixAlpha", "protocol", "s:FXSwiftProto", "-", "FXSwiftProto", "ios=13.0"),
    swift("FixAlpha", "typealias", "s:FXAlias", "-", "FXAlias", "ios=6.0"),
    -- a usr FixAlpha and FixGamma both hold: its module is FixAlpha, so FixAlpha owns it and FixGamma's row is dropped
    swift("FixAlpha", "struct", "s:8FixAlpha5Thing", "-", "Thing", "ios=9.0"),
    -- a usr both hold whose module neither is: no owner, so both rows are kept
    swift("FixAlpha", "struct", "s:5Other6Shared", "-", "Shared", "ios=9.0"),
    -- a nested enum and its case: the case's api is qualified by both types
    swift("FixAlpha", "enum", "s:FXSwift.Modes", "FXSwift", "Modes", "-"),
    swift("FixAlpha", "constant", "s:FXSwift.Modes.FXEnumNew", "FXSwift.Modes", "FXEnumNew", "-"),
    -- the operator's labels are the digester's (_:_:); the interface spells them (a:b:), and the row takes the interface's
    swift("FixAlpha", "method", "s:FXSwift.eq", "FXSwift", "==(_:_:)", "-"),
    -- two overloads the digester names alike: two declarations (two usrs), two rows
    swift("FixAlpha", "method", "s:FXSwift.over1", "FXSwift", "over(_:)", "ios=12.0"),
    swift("FixAlpha", "method", "s:FXSwift.over2", "FXSwift", "over(_:)", "ios=12.0"),
    -- the Swift property of an ObjC property, declared in an extension with no availability of its own
    swift("FixAlpha", "property", "s:FXNew.bridged", "FXNew", "bridged", "-"),
}

-- The Swift interface text of FixAlpha: the declarations the digester dump above names, with the availability the SDK's text gives them
-- (an extension's or a type's @available reaches its members), and one member the dump leaves out (renamed).
local ALPHA_INTERFACE = [[
@available(iOS 8.0, tvOS 9.0, *)
public struct FXSwift {
    public func doIt(x: Int) {}
    public static func == (a: FXSwift, b: FXSwift) -> Bool { true }
    @available(iOS 12.0, *)
    public func over(_ x: Int) {}
    @available(iOS 12.0, *)
    public func over(_ x: String) {}
    @available(iOS 12.0, *)
    public var renamed: Int { get { 0 } }
    public struct Inner {
        public func run() {}
    }
    public enum Modes {
        case FXEnumNew
    }
}
@available(iOS 5.0, *)
public struct FXSwiftOld {
    public func old() {}
}
@available(iOS 12.0, *)
public func fxSwiftFunc(_ x: Int) {}
@available(iOS 13.0, *)
public protocol FXSwiftProto {}
@available(iOS 6.0, *)
public typealias FXAlias = Int
extension FXNew {
    public var bridged: Int { get { 0 } }
}
]]

local GAMMA_SWIFT = {
    swift("FixGamma", "struct", "s:GSwift", "-", "GSwift", "ios=14.0"),
    swift("FixGamma", "struct", "s:8FixAlpha5Thing", "-", "Thing", "ios=9.0"),
    swift("FixGamma", "struct", "s:5Other6Shared", "-", "Shared", "ios=9.0"),
}

-- The rows the surface holds, as "framework kind lang api introduced via unavailable getter deprecated" ("-" where empty).
local EXPECTED = {
    "FixAlpha class objc FXNew 7.0 own - - -",
    "FixAlpha method objc -[FXNew doThing] 7.0 container - - -",
    "FixAlpha method objc +[FXNew make] 9.0 own - - -",
    "FixAlpha property objc FXNew.label 7.0 container - isLabelled -",
    "FixAlpha method objc -[FXNew extNew] 7.0 class-floor - - -",
    "FixAlpha constant objc FXConstant 8.0 own - - -",
    "FixAlpha function objc FXFunction() 10.0 own - - -",
    "FixAlpha method objc -[FXNew gone] 9.0 own yes - -",
    "FixAlpha struct objc FXStruct 8.0 own - - -",
    "FixAlpha class objc FXDep 7.0 own - - 8.0",
    "FixAlpha protocol objc FXProto 7.5 own - - -",
    "FixAlpha method objc -[FXProto protoDo] 7.5 container - - -",
    "FixBeta method objc -[FXNew betaExt] 7.0 class-floor - - -",
    "FixAlpha struct swift FXSwift 8.0 own - - -",
    "FixAlpha method swift FXSwift.doIt(x:) 8.0 container - - -",
    "FixAlpha struct swift FXSwift.Inner 8.0 container - - -",
    "FixAlpha method swift FXSwift.Inner.run() 8.0 container - - -",
    "FixAlpha function swift fxSwiftFunc(_:) 12.0 own - - -",
    "FixAlpha protocol swift FXSwiftProto 13.0 own - - -",
    "FixAlpha enum swift FXSwift.Modes 8.0 container - - -",
    "FixAlpha constant swift FXSwift.Modes.FXEnumNew 8.0 container - - -",
    "FixGamma struct swift GSwift 14.0 own - - -",
    "FixAlpha struct swift Thing 9.0 own - - -",
    "FixAlpha struct swift Shared 9.0 own - - -",
    "FixGamma struct swift Shared 9.0 own - - -",
    "FixAlpha enum objc FXEnum 9.0 own - - -",
    "FixAlpha constant objc FXEnum_A 9.0 container - - -",
    "FixAlpha class objc FXSub 8.0 own - - -",
    "FixAlpha method swift FXSwift.==(a:b:) 8.0 container - - -",
    "FixAlpha property objc FXNew.shared 12.0 own - - -",
    "FixAlpha property objc FXNew.shared 12.0 own - - -",
    "FixAlpha property objc FXNew.bridged 12.0 own - - -",
    "FixAlpha method swift FXSwift.over(_:) 12.0 own - - -",
    "FixAlpha method swift FXSwift.over(_:) 12.0 own - - -",
    -- a member the dump leaves out, which the interface text has
    "FixAlpha property swift FXSwift.renamed 12.0 own - - -",
}

-- A version as a number, for the order of the rows: 6.1 is 601, 7.5 is 705.
local function number(text)
    local major, minor = string.match(text, "^(%d+)%.?(%d*)")
    return tonumber(major) * 100 + (tonumber(minor) or 0)
end

local function checks()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end
end

local function line_of(record)
    local function cell(value)
        return (value == nil or value == "") and "-" or value
    end
    return table.concat({record.framework, record.kind, record.lang, record.api, record.introduced, record.via,
                         cell(record.unavailable == "yes" and "yes" or nil), cell(record.getter), cell(record.deprecated)}, " ")
end

function main()
    local check, failures = checks()
    local surface_model = import("gen.surface_model", {rootdir = TOOLS, anonymous = true})
    local corpus_fixture = import("surface_corpus", {rootdir = os.scriptdir(), anonymous = true})
    local root = path.join(os.scriptdir(), "..", "..", ".agent-work", "runs", "surface-test-" .. tostring(os.time()) .. "-"
                           .. tostring(math.random(1000000)))
    local tree = path.join(root, "tree")
    os.mkdir(tree)
    os.cp(TOOLS, path.join(tree, "tools"))
    os.cp(path.join(TOOLS, "..", "modules"), path.join(tree, "modules"))

    shards.write(tree, "FixAlpha", ALPHA_OBJC, ALPHA_SWIFT)
    shards.write_interface(tree, "FixAlpha", ALPHA_INTERFACE)
    shards.write(tree, "FixBeta", BETA_OBJC, nil)
    shards.write(tree, "FixGamma", nil, GAMMA_SWIFT)
    shards.write(tree, "FixAlpha/Sub", SUB_OBJC, nil)

    -- the corpus: the crash demand (FXNew and FXFunction) and the file lists (WinObjC lists FXNew's file)
    local corpus = path.join(root, "corpus")
    corpus_fixture.write(corpus, DEMAND, {["microsoft/WinObjC"] = {"Frameworks/FixAlpha/FXNew.m"}})

    local names = surface_model.frameworks(tree)
    check(#names == 3 and names[1] == "FixAlpha" and names[2] == "FixBeta" and names[3] == "FixGamma",
          "the frameworks are the three shards, in byte order (got " .. table.concat(names, ",") .. ")")

    -- the absent list (spec/framework-verdicts-6.1.3.tsv, verdict absent): FixGamma is absent from 6.1.3; FixBeta has no ledger and is not
    -- absent, so not checked
    local surface = import("gen.surface", {rootdir = TOOLS, anonymous = true})
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    emit.file(path.join(tree, "packages", "a", "apple-backports", "spec", "framework-verdicts-6.1.3.tsv"),
              "framework\tverdict\tcheckable\tpresent\treason\n"
              .. "FixGamma\tabsent\t1\t0\tfixture: no runtime symbol in the 6.1.3 cache\n"
              .. "FixBeta\tundecided\t0\t0\tfixture: no runtime declaration\n")
    check(surface.unlisted_state(tree, "FixGamma") == "absent at 6.1.3", "a framework on the absent list: its unlisted rows are absent")
    -- a release folder that is an absolute path is the folder itself (ledger --rows writes there); a relative one is under the corpus
    check(surface.ledger_file("/corpus", "/rows", "Foo/Bar") == "/rows/Foo_Bar.tsv", "an absolute release folder is read where it is")
    check(surface.ledger_file("/corpus", "ledger-w45", "Foo/Bar") == "/corpus/ledger-w45/Foo_Bar.tsv",
          "a relative release folder is under the corpus, a nested framework's slash an underscore")
    check(surface.unlisted_state(tree, "FixBeta") == "not checked at 6.1.3", "a framework not on the list: its unlisted rows are not checked")

    local rows, repeats, _, cross = surface_model.rows(tree, corpus, shards.release())
    check(repeats == 1, "one exact repeat (the category's usr that the class declares) is dropped (got " .. repeats .. ")")
    local holders_of = {}
    for _, record in ipairs(rows) do
        if record.api == "Thing" or record.api == "Shared" then
            holders_of[record.api] = (holders_of[record.api] or "") .. record.framework .. " "
        end
    end
    check(holders_of["Thing"] == "FixAlpha " and holders_of["Shared"] == "FixAlpha FixGamma ",
          "a usr two frameworks hold is one row in its owning framework (the module it names), and kept in both when no one owns it")
    check(cross.usrs == cross.undecided_usrs + 1 and cross.dropped >= 1 and cross.undecided_rows >= 2,
          "the cross-framework counts name the dropped and the undecided rows (got usrs " .. cross.usrs .. ", dropped " .. cross.dropped
          .. ", undecided " .. cross.undecided_usrs .. ")")
    local per_api = {}
    for _, record in ipairs(rows) do
        per_api[record.api] = (per_api[record.api] or 0) + 1
    end
    check(per_api["FXNew.label"] == 1 and per_api["FXNew.shared"] == 2 and per_api["FXSwift.over(_:)"] == 2,
          "a repeat counts once, and a class and an instance property, or two overloads, are a row each")
    local by_api = {}
    for _, record in ipairs(rows) do
        by_api[record.kind .. " " .. record.api] = record
    end
    local fx_new = by_api["class FXNew"]
    check(fx_new ~= nil and fx_new["demand-rank"] == "3" and fx_new["demand-apps"] == "2" and fx_new["demand-telegram"] == "yes",
          "a class with a demand row takes its rank, apps and telegram")
    check(fx_new ~= nil and fx_new["impl-lead"] == "WinObjC"
          and fx_new["impl-file-lead"] == "microsoft/WinObjC:Frameworks/FixAlpha/FXNew.m",
          "a class takes the lead of its file in a repository that stands for its framework")
    local fx_function = by_api["function FXFunction()"]
    check(fx_function ~= nil and fx_function["demand-rank"] == "1" and fx_function["demand-apps"] == "5"
          and fx_function["demand-telegram"] == "" and fx_function["impl-lead"] == "",
          "a function takes the demand of its linker symbol, and no telegram or lead it does not have")
    local fx_struct = by_api["struct FXStruct"]
    check(fx_struct ~= nil and fx_struct["demand-rank"] == "" and fx_struct["demand-apps"] == "",
          "a row no demand names has empty demand cells")

    local got, want = {}, {}
    for _, record in ipairs(rows) do
        table.insert(got, line_of(record))
    end
    for _, text in ipairs(EXPECTED) do
        table.insert(want, text)
    end
    table.sort(got)
    table.sort(want)
    local have = {}
    for _, text in ipairs(got) do
        have[text] = (have[text] or 0) + 1
    end
    for _, text in ipairs(want) do
        if have[text] == nil or have[text] == 0 then
            check(false, "missing row: " .. text)
        else
            have[text] = have[text] - 1
        end
    end
    for text, count in pairs(have) do
        for _ = 1, count do
            check(false, "unexpected row: " .. text)
        end
    end
    check(#rows == #EXPECTED, "the surface holds " .. #EXPECTED .. " rows (got " .. #rows .. ")")

    local sorted = true
    for index = 2, #rows do
        if number(rows[index - 1].introduced) > number(rows[index].introduced) then
            sorted = false
        end
    end
    check(sorted, "the rows come out in the order of their introduction")
    check(rows[1] ~= nil and rows[1].introduced == "7.0", "the first row is the earliest introduction (7.0)")

    local text = surface_model.table_text(rows)
    local header = string.match(text, "^[^\n]*")
    check(header == "framework\tkind\tlang\tapi\tusr\tintroduced\tdeprecated\tobsoleted\tunavailable\tvia\tgetter\tdemand-rank"
          .. "\tdemand-severity\tdemand-apps\tdemand-telegram\timpl-lead\timpl-file-lead",
          "the table's header has the surface and enrichment columns in order")
    local _, lines = string.gsub(text, "\n", "\n")
    check(lines == #rows + 1, "the table has one line per row and the header")

    os.rm(root)
    print("surface test: " .. (failures() == 0 and "OK" or ("FAIL " .. failures())))
    if failures() > 0 then
        os.exit(1)
    end
end

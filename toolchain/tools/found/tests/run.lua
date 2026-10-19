local ROOT = path.absolute(os.scriptdir())
local FOUND = path.directory(ROOT)
local REPO = path.directory(path.directory(FOUND))
local IR = path.join(FOUND, "ir.lua")
local GOLDEN = path.join(ROOT, "expected")
local SPEC = path.join(REPO, "build", "found", "test-spec")
local shard = import("shard", {rootdir = FOUND, anonymous = true})
local host = import("gen.host", {rootdir = path.join(REPO, "tools"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(REPO, "modules"), anonymous = true})
local checks = 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then raise("test failed: " .. message) end
end

local DECLS = host.target_product(REPO, FOUND, "decls")
assert(os.isfile(DECLS), "the extractor is not built: " .. DECLS .. " (xmake -P tools/found)")
local FIXTURE_SDK = path.join(ROOT, "fixture", "sdk")

local TOKEN = "#libclang=<decls --version>"
local fixture_identity = (os.iorunv(DECLS, {"--version"}, {envs = {IR_SDK = FIXTURE_SDK}}):gsub("%s+$", ""))
os.tryrm(SPEC)
for _, file in ipairs(os.files(path.join(GOLDEN, "**", "declarations.tsv"))) do
    local golden = io.readfile(file)
    local name = path.relative(file, GOLDEN)
    expect(golden:sub(1, #TOKEN) == TOKEN, "the golden shard " .. name .. " holds the token, not an identity of its own")
    local target = path.join(SPEC, name)
    os.mkdir(path.directory(target))
    io.writefile(target, "#libclang=" .. fixture_identity .. golden:sub(#TOKEN + 1))
end
local function module_names()
    local names = {}
    for line in os.iorunv(DECLS, {"--list"}, {envs = {IR_SDK = FIXTURE_SDK}}):gmatch("[^\n]+") do
        table.insert(names, line:match("^([^\t]+)"))
    end
    return table.concat(names, " ")
end
expect(os.iorunv(DECLS, {"FixtureSub"}, {envs = {IR_SDK = FIXTURE_SDK}}):find("sub_value", 1, true) ~= nil,
    "a framework of System/Library/SubFrameworks is in the sweep (derived from the SDK layout) and its declarations are read")
expect(os.iorunv(DECLS, {"FixtureFallback"}, {envs = {IR_SDK = FIXTURE_SDK}}):find("extra_value", 1, true) ~= nil,
    "a framework with no module map reads every header of its Headers/ folder, not only its umbrella")
expect(module_names() == "Broken Fixture Fixture/Inner FixtureC FixtureCExtra FixtureDotted FixtureFallback FixtureRoot FixtureSub FixtureUmbrella FixtureUmbrella/FixtureNested NoHeader Plain Swiftonly",
    "the sweep lists every top-level module the maps declare (FixtureCExtra and FixtureRoot too: no reviewed list leaves one out)")
local root_rows = os.iorunv(DECLS, {"FixtureRoot"}, {envs = {IR_SDK = FIXTURE_SDK}})
expect(root_rows:find("FixtureRootInt", 1, true) ~= nil, "a usr/include module owns the declarations of its own header in the include root")
expect(root_rows:find("root_other_function", 1, true) == nil and root_rows:find("FixtureRootOtherLong", 1, true) == nil,
    "a header of the include root that the module does not name is not the module's own (its declarations are left out)")

expect(os.iorunv(DECLS, {"Plain"}, {envs = {IR_SDK = FIXTURE_SDK}}):find("plain_value", 1, true) ~= nil,
    "a framework with no module map is read from its Headers/ folder, with no list naming it")

expect(os.iorunv(DECLS, {"FixtureDotted"}, {envs = {IR_SDK = FIXTURE_SDK}}):find("dotted_value", 1, true) ~= nil,
    "a submodule named with a dot is not a top-level module: FixtureDotted is read from its own map alone")

local umbrella_census = os.iorunv(DECLS, {"FixtureUmbrella"}, {envs = {IR_SDK = FIXTURE_SDK}})
expect(umbrella_census:find("own=0", 1, true) ~= nil and umbrella_census:find("nested_value", 1, true) == nil,
    "a nested framework's declaration reached through ../Frameworks is not the umbrella's own (census own=0; got " .. umbrella_census:gsub("\n", " | ") .. ")")
local census_files, census_files_total, nested_census_file = 0, 0, nil
for line in umbrella_census:gmatch("[^\n]+") do
    local cells = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(cells, cell) end
    if cells[2] == "census-file" then
        census_files = census_files + 1
        census_files_total = census_files_total + tonumber(cells[11]:match("count=(%d+)"))
        if cells[5]:find("FixtureNested", 1, true) then nested_census_file = cells[5] end
    end
end
expect(census_files > 0 and census_files_total == tonumber(umbrella_census:match("foreign=(%d+)")),
    "the census-file rows count every foreign declaration of the census (" .. census_files_total .. " of " .. tostring(umbrella_census:match("foreign=(%d+)")) .. ")")
expect(nested_census_file ~= nil and nested_census_file:sub(1, 1) ~= "/" and nested_census_file:find("FixtureNested.framework/Headers/", 1, true) ~= nil,
    "the census names the nested framework's header under the SDK root (got " .. tostring(nested_census_file) .. ")")

local function named_rows(file)
    local names = {}
    for line in io.lines(file) do
        local name = line:match("^([^\t#][^\t]*)\t")
        if name then names[name] = true end
    end
    return names
end
local unparsed_names = named_rows(path.join(ROOT, "unparsed.tsv"))
local computed_names = named_rows(path.join(ROOT, "no-shard.tsv"))
local swept, unclassified = {}, {}
for line in os.iorunv(DECLS, {"--list"}, {envs = {IR_SDK = FIXTURE_SDK}}):gmatch("[^\n]+") do
    local name = line:match("^([^\t]+)")
    swept[name] = true
    if not os.isfile(path.join(SPEC, name, "declarations.tsv")) and not unparsed_names[name] and not computed_names[name] then
        table.insert(unclassified, name)
    end
end
byteorder.sort(unclassified)
expect(#unclassified == 0, "a framework with no shard is classified (unparsed.tsv or no-shard.tsv); unclassified: " .. table.concat(unclassified, " "))
for name in pairs(computed_names) do
    expect(swept[name] and not os.isfile(path.join(SPEC, name, "declarations.tsv")),
        name .. " is listed in no-shard.tsv but is not a framework of the sweep without a shard")
end

local value_lines = {}
for line in io.lines(path.join(SPEC, "Fixture", "declarations.tsv")) do table.insert(value_lines, line) end
expect(value_lines[1]:match("columns=([^\t\n]*)") == "kind,usr,container,name,side,type,params,attrs,availability,message,declhash,value",
    "the shard header names a value column, after declhash")
local enum_value, others_dash = {}, true
for i = 2, #value_lines do
    local cells = {}
    for c in (value_lines[i] .. "\t"):gmatch("([^\t]*)\t") do table.insert(cells, c) end
    if cells[1] == "enumconst" then
        enum_value[cells[2]] = cells[12]
    elseif cells[12] ~= "-" then
        others_dash = false
    end
end
expect(enum_value["c:@E@FXState@FXStateOn"] == "1" and enum_value["c:@E@FXState@FXStateOff"] == "2" and others_dash,
    "an enum constant's row carries its clang value (FXStateOn 1, FXStateOff 2) and every other row has - in the value column")
for usr, want in pairs({
    ["c:@E@FXByte@FXByteTop"] = "255",
    ["c:@E@FXWord@FXWordAll"] = "18446744073709551615",
    ["c:@E@FXWide@FXWideTop"] = "9223372036854775808",
    ["c:@E@FXMask@FXMaskClass"] = "4026531840",
    ["c:@E@FXSigned@FXSignedBelow"] = "-1"}) do
    expect(enum_value[usr] == want, "the enum constant " .. usr .. " has the value " .. want .. " (got " .. tostring(enum_value[usr]) .. ")")
end

os.runv("mkdir", {"-p", path.join(REPO, "build", "found", "test-config")})
local stale_table = path.join(REPO, "build", "found", "test-config", "no-shard-empty.tsv")
local stale_file = assert(io.open(stale_table, "w")); stale_file:write("# none\n"); stale_file:close()
local function check_fixture(no_shard)
    return os.runv("xmake", {"l", IR}, {envs = {IR_SDK = path.join(ROOT, "fixture", "sdk"),
        IR_MODE = "check", IR_SPEC = SPEC, IR_CONFLICTS = path.join(ROOT, "conflicts.tsv"), IR_UNPARSED = path.join(ROOT, "unparsed.tsv"),
        IR_NO_SHARD = no_shard}})
end
local computed_failure = nil
try {
    function () check_fixture(path.join(ROOT, "no-shard.tsv")) end,
    catch {
        function (errors) computed_failure = tostring(errors) end
    }
}
expect(computed_failure == nil, "FixtureUmbrella is computed into no-shard.tsv and the check passes against the golden table: "
    .. tostring(computed_failure))
local refusal = nil
try {
    function () check_fixture(stale_table) end,
    catch {
        function (errors) refusal = tostring(errors) end
    }
}
expect(refusal ~= nil and refusal:find("no-shard-empty.tsv", 1, true) ~= nil,
    "ir.lua refuses a no-shard table that does not hold the computed rows, and the error names the table")

local FULL = path.join(REPO, "build", "found", "test-ir.tsv")
os.runv("xmake", {"l", IR}, {envs = {IR_SDK = path.join(ROOT, "fixture", "sdk"), IR_MODE = "check",
    IR_SPEC = SPEC, IR_CONFLICTS = path.join(ROOT, "conflicts.tsv"), IR_UNPARSED = path.join(ROOT, "unparsed.tsv"),
    IR_NO_SHARD = path.join(ROOT, "no-shard.tsv"), IR_FULL = FULL}})
checks = checks + 1

local function decl_of(usr)
    for line in io.lines(FULL) do
        local c = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
        if c[3] == usr then return c[17] end
    end
    return nil
end

local function full_of(usr)
    for line in io.lines(FULL) do
        local c = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
        if c[3] == usr then return c end
    end
    return nil
end

local rows = {}
for _, file in ipairs({path.join(SPEC, "Fixture", "declarations.tsv"), path.join(SPEC, "Fixture", "Inner", "declarations.tsv")}) do
    local framework = file:find("/Inner/", 1, true) and "Fixture/Inner" or "Fixture"
    for line in io.lines(file) do
        if not line:find("^#") then
            local c = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
            expect(#c == 12, "every shard row has 12 columns (the value is the twelfth): " .. line)
            local name, side = shard.decode(c[1], c[2], c[4], c[5])
            table.insert(rows, {framework = framework, kind = c[1], usr = c[2], container = c[3], name = name, side = side,
                type = c[6], params = c[7], attrs = c[8], avail = c[9], message = c[10], hash = c[11]})
        end
    end
end

local function find(predicate)
    local out = {}
    for _, r in ipairs(rows) do
        if predicate(r) then table.insert(out, r) end
    end
    return out
end

local function count(predicate, expected, message)
    expect(#find(predicate) == expected, message .. " (found " .. #find(predicate) .. ")")
end

count(function (r) return r.usr == "c:@F@FXRun" end, 1, "FXRun is one function")
expect(decl_of("c:@F@FXRun") == "void FXRun(int total)", "FXRun is emitted from Repeat.h")
count(function (r) return r.usr == "c:Repeat.h@T@FXCount" and r.kind == "typedef" end, 1, "FXCount is one typedef")
expect(find(function (r) return r.usr == "c:Repeat.h@T@FXCount" end)[1].type == "int", "a typedef row keeps its underlying type")
expect(find(function (r) return r.usr == "c:Fixture.h@T@FXOpaque" end)[1].type == "struct FXOpaque",
    "an opaque typedef keeps the struct it names")
local widget_named = find(function (r) return r.usr == "c:objc(cs)FXWidget(cm)widgetNamed:" end)[1]
expect(widget_named.type == "instancetype", "a method keeps its return type")
expect(find(function (r) return r.usr == "c:@F@FXRun" end)[1].params == "int total", "a function keeps its parameter types and names")
count(function (r) return r.usr == "c:@T@fx_float3" end, 1, "fx_float3, a typedef of another header, is one row")
expect(find(function (r) return r.usr == "c:@T@fx_float3" end)[1].type == "float __attribute__((ext_vector_type(3)))",
       "a foreign vector typedef keeps its spelled type")
expect(find(function (r) return r.usr == "c:@T@fx_vector3" end)[1].type == "fx_float3", "a foreign typedef keeps the name its chain gives")
expect(find(function (r) return r.usr == "c:@T@fx_family" end)[1].type == "fx_byte"
       and find(function (r) return r.usr == "c:@T@fx_byte" end)[1].type == "unsigned char", "a chain of foreign typedefs ends at its scalar")
expect(find(function (r) return r.usr == "c:@F@FXMove" end)[1].params == "fx_vector3 at | fx_family family", "a function's parameters name the foreign typedefs")
local function type_of_var(usr)
    return find(function (r) return r.usr == usr end)[1].type
end
expect(type_of_var("c:@FXConstName") == "const FXStringRef", "a const variable of a typedef keeps its const")
expect(type_of_var("c:@FXConstPointer") == "const char *const", "a const pointer to const keeps both")
expect(type_of_var("c:@FXPointerConst") == "char *const", "a const pointer keeps its const after the star")
expect(type_of_var("c:@FXPointerToConst") == "const char *", "a pointer to const keeps its const before the star")
expect(type_of_var("c:@FXConstInt") == "const int", "a const integer keeps its const")
expect(type_of_var("c:@FXMacroConst") == "const FXStringRef", "an attribute macro in front of a variable's type is not part of the type")
expect(type_of_var("c:@FXMacroPointer") == "char *const", "an attribute macro does not hide a pointer's const")
expect(type_of_var("c:@FXRefinedName") == "const FXStringRef", "a Swift attribute macro in front of the type is not part of it")
expect(full_of("c:@FXConstName")[10] == "n", "a nullability word stays in the nullability column, not the type")
local function type_of_usr(usr)
    return find(function (r) return r.usr == usr end)[1].type
end
expect(type_of_usr("c:Repeat.h@T@FXStringAlias") == "FXStringRef", "a typedef's underlying type is spelled without its macro")
expect(type_of_usr("c:@F@FXFetch") == "FXStringRef (const char *)", "a function's result and parameters are spelled without their macros")
expect(find(function (r) return r.usr == "c:@F@FXFetch" end)[1].params == "const char * key", "a function's parameter keeps its type and name")
expect(type_of_usr("c:objc(cs)FXMacroBox(py)macroProperty") == "const FXStringRef", "a property's type is spelled without its macro, const kept")
expect(type_of_usr("c:objc(cs)FXMacroBox(im)macroReturn") == "FXStringRef", "a method's result is spelled without its macro")
local take = find(function (r) return r.usr == "c:objc(cs)FXMacroBox(im)macroTake:" end)[1]
expect(take.params == "const char * value", "a method's parameter is spelled without its macro")
expect(type_of_usr("c:Repeat.h@T@FXBlock") == "id ((^))(int)", "a block typedef is spelled with its block marker, without macros or nullability")
expect(full_of("c:objc(cs)FXWidget(cm)widgetNamed:")[10] == "-|l",
    "a method's nullability is the result, then the parameters (full IR)")
expect(full_of("c:@E@FXState@FXStateOn")[14] == "1", "an enum constant keeps its value (full IR)")
expect(find(function (r) return r.usr == "c:@FXScale" end)[1].type == "const double", "a qualifier is part of the type")
local enabled_row = find(function (r) return r.usr == "c:objc(cs)FXWidget(py)enabled" end)[1]
expect(enabled_row.attrs == "readonly,nonatomic,getter=isEnabledNow" and enabled_row.type == "_Bool",
    "a property keeps its attributes and its type")
count(function (r) return r.type == "" end, 0, "every row fills its type cell")
count(function (r) return r.usr == "c:@E@FXState" end, 1, "FXState is one enum (definition only)")
count(function (r) return r.usr == "c:@S@FXOpaque" end, 1, "FXOpaque is one struct")

count(function (r) return r.usr == "c:@F@FXPrivateOnly" or r.usr == "c:@F@FXTextualOnly" end, 0,
    "private and textual headers are not emitted")
count(function (r) return r.usr:find("FXOnlyIntel", 1, true) ~= nil end, 0, "the x86_64 branch is not emitted")
count(function (r) return r.usr == "c:@F@FXSubtract" end, 1, "a submodule header is emitted")

local init = find(function (r) return r.usr == "c:objc(cs)FXWidget(im)init" end)
expect(#init == 1 and init[1].avail == "*unavailable" and decl_of("c:objc(cs)FXWidget(im)init") == "FX_NO_INIT",
    "the macro-produced init is as spelled")
local widget = find(function (r) return r.usr == "c:objc(cs)FXWidget(cm)widgetNamed:" end)
expect(widget[1].avail == "ios=16.0/-/-/0", "the availability version is read (" .. widget[1].avail .. ")")
expect(widget[1].side == "+" and widget[1].name == "widgetNamed:", "a class method's side and selector are read back")
local enabled = find(function (r) return r.usr == "c:objc(cs)FXWidget(py)enabled" end)
expect(decl_of("c:objc(cs)FXWidget(py)enabled"):find("getter=isEnabledNow", 1, true) ~= nil, "the property declaration keeps its getter")

count(function (r) return r.usr == "c:objc(cs)FXWidget(im)isEnabledNow" end, 0, "a synthesised getter is not in the shards")
local accessor = false
for line in io.lines(FULL) do
    if line:find("\taccessor\tc:objc%(cs%)FXWidget%(im%)isEnabledNow\t") then accessor = true end
end
expect(accessor, "a synthesised getter is an accessor row of the full IR")

local old_fn = find(function (r) return r.usr == "c:@F@FXOld" end)
expect(#old_fn == 1 and old_fn[1].message == "deprecated: Use newWay", "the deprecation message of an availability attribute")
local gone = find(function (r) return r.usr == "c:@F@FXGone" end)
expect(#gone == 1 and gone[1].message == "unavailable: removed in 2.0", "the unavailability message of an unavailable attribute")

local old = find(function (r) return r.usr == "c:objc(cs)FXLegacy(im)old" end)
expect(#old == 1 and old[1].avail == "ios=16.0/-/-/0", "a later extension availability overrides the class's")
local tweak = find(function (r) return r.usr == "c:objc(cs)FXLegacy(im)tweak" end)
expect(#tweak == 1 and tweak[1].avail == "ios=14.0/-/-/0", "an earlier extension availability is ignored")
count(function (r) return r.usr == "c:@F@FXVersioned" end, 1, "a merged C function is one row")
expect(find(function (r) return r.usr == "c:@F@FXVersioned" end)[1].avail == "ios=17.0/-/-/0",
    "the merged availability of the C function is the annotated declaration's")

count(function (r) return r.usr == "c:objc(ext)FXWidget" and r.kind == "category" and r.name == "-" end, 1,
    "the class extension is keyed by its class name and has no name")
count(function (r) return r.kind == "conforms" and r.container == "FXWidget" and r.name == "FXSource" end, 1,
    "the class extension's protocol belongs to the class")
local extras = find(function (r) return r.usr == "c:objc(cs)FXWidget(im)extraAction" end)
expect(extras[1].container == "Extras", "a named category's member carries the category as its container")
expect(widget[1].container == "-", "a class member has no container")

count(function (r) return r.name == "FXLater" end, 0, "a forward-declared protocol is not emitted")

count(function (r) return r.framework == "Fixture/Inner" and r.usr == "c:objc(cs)FXInner" end, 1,
    "the nested framework is labelled Fixture/Inner")

local conflicts = 0
for line in io.lines(path.join(ROOT, "conflicts.tsv")) do
    if not line:find("^framework\t") then conflicts = conflicts + 1 end
end
expect(conflicts == 3, "three conflicts are listed (found " .. conflicts .. ")")
local reasons, classes = {}, {}
for line in io.lines(path.join(ROOT, "unparsed.tsv")) do
    if not line:find("^#") then
        local name, class, reason = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
        reasons[name], classes[name] = reason, class
        expect(not reason:find("/Users/", 1, true) and not reason:find(".sdk", 1, true), "an unparsed evidence carries no host path")
    end
end
expect(classes.Broken == "unparsed" and reasons.Broken:find("Missing.h", 1, true) ~= nil,
    "the broken header is unparsed, and its evidence names the missing header")
expect(classes.NoHeader == "no declarations" and reasons.NoHeader:find("^no public header in Headers/ and no module map header") ~= nil,
    "a framework with no header has no declarations, and its evidence says why")
expect(classes.Swiftonly == "parsed (Swift interface)" and reasons.Swiftonly:find("^no Objective%-C or C header; Swift interface only") ~= nil,
    "a Swift-only framework is parsed from its Swift interface, and its evidence says why")

local header = io.lines(path.join(SPEC, "Fixture", "declarations.tsv"))()
expect(header:find("^#libclang=") ~= nil and header:find("sdk=sdk", 1, true) ~= nil, "the shard header records libclang and the SDK")

local facts = import("facts", {rootdir = FOUND, anonymous = true})
local members = facts.members(SPEC, "Fixture")
local byapi = {}
for _, m in ipairs(members) do byapi[m.api] = m end
expect(byapi["+[FXWidget widgetNamed:]"] ~= nil and byapi["+[FXWidget widgetNamed:]"].avail == "ios=16.0/-/-/0",
    "a class method's spec key and availability")
expect(byapi["-[FXWidget enabled]"] ~= nil and byapi["-[FXWidget enabled]"].alias == "FXWidget.enabled",
    "a property's spec key and alias")
expect(byapi["-[FXWidget extraAction]"] ~= nil and byapi["-[FXWidget extraAction]"].key == "Extras",
    "a category member keeps its category as key, under its class")
expect(byapi["-[FXLegacy old]"] ~= nil and byapi["-[FXLegacy old]"].avail == "ios=16.0/-/-/0", "the resolved availability is the fact")
expect(byapi["+[FXWidget widgetNamed:]"].text == "API_AVAILABLE(ios(16.0))", "a member's availability text is rendered from its fields")
expect(byapi["-[FXWidget isEnabledNow]"] == nil and byapi["+[FXWidget label]"] == nil and byapi["-[FXWidget setLabel:]"] == nil,
    "the accessors synthesised from a property are not members: the property is")
local conforms = facts.conformances(SPEC, "Fixture")
expect(#conforms == 1 and conforms[1].cls == "FXWidget" and conforms[1].protocol == "FXSource", "the conformance fact")
local typedef_fact = nil
for _, t in ipairs(facts.typedefs(SPEC, "Fixture")) do
    if t.name == "FXCount" then typedef_fact = t end
end
expect(typedef_fact ~= nil and typedef_fact.type == "int", "the typedef fact carries the underlying type")

local avail = import("avail", {rootdir = FOUND, anonymous = true})
local function eq(actual, expected, message)
    expect(actual == expected, message .. " (got [" .. tostring(actual) .. "], want [" .. expected .. "])")
end
local function row(a, m) return {avail = a, message = m or ""} end

eq(avail.merge({row("ios=2.0/12.0/-/0,tvos=9.0/12.0/-/0"), row("tvos=9.0/12.0/-/0"), row("ios=3.0/12.0/-/0,tvos=9.0/12.0/-/0")}).avail,
    "ios=2.0/12.0/-/0,tvos=9.0/12.0/-/0", "introduced is the earliest, deprecated is kept when every declaration deprecates")
eq(avail.merge({row("ios=-/-/-/1,macos=13.3/-/-/0,tvos=-/-/-/1,watchos=-/-/-/1"),
    row("ios=17.4/-/-/0,maccatalyst=16.6/-/-/0,macos=13.5/-/-/0,tvos=-/-/-/1,watchos=-/-/-/1")}).avail,
    "ios=17.4/-/-/0,maccatalyst=16.6/-/-/0,macos=13.3/-/-/0,tvos=-/-/-/1,watchos=-/-/-/1",
    "an unavailable declaration does not introduce; the earliest available introduction wins")
eq(avail.merge({row("ios=2.0/-/-/0,watchos=-/-/-/1"), row("ios=17.0/-/-/0,tvos=17.0/-/-/0,watchos=-/-/-/1")}).avail,
    "ios=2.0/-/-/0,tvos=17.0/-/-/0,watchos=-/-/-/1", "a platform named by one declaration takes that declaration's introduction")
eq(avail.merge({row("ios=2.0/9.0/-/0"), row("ios=3.0/-/-/0")}).avail, "ios=2.0/-/-/0", "one declaration not deprecating: not deprecated")
eq(avail.merge({row("ios=2.0/9.0/-/0"), row("ios=3.0/12.0/-/0")}).avail, "ios=2.0/12.0/-/0", "every declaration deprecating: the latest deprecation")
eq(avail.merge({row("ios=2.0/-/9.0/0"), row("ios=2.0/-/11.0/0")}).avail, "ios=2.0/-/11.0/0", "obsoleted: the latest, when every declaration obsoletes")
eq(avail.merge({row("ios=-/-/-/1"), row("ios=5.0/-/-/0")}).avail, "ios=5.0/-/-/0", "available if any declaration is available")
eq(avail.merge({row("ios=-/-/-/1"), row("ios=-/-/-/1")}).avail, "ios=-/-/-/1", "unavailable when every declaration is")
eq(avail.merge({row("-"), row("ios=4.0/12.0/-/0,tvos=9.0/12.0/-/0")}).avail, "ios=4.0/12.0/-/0,tvos=9.0/12.0/-/0",
    "an unannotated declaration is ignored: the annotated OpenGLES entry decides")
eq(avail.merge({row("-"), row("ios=18.0/-/-/0")}).avail, "ios=18.0/-/-/0",
    "an unannotated declaration is ignored: the annotated PDFKit typedef decides")
eq(avail.merge({row("-"), row("-")}).avail, "-", "when no declaration is annotated the key has no availability")
eq(avail.merge({row("*unavailable"), row("-")}).avail, "*unavailable", "an unannotated row does not clear the unavailable flag")
eq(avail.merge({row("*deprecated"), row("-")}).avail, "*deprecated", "an unannotated row does not clear the deprecated flag")
eq(avail.merge({row("*unavailable"), row("ios=5.0/-/-/0")}).avail, "ios=5.0/-/-/0",
    "a row that names a platform without the flag still clears the flag for it")
eq(avail.merge({row("-"), row("ios=4.0/12.0/-/0", "deprecated: Gone"), row("-", "deprecated: Other")}).message,
    "deprecated: Gone", "an unannotated declaration's message is not the key's message")
eq(avail.merge({row("ios=2.0/9.0/-/0", "deprecated: A"), row("ios=2.0/12.0/-/0", "deprecated: B")}).message, "deprecated: B",
    "the message of the declaration that gives the latest deprecation")

eq(avail.render("ios=16.0/-/-/0,macos=13.0/-/-/0", ""), "API_AVAILABLE(ios(16.0), macos(13.0))", "available platforms")
eq(avail.render("ios=2.0/9.0/-/0", "deprecated: Use Y"), 'API_DEPRECATED("Use Y", ios(2.0, 9.0))', "a deprecation with its message")
eq(avail.render("ios=-/-/-/1", ""), "API_UNAVAILABLE(ios)", "an unavailable platform")
eq(avail.render("ios=2.0/-/9.0/0", ""), "API_OBSOLETED(ios(2.0, 9.0))", "an obsoleted platform")
eq(avail.render("ios=2.0/-/-/0,macos=10.0/12.0/-/0,tvos=-/-/-/1", "deprecated: M"),
    'API_AVAILABLE(ios(2.0)) API_DEPRECATED("M", macos(10.0, 12.0)) API_UNAVAILABLE(tvos)', "the four macros in order")
eq(avail.render("-", ""), "", "an unannotated declaration renders nothing")
eq(avail.render("*deprecated", "deprecated: Gone"), 'API_DEPRECATED("Gone")', "a deprecation of every platform, without platforms")
eq(avail.render("*unavailable", ""), "API_UNAVAILABLE", "an unavailability of every platform, without platforms")
eq(avail.render("*unavailable ios=-/-/-/1", ""), "API_UNAVAILABLE(ios)", "a flagged unavailability that names its platforms renders them")

local dep, unav = avail.split_message("deprecated: Use A | B instead")
expect(dep == "Use A | B instead" and unav == nil, "a deprecation text that contains the separator stays whole")
dep, unav = avail.split_message("deprecated: X | unavailable: Y")
expect(dep == "X" and unav == "Y", "a deprecation and an unavailability text, in that order")
dep, unav = avail.split_message("unavailable: removed in 2.0")
expect(dep == nil and unav == "removed in 2.0", "an unavailability text alone")

local docs = os.iorunv("xmake", {"l", IR}, {envs = {IR_SDK = path.join(ROOT, "fixture", "sdk"), IR_MODE = "docs"}})
local doc_lines = {}
for line in docs:gmatch("[^\n]+") do
    if line:find("\t", 1, true) then table.insert(doc_lines, line) end
end
local function doc_cells(line)
    local c = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
    return c
end
for _, line in ipairs(doc_lines) do
    expect(#doc_cells(line) == 10, "every doc row has 10 cells: " .. line)
end
local function doc_of(usr)
    for _, line in ipairs(doc_lines) do
        local c = doc_cells(line)
        if c[3] == usr then return c end
    end
    return nil
end
local run_doc = doc_of("c:@F@FXRun")
expect(run_doc ~= nil and run_doc[8] == "Runs the total. The total is added to the sum.", "a doc row carries the brief as clang parses it")
expect(run_doc ~= nil and run_doc[9]:find("\\n", 1, true) ~= nil, "the raw doc comment is one cell, its line breaks escaped")
expect(run_doc ~= nil and run_doc[7] == "total" and run_doc[10] == "void FXRun(int total)",
    "a doc row carries the parameter names and the declaration as written")
local widget_doc = doc_of("c:objc(cs)FXWidget(cm)widgetNamed:")
expect(widget_doc ~= nil and widget_doc[7] == "name" and widget_doc[8] == "", "a method with no doc comment has an empty brief")
expect(doc_of("c:@FXPointerToConst") ~= nil and doc_of("c:@FXPointerToConst")[9] == "", "a declaration with no comment has an empty raw text")
local double_doc = doc_of("c:@F@FXDouble")
expect(double_doc ~= nil and double_doc[8] == "Doubles a value." and double_doc[9] == "/// Doubles a value.",
    "a /// doc comment is kept, with its brief")
local count_doc = doc_of("c:Repeat.h@T@FXCount")
expect(count_doc ~= nil and count_doc[8] == "Counts the items." and count_doc[9] == "//! Counts the items.",
    "a //! doc comment is kept, and an ordinary // comment above it is not")
local halve_doc = doc_of("c:@F@FXHalve")
expect(halve_doc ~= nil and halve_doc[8] == "Halves a value." and halve_doc[9] == "/*! Halves a value. */",
    "a /*! doc comment is kept, with its brief")

local usr_shard = {}
for line in io.lines(path.join(SPEC, "FixtureC", "declarations.tsv")) do
    if not line:find("^#") then table.insert(usr_shard, line) end
end
local function shard_has(name)
    for _, line in ipairs(usr_shard) do
        if doc_cells(line)[2] == name then return true end
    end
    return false
end
expect(shard_has("c:@F@fc_add") and shard_has("c:@T@fc_count"), "a usr/include module's shard holds the declarations of its own directory")
expect(not shard_has("c:@F@fc_other") and not shard_has("c:@F@fc_extra"),
    "a declaration of another directory, or of another module in the same map, is not in the module's shard")
local usr_doc = false
for _, line in ipairs(doc_lines) do
    if line:find("^FixtureC\t") then usr_doc = true end
end
expect(usr_doc, "the doc mode covers the usr/include module")

local fixture_env = {IR_SDK = path.join(ROOT, "fixture", "sdk")}
local names = {}
for line in os.iorunv(DECLS, {"--list"}, {envs = fixture_env}):gmatch("[^\n]+") do
    table.insert(names, line:match("^([^\t]+)"))
end
expect(table.concat(names, " ") == "Broken Fixture Fixture/Inner FixtureC FixtureCExtra FixtureDotted FixtureFallback FixtureRoot FixtureSub FixtureUmbrella FixtureUmbrella/FixtureNested NoHeader Plain Swiftonly", "decls --list names the sweep's frameworks")
local nested_frameworks = path.join(ROOT, "fixture", "sdk", "System", "Library", "Frameworks", "Fixture.framework", "Frameworks")
os.iorunv("chmod", {"000", nested_frameworks})
local unreadable_failure = nil
try {
    function () os.iorunv(DECLS, {"--list"}, {envs = fixture_env}) end,
    catch {
        function (errors) unreadable_failure = tostring(errors) end
    }
}
os.iorunv("chmod", {"755", nested_frameworks})
expect(unreadable_failure ~= nil and unreadable_failure:find("Frameworks", 1, true) ~= nil,
    "an unreadable framework folder is an error that names its path")
expect(os.iorunv(DECLS, {"--target"}, {envs = fixture_env}) == "arm64-apple-ios26.4\n", "decls --target is derived from the SDK's version")
local identity = os.iorunv(DECLS, {"--version"})
local dylib_sha = identity:match("dylib%-sha256=(%x+)")
expect(dylib_sha ~= nil and #dylib_sha == 64, "decls --version names the SHA-256 of the libclang it runs (got " .. identity:gsub("\n", " ") .. ")")
local function rows_of(text, name)
    local out = {}
    for line in text:gmatch("[^\n]+") do
        if line:sub(1, #name + 1) == name .. "\t" then table.insert(out, line) end
    end
    return table.concat(out, "\n")
end
local direct = os.iorunv(DECLS, {"--doc", "Fixture"}, {envs = fixture_env})
expect(direct ~= "" and rows_of(direct, "Fixture") == rows_of(docs, "Fixture"),
    "decls --doc Fixture gives the rows the doc pass gives for Fixture")

local SCRATCH = path.join(REPO, "build", "found", "test-frameworks")
local fixture_library = path.join(ROOT, "fixture", "sdk", "System", "Library")
local function frameworks_copy(name)
    local root = path.join(SCRATCH, name)
    os.tryrm(root)
    os.mkdir(root)
    os.cp(path.join(fixture_library, "Frameworks"), path.join(root, "Frameworks"))
    os.cp(path.join(fixture_library, "SubFrameworks"), path.join(root, "SubFrameworks"))
    return root
end
local function env_with(root)
    return {IR_SDK = fixture_env.IR_SDK, IR_CONFIG = FIXTURE_CONFIG, IR_FRAMEWORKS = root}
end
local copy = frameworks_copy("copy")
local copy_list = os.iorunv(DECLS, {"--list"}, {envs = env_with(copy)})
local copy_names = {}
for line in copy_list:gmatch("[^\n]+") do
    table.insert(copy_names, line:match("^([^\t]+)"))
end
expect(table.concat(copy_names, " ") == table.concat(names, " ") and copy_list:find(copy, 1, true) ~= nil,
    "decls --list under IR_FRAMEWORKS names the same frameworks, rooted in that root")
expect(os.iorunv(DECLS, {"--doc", "Fixture"}, {envs = env_with(copy)}) == direct,
    "decls --doc Fixture under IR_FRAMEWORKS gives the rows it gives under the SDK")
local dropped = frameworks_copy("dropped")
os.rm(path.join(dropped, "Frameworks", "Fixture.framework", "Headers", "Sub.h"))
local dropped_result = nil
try {
    function () dropped_result = os.iorunv(DECLS, {"--doc", "Fixture"}, {envs = env_with(dropped)}) end,
    catch {
        function (errors) dropped_result = "error" end
    }
}
expect(dropped_result ~= direct, "a root without Fixture's Sub.h does not give the SDK's rows (mutant)")
local bare = path.join(SCRATCH, "bare")
os.tryrm(bare)
os.mkdir(bare)
local bare_failure = nil
try {
    function () os.iorunv(DECLS, {"--list"}, {envs = env_with(bare)}) end,
    catch {
        function (errors) bare_failure = tostring(errors) end
    }
}
expect(bare_failure ~= nil and bare_failure:find("IR_FRAMEWORKS", 1, true) ~= nil,
    "a root with no Frameworks folder is an error that names IR_FRAMEWORKS")

local many_avail = find(function (r) return r.usr == "c:@F@FXManyPlatforms" end)[1].avail
local many_count = 0
for _ in string.gmatch(many_avail, "[^,]+") do many_count = many_count + 1 end
expect(many_count == 14, "every platform record clang reports is kept (got " .. many_count .. ")")

local function shasum16(text)
    local out = os.iorunv("/bin/sh", {"-c", "printf '%s' \"$1\" | shasum -a 256 | cut -c1-16", "sh", text})
    return (out:gsub("%s+$", ""))
end
local hash_checked, hash_mismatch = 0, {}
for line in io.lines(FULL) do
    local c = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
    if c[2] ~= "census" and c[2] ~= "unparsed" and c[2] ~= "conflict" and c[2] ~= "meta" and c[15] and c[15] ~= "" then
        local canonical = {}
        for _, i in ipairs({2, 3, 4, 5, 6, 11, 12, 10, 13, 14}) do table.insert(canonical, c[i] .. "\31") end
        hash_checked = hash_checked + 1
        local expected = shasum16(table.concat(canonical))
        if expected ~= c[15] then table.insert(hash_mismatch, c[2] .. " " .. c[3] .. " " .. c[15] .. " != " .. expected) end
    end
end
expect(hash_checked > 0 and #hash_mismatch == 0,
    string.format("every declaration hash is the SHA-256 of its canonical cells (%d checked, %d differ: %s)",
        hash_checked, #hash_mismatch, table.concat(hash_mismatch, "; ", 1, math.min(3, #hash_mismatch))))

local FACTS = path.join(REPO, "build", "found", "facts-sdk")
local FACTS_CONFIG = path.join(REPO, "build", "found", "facts-config")
local function write_file(file, text)
    os.mkdir(path.directory(file))
    local handle = assert(io.open(file, "wb"))
    handle:write(text)
    handle:close()
end
local function facts_run(bound)
    os.tryrm(FACTS)
    local framework = path.join(FACTS, "System", "Library", "Frameworks", "Facts.framework")
    write_file(path.join(framework, "Headers", "Facts.h"), [[
#pragma clang system_header
__attribute__((objc_root_class))
@interface FactsBase
- (void)noop;
@end

@interface FactsBox<Element : ]] .. bound .. [[, Other> : FactsBase
- (void)take:(Element)item;
@end

@interface FactsBox<Element : ]] .. bound .. [[, Other> (Extra)
- (void)extra:(Element)item;
@end

@protocol FactsListing
- (void)list;
@end

@interface FactsBase (FactsListing) <FactsListing>
@end

typedef struct FactsHolder {
  union {
    struct { int x; int y; } point;
    float fx;
  } value;
} FactsHolder;
]])
    write_file(path.join(framework, "Modules", "module.modulemap"), "framework module Facts {\n  umbrella header \"Facts.h\"\n  export *\n}\n")
    write_file(path.join(FACTS, "SDKSettings.json"), io.readfile(path.join(ROOT, "fixture", "sdk", "SDKSettings.json")))
    write_file(path.join(FACTS_CONFIG, "usr-modules.tsv"), "# no usr/include modules in this scratch SDK\n")
    write_file(path.join(FACTS_CONFIG, "fallback.tsv"), "# no framework without a module map in this scratch SDK\n")
    local rows = {}
    for line in os.iorunv(DECLS, {"Facts"}, {envs = {IR_SDK = FACTS, IR_CONFIG = FACTS_CONFIG}}):gmatch("[^\n]+") do
        local c = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
        table.insert(rows, c)
    end
    return rows
end
local function row_of(rows, kind, name)
    for _, c in ipairs(rows) do
        if c[2] == kind and c[5] == name then return c end
    end
    error("no " .. kind .. " row named " .. name)
end
local facts = facts_run("FactsBase *")
expect(row_of(facts, "interface", "FactsBox")[19] == "Element:FactsBase * | Other:id",
    "a generic class's typeparams are name:bound in order (got " .. row_of(facts, "interface", "FactsBox")[19] .. ")")
expect(row_of(facts, "interface", "FactsBase")[19] == "-", "a class with no type parameters has typeparams -")
expect(row_of(facts, "category", "Extra")[19] == "Element:FactsBase * | Other:id",
    "a category of a generic class has its own typeparams, in order (got " .. row_of(facts, "category", "Extra")[19] .. ")")
local holder_value = row_of(facts, "field", "value")
local union = row_of(facts, "union", "-")
expect(holder_value[20] == union[3] and union[3] ~= "-", "a field of an anonymous union names the union's USR in anon")
expect(row_of(facts, "field", "x")[20] == "-" and row_of(facts, "field", "point")[20] ~= "-",
    "a named field's anon is - and a field of an anonymous struct names its struct")
expect(row_of(facts, "conforms", "FactsListing")[21] == "FactsListing" and row_of(facts, "conforms", "FactsListing")[4] == "FactsBase",
    "a conforms row in a category carries the category, and its container is the class")
local mutant = facts_run("id")
expect(row_of(mutant, "interface", "FactsBox")[19] == "Element:id | Other:id" and
    row_of(mutant, "interface", "FactsBox")[19] ~= row_of(facts, "interface", "FactsBox")[19],
    "the mutant's bound id changes typeparams, so the cell is read from the source")
os.tryrm(FACTS)
os.tryrm(FACTS_CONFIG)

print(string.format("extractor tests passed: %d checks", checks))

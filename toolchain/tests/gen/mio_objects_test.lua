local REPO = path.directory(path.directory(path.absolute(os.scriptdir())))
local TOOLS = path.join(REPO, "tools")
local mio = import("gen.mio_objects", {rootdir = TOOLS, anonymous = true})
local FIXTURE = path.join(os.scriptdir(), "mio_objects_fixture")
local checks, failures = 0, 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL: " .. message)
    end
end

local function has_line(text, line)
    for each in string.gmatch(text, "[^\n]+") do
        if each == line then
            return true
        end
    end
    return false
end

local result = mio.plan(FIXTURE, "ModelIO", "9.0")
local files = result.files

expect(result.methods == 11, "methods read: want 11, got " .. result.methods)
expect(#result.dropped == 2, "dropped by a rule: want 2, got " .. #result.dropped)
expect(result.kept == 9, "kept: want 9, got " .. result.kept)
expect(#result.tree_dropped == 4, "dropped because the tree defines them: want 4, got " .. #result.tree_dropped)

local rule_of = {}
for _, drop in ipairs(result.dropped) do
    rule_of[drop.api] = drop.rule
end
expect(rule_of["-[MDLAsset .cxx_destruct]"] == "cxx destructor", "cxx destructor is dropped by its rule")
expect(rule_of["-[MDLNew allocator]"] == "allocator", "allocator is dropped by its rule")

local tree_of = {}
for _, drop in ipairs(result.tree_dropped) do
    tree_of[drop.cls .. " " .. drop.selector] = drop.file
end
expect(tree_of["MDLAsset -setName:other:"] == "MDLAsset9.m", "-setName:other: is defined by MDLAsset9.m")
expect(tree_of["MDLAsset -tracked"] == "MDLAsset9.m", "-tracked is defined by the category in MDLAsset9.m")
expect(tree_of["MDLMesh -generatorThing:"] == "MDLMeshGenerators9.m", "-generatorThing: is defined by the category in MDLMeshGenerators9.m")
expect(tree_of["MDLAsset -setName:"] == nil, "-setName: (same first keyword, different selector) is not dropped")
expect(tree_of["MDLAliased -aliasedThing:"] == "MDLAliased10.m", "-aliasedThing: is defined by the alias category in MDLAliased10.m")
expect(tree_of["MDLAliased -aliasedOther"] == nil, "-aliasedOther is not defined by the folder, so it is kept")

expect(files["MDIO90.m"] ~= nil, "band 9.0 writes MDIO90.m")
expect(files["MDIO100.m"] ~= nil, "band 10.0 writes MDIO100.m")
expect(files["MDIO90.m"] ~= nil and not has_line(files["MDIO90.m"], "@implementation MDLAsset"),
    "MDLAsset, defined in MDLAsset9.m with a category in that file, is not declared again")
expect(files["MDIO90.m"] ~= nil and has_line(files["MDIO90.m"], "@implementation MDLAsset (Revenant90)"),
    "the kept MDLAsset member goes in a category")
expect(files["MDIO90.m"] ~= nil and string.find(files["MDIO90.m"], "+ (id)canExportFileExtension:(id)a0", 1, true) ~= nil,
    "the first row (+canExportFileExtension:) is carried: it was skipped as a header before")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLNew"),
    "MDLNew, which the folder does not define, is declared")
expect(files["MDIO100.m"] ~= nil and not has_line(files["MDIO100.m"], "@implementation MDLMesh"),
    "MDLMesh, defined in MDLMesh9.m with a category elsewhere, is not declared again")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLMesh (Revenant100)"),
    "the kept MDLMesh member goes in a category")
expect(files["MDIO100.m"] ~= nil and string.find(files["MDIO100.m"], '#import "RevenantModelIO.h"', 1, true) ~= nil,
    "MDLNew has no header in the map, so the package's own header is imported")
expect(files["MDIO100.m"] ~= nil and not has_line(files["MDIO100.m"], "@implementation MDLAliased"),
    "MDLAliased, defined through REVENANT_ALIAS in the folder, is not declared again")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLAliased (Revenant100)"),
    "the kept MDLAliased member goes in a category")

if failures > 0 then
    print(string.format("mio_objects: %d of %d checks FAILED", failures, checks))
    os.exit(1)
end
print(string.format("mio_objects: OK (%d checks)", checks))

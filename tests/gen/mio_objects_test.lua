-- The ModelIO objects (tools/gen/mio_objects.lua) on a fixture tree whose answers are worked out by hand from the rules, not read from
-- the code under test. The fixture (mio_objects_fixture) holds eleven method rows and one class row per band, and hand-written sources
-- that define some of them. Checks what each rule drops, what each tree-defined member is dropped for, which band each class lands in,
-- and that a category in one file does not take its class back from the file that defines it.
--
-- Run, from any folder: xmake l tests/gen/mio_objects_test.lua
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

-- Whether a text holds this exact line.
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

-- The counts: eleven method rows (the init row has no band and is not read), two dropped by a rule, nine kept, four of them defined by
-- the hand-written sources.
expect(result.methods == 11, "methods read: want 11, got " .. result.methods)
expect(#result.dropped == 2, "dropped by a rule: want 2, got " .. #result.dropped)
expect(result.kept == 9, "kept: want 9, got " .. result.kept)
expect(#result.tree_dropped == 4, "dropped because the tree defines them: want 4, got " .. #result.tree_dropped)

-- Which rule drops which row: the cxx destructor and the allocator.
local rule_of = {}
for _, drop in ipairs(result.dropped) do
    rule_of[drop.api] = drop.rule
end
expect(rule_of["-[MDLAsset .cxx_destruct]"] == "cxx destructor", "cxx destructor is dropped by its rule")
expect(rule_of["-[MDLNew allocator]"] == "allocator", "allocator is dropped by its rule")

-- Each tree-defined member, with the class, the whole selector, and the file that defines it. -setName:other: and -setName: share a first
-- keyword: only the whole selector tells them apart, so -setName: is kept.
local tree_of = {}
for _, drop in ipairs(result.tree_dropped) do
    tree_of[drop.cls .. " " .. drop.selector] = drop.file
end
expect(tree_of["MDLAsset -setName:other:"] == "MDLAsset9.m", "-setName:other: is defined by MDLAsset9.m")
expect(tree_of["MDLAsset -tracked"] == "MDLAsset9.m", "-tracked is defined by the category in MDLAsset9.m")
expect(tree_of["MDLMesh -generatorThing:"] == "MDLMeshGenerators9.m", "-generatorThing: is defined by the category in MDLMeshGenerators9.m")
expect(tree_of["MDLAsset -setName:"] == nil, "-setName: (same first keyword, different selector) is not dropped")
-- MDLAliased is defined through CHARON_ALIAS in MDLAliased10.m, and its category is written with CHARON_ALIAS_CLASS: the class and the
-- member the category implements are the folder's, under the release's name, not under the alias's.
expect(tree_of["MDLAliased -aliasedThing:"] == "MDLAliased10.m", "-aliasedThing: is defined by the alias category in MDLAliased10.m")
expect(tree_of["MDLAliased -aliasedOther"] == nil, "-aliasedOther is not defined by the folder, so it is kept")

-- The objects. Band 9.0 holds a category of MDLAsset (the class is defined in the folder, so it is not declared again); band 10.0 holds
-- MDLNew (the folder does not define it, so it is declared) and a category of MDLMesh (the folder defines the class in another file).
expect(files["MDIO90.m"] ~= nil, "band 9.0 writes MDIO90.m")
expect(files["MDIO100.m"] ~= nil, "band 10.0 writes MDIO100.m")
expect(files["MDIO90.m"] ~= nil and not has_line(files["MDIO90.m"], "@implementation MDLAsset"),
    "MDLAsset, defined in MDLAsset9.m with a category in that file, is not declared again")
expect(files["MDIO90.m"] ~= nil and has_line(files["MDIO90.m"], "@implementation MDLAsset (Charon90)"),
    "the kept MDLAsset member goes in a category")
expect(files["MDIO90.m"] ~= nil and string.find(files["MDIO90.m"], "+ (id)canExportFileExtension:(id)a0", 1, true) ~= nil,
    "the first row (+canExportFileExtension:) is carried: it was skipped as a header before")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLNew"),
    "MDLNew, which the folder does not define, is declared")
expect(files["MDIO100.m"] ~= nil and not has_line(files["MDIO100.m"], "@implementation MDLMesh"),
    "MDLMesh, defined in MDLMesh9.m with a category elsewhere, is not declared again")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLMesh (Charon100)"),
    "the kept MDLMesh member goes in a category")
expect(files["MDIO100.m"] ~= nil and string.find(files["MDIO100.m"], '#import "CharonModelIO.h"', 1, true) ~= nil,
    "MDLNew has no header in the map, so the package's own header is imported")
expect(files["MDIO100.m"] ~= nil and not has_line(files["MDIO100.m"], "@implementation MDLAliased"),
    "MDLAliased, defined through CHARON_ALIAS in the folder, is not declared again")
expect(files["MDIO100.m"] ~= nil and has_line(files["MDIO100.m"], "@implementation MDLAliased (Charon100)"),
    "the kept MDLAliased member goes in a category")

if failures > 0 then
    print(string.format("mio_objects: %d of %d checks FAILED", failures, checks))
    os.exit(1)
end
print(string.format("mio_objects: OK (%d checks)", checks))

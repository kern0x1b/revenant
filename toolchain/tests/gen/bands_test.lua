local REPO = path.directory(path.directory(path.absolute(os.scriptdir())))
local TOOLS = path.join(REPO, "tools")
local bands = import("gen.bands", {rootdir = TOOLS, anonymous = true})
local checks = 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then raise("test failed: " .. message) end
end

local function has(text, needle)
    return string.find(text, needle, 1, true) ~= nil
end

local objects = bands.objects(REPO, "FileProvider")
local names = {}
for name in pairs(objects) do
    table.insert(names, name)
end
table.sort(names)

expect(#names == 2 and names[1] == "FileProvider11.m" and names[2] == "FileProvider16.m",
    "the spec defines FileProvider11.m and FileProvider16.m, got " .. table.concat(names, ", "))

for _, name in ipairs(names) do
    local text = objects[name]
    expect(has(text, "#import <FileProvider/FileProvider.h>\n"), name .. " imports the framework header")
    expect(has(text, "// packages/frameworks/apple-backports/spec/FileProvider/bands.json. "), name .. " names the spec it is written from")
    expect(string.sub(text, -1) == "\n" and string.sub(text, -2, -2) ~= "\n", name .. " ends with one newline")
end

local eleven = objects["FileProvider11.m"]
expect(has(eleven, "@implementation NSFileProviderDomain {\n"), "the 11.0 object defines NSFileProviderDomain")
expect(has(eleven, "// Corpus rank 7 of the corpus's crash-demand-top.tsv. The spec is"), "the class piece carries rank 7")
expect(has(eleven, "// Corpus rank 8 of the corpus's crash-demand-top.tsv. The spec is"), "the policy piece carries rank 8")
expect(string.find(eleven, "@end\n\n", 1, true) ~= nil and string.find(eleven, "@implementation NSFileProviderManager", 1, true) == nil,
    "the policy piece emits no @implementation of NSFileProviderManager")
expect(has(eleven, "//   never called: +[NSFileProviderManager addDomain:completionHandler:]\n"), "a never_call name is written as carried")

local sixteen = objects["FileProvider16.m"]
expect(has(sixteen, "@implementation NSFileProviderDomain (Revenant16)\n"), "the 16.0 object is a category of NSFileProviderDomain")
expect(not has(sixteen, "@implementation NSFileProviderDomain {"), "the 16.0 object defines no class")
expect(has(sixteen, "- (void)setSupportsSyncingTrash:(BOOL)supportsSyncingTrash {"), "the 16.0 category sets supportsSyncingTrash")

local fixture = path.join(os.scriptdir(), "bands_fixture")
local refusal = nil
try {
    function() bands.objects(fixture, "Fixture") end,
    catch { function(errors) refusal = tostring(errors) end }
}
expect(refusal ~= nil, "a class the package already defines is refused")
expect(has(refusal, "FixtureThing is already defined by Other.m"), "the refusal names the file that defines the class: " .. tostring(refusal))

local clean = bands.objects(fixture, "Clean")
expect(clean["Clean9.m"] ~= nil, "a category of a class in the package is not refused")
expect(has(clean["Clean9.m"], "@implementation FixtureThing\n@end\n"), "the class of the clean spec is written as the spec states it")

print("bands_test: " .. checks .. " checks passed")

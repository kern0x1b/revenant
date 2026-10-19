local REPO = path.directory(path.directory(path.absolute(os.scriptdir())))
local TOOLS = path.join(REPO, "tools")
local measured = import("gen.measured", {rootdir = TOOLS, anonymous = true})
local checks = 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then raise("test failed: " .. message) end
end

local objects = measured.release_objects(REPO, "UIKit")
local names = {}
for name in pairs(objects) do
    table.insert(names, name)
end
table.sort(names)

local EXPECTED = {"UIKitConstants1001.m", "UIKitConstants110.m", "UIKitConstants134.m", "UIKitConstants160.m", "UIKitConstants180.m", "UIKitConstants182.m",
                  "UIKitConstants183.m", "UIKitConstants260.m"}
expect(#names == #EXPECTED, "the table defines " .. #EXPECTED .. " objects, got " .. #names)
local merged = measured.objects(REPO, "UIKit")
local merged_count = 0
for _ in pairs(merged) do
    merged_count = merged_count + 1
end
expect(merged_count == #EXPECTED + 6, "objects() merges the 7 release objects and the 6 constant objects of UIKit, got " .. merged_count)
for i, name in ipairs(EXPECTED) do
    expect(names[i] == name, "object " .. i .. " is " .. name)
    local text = objects[name]
    expect(string.sub(text, -1) == "\n" and string.sub(text, -2, -2) ~= "\n", name .. " ends with one newline")
    expect(string.find(text, "#import <UIKit/UIKit.h>\n", 1, true) ~= nil, name .. " imports UIKit")
    expect(string.find(text, "// Generated:  xmake l tools/gen.lua gen --framework UIKit\n", 1, true) ~= nil, name .. " names its producer")
end

expect(string.find(objects["UIKitConstants160.m"], "= {.top = 0.0, .leading = CGFLOAT_MAX, .bottom = 0.0, .trailing = CGFLOAT_MAX};", 1, true)
    ~= nil, "a struct value is written with its members dotted")

expect(string.find(objects["UIKitConstants180.m"], "#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 180000\n", 1, true) ~= nil,
    "a floor of 18.0 is guarded at 180000")
expect(string.find(objects["UIKitConstants180.m"], "#else\n", 1, true) ~= nil, "a guarded row has its fallback")

expect(string.find(objects["UIKitConstants134.m"], "void UIGuidedAccessConfigureAccessibilityFeatures(", 1, true) ~= nil,
    "the 13.4 object carries UIGuidedAccessConfigureAccessibilityFeatures")

expect(string.find(objects["UIKitConstants182.m"], "const NSAttributedStringKey _Nonnull NSWritingToolsExclusionAttributeName = ", 1, true)
    ~= nil, "the type keeps its nullability and loses no API_ macro")

local seen = {}
for _, name in ipairs(names) do
    local in_fallback = false
    for line in string.gmatch(objects[name], "[^\n]+") do
        if line == "#else" then
            in_fallback = true
        elseif line == "#endif" then
            in_fallback = false
        end
        local api = string.match(line, "^[%w_ %*]+ ([%w_]+) = ")
        if api ~= nil and not in_fallback then
            expect(seen[api] == nil, api .. " is defined by one object only")
            seen[api] = name
        end
    end
end
expect(seen.UICollectionViewLayoutAutomaticDimension == "UIKitConstants1001.m", "the 10.0.1 row is in the 10.0.1 object")

for _, name in ipairs(names) do
    expect(string.find(objects[name], '@\\"', 1, true) == nil, name .. " writes no ObjC literal inside a string")
end
expect(string.find(objects["UIKitConstants260.m"], 'const UIMenuIdentifier UIMenuNewItem = @"com.apple.menu.new-item";', 1, true) ~= nil,
    "UIMenuNewItem is the plain string the host gives it")

print("measured_test: " .. checks .. " checks passed")

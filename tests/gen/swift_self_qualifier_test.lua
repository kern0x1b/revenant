-- The framework's own name as a qualifier (tools/gen/swift_render.lua self_qualified_rows, render): a name the framework does not declare
-- loses its qualifier, since the qualifier names the Swift module being compiled. simd.simd_double2 is a clang type of the simd module,
-- and SwiftUI.View is declared by SwiftUICore, the implementation whose public name is SwiftUI: SwiftUICore is imported for it (2000
-- "no type named 'simd_double2' in module 'simd'" and 10223 "no type named 'View' in module 'SwiftUI'" errors in the whole-SDK run). A name
-- the framework declares keeps its qualifier. Checked on fixtures. Run: xmake l tests/gen/swift_self_qualifier_test.lua (pure Lua)

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

-- A model row with every cell the renderer reads, "-" where the row says nothing.
local function row(fields)
    local out = {kind = "-", usr = "-", container = "-", name = "-", side = "-", type = "-", params = "-", generic_sig = "-",
                 conformances = "-", superclass = "-", throwing = "-", async = "-", mutating = "-", attributes = "-", accessors = "-",
                 storage = "-", is_let = "-", is_open = "-", requirement = "-", in_extension = "-", owner_module = "-", raw = "-",
                 alias = "-", overriding = "-", init_kind = "-", availability = "-", outer_names = "-"}
    for key, value in pairs(fields) do
        out[key] = value
    end
    return out
end

function main()
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    -- simd: the framework's clang type is named by its own module name, and the module declares no such type
    local simd = {row({kind = "swift-function", name = "f(_:)", side = "-", type = "-", params = "simd.simd_double2",
                       usr = "s:simd.f"})}
    local simd_text = render.render(simd, "simd", {simd = true, Swift = true}, nil, nil, nil)
    check(string.find(simd_text, "simd_double2", 1, true) ~= nil and string.find(simd_text, "simd.simd_double2", 1, true) == nil,
          "a self-qualified name the framework does not declare loses its qualifier")

    -- SwiftUI: View is SwiftUICore's, whose public name is SwiftUI; the conformance drops the qualifier and SwiftUICore is imported
    local swiftui = {row({kind = "swift-struct", name = "Text", usr = "s:Text", conformances = "SwiftUI.View"}),
                     row({kind = "swift-struct", name = "Image", usr = "s:Image"})}
    local swiftui_text = render.render(swiftui, "SwiftUI", {SwiftUI = true, SwiftUICore = true, Swift = true}, nil, {SwiftUICore = "SwiftUI"}, nil)
    check(string.find(swiftui_text, "import SwiftUICore", 1, true) ~= nil, "the implementation module of the framework is imported")
    check(string.find(swiftui_text, "SwiftUI.View", 1, true) == nil, "the qualifier of View is dropped")

    -- a name the framework declares keeps its qualifier
    local own = {row({kind = "swift-struct", name = "Outer", usr = "s:Outer"}),
                 row({kind = "swift-struct", container = "Outer", name = "Inner", usr = "s:Outer.Inner"}),
                 row({kind = "swift-property", container = "Outer", name = "x", side = "-", type = "Own.Outer.Inner",
                      accessors = "get", usr = "s:Outer.x"})}
    local own_text = render.render(own, "Own", {Own = true, Swift = true}, nil, nil, nil)
    check(string.find(own_text, "Own.Outer.Inner", 1, true) ~= nil, "a name the framework declares keeps its qualifier")

    -- a generic superclass has commas of its own: the chain's first item is the whole superclass (AppIntents' EqualToComparator)
    local generic = {row({kind = "swift-class", name = "Base", usr = "s:Base"}),
                     row({kind = "swift-class", name = "Eq", usr = "s:Eq", superclass = "Mod.Base<Property, PropertyType>, Mod.Other",
                          conformances = "Copyable"})}
    local generic_text = render.render(generic, "Mod", {Mod = true, Swift = true}, nil, nil, nil)
    check(string.find(generic_text, "Mod.Base<Property, PropertyType>, Swift.Copyable", 1, true) ~= nil,
          "a generic superclass keeps its arguments, then the conformances")

    -- a some inside a generic argument list is not a parameter's own some (only a top-level some X, or () -> some X, is named)
    local nested = {row({kind = "swift-struct", name = "Box", usr = "s:Box"}),
                    row({kind = "swift-method", container = "Box", name = "put(_:)", side = "+", params = "Swift.Array<some Q>",
                         type = "-", usr = "s:Box.put", generic_sig = "<W0 where W0 : Q>"})}
    local nested_text = render.render(nested, "Box", {Box = true, Swift = true}, nil, nil, nil)
    check(string.find(nested_text, "Swift.Array<some Q>", 1, true) ~= nil, "a some inside brackets is left as it is")

    print("swift self qualifier test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

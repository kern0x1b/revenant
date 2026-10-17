-- A class's superclass in the Swift skeleton (tools/gen/swift_render.lua inheritance_of): the model's superclass cell lists the chain above the
-- class, direct superclass first ("UIKit.UIView,UIKit.UIResponder,ObjectiveC.NSObject"), and a skeleton that declares the whole list
-- fails with "multiple inheritance from classes 'UIView' and 'UIResponder'" (502 errors in 37 modules of the coordinator's sdk run). A
-- class has one superclass: the skeleton declares the first name of the cell, then its conformances. Checked here on a class with a
-- three-name chain and one conformance. Run: xmake l tests/gen/swift_superclass_test.lua (pure Lua: no toolchain)

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

    local rows = {
        row({kind = "swift-class", name = "AUView", usr = "c:AUView", superclass = "UIKit.UIView,UIKit.UIResponder,ObjectiveC.NSObject",
             conformances = "Sendable"}),
    }
    local text = render.render(rows, "Fix", {}, nil, nil)
    check(string.find(text, "public class AUView: UIKit.UIView, Swift.Sendable {", 1, true) ~= nil,
          "the class declares its direct superclass and its conformance, nothing above it: " .. text)
    check(string.find(text, "UIResponder", 1, true) == nil, "the superclass chain's other names are not declared")

    print("swift superclass test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

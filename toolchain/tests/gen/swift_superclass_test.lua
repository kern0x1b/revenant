local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

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

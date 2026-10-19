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
        row({kind = "swift-enum", name = "Error", usr = "c:Error", conformances = "Copyable,Equatable,Error,Sendable"}),
        row({kind = "swift-enum", name = "Code", usr = "c:Code", raw = "Int", conformances = "Error,Hashable"}),
        row({kind = "swift-struct", name = "Holder", usr = "s:Holder", conformances = "Hashable,MyProtocol"}),
    }
    local text = render.render(rows, "Fix", {}, nil, nil)

    check(string.find(text, "public enum Error: Swift.Copyable, Swift.Equatable, Swift.Error, Swift.Sendable {", 1, true) ~= nil,
          "the enum named Error spells its standard conformances qualified: " .. text)
    check(string.find(text, "public enum Code: Int, Swift.Error, Swift.Hashable {", 1, true) ~= nil,
          "a raw type stays first, and the standard conformances are qualified")
    check(string.find(text, "public struct Holder: Swift.Hashable, MyProtocol {", 1, true) ~= nil,
          "a protocol of the SDK keeps its name")

    print("swift stdlib names test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

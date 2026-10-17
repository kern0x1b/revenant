-- The standard library's protocols in a skeleton's inheritance clause (tools/gen/swift_render.lua stdlib_qualified): an enum named Error that
-- conforms to Error refers to itself by that name, so the compiler refuses it ("'Error' has a raw type that depends on itself", 14 lines
-- of the coordinator's sdk run; "type alias 'Element' references itself" is the same spelling in a typealias). A standard protocol is
-- spelled Swift.X in the clause; a raw type stays first; a protocol of the SDK keeps its name. Checked here on three types: enum Error with
-- Error among its conformances, an Int-raw enum with Error, and a struct with a protocol that is not the standard library's. Run:
-- xmake l tests/gen/swift_stdlib_names_test.lua (pure Lua: no toolchain)

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

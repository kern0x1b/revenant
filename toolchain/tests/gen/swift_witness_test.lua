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

local function lines_with(text, needle)
    local found = {}
    for line in string.gmatch(text, "[^\n]*") do
        if string.find(line, needle, 1, true) then
            table.insert(found, line)
        end
    end
    return found
end

function main()
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local rows = {
        row({kind = "swift-class", name = "Item", usr = "c:Item", conformances = "NSCopying,NSSecureCoding", superclass = "NSObject"}),
        row({kind = "swift-class", name = "Box", usr = "c:Box", conformances = "NSCopying", superclass = "NSObject"}),
        row({kind = "swift-method", container = "Box", name = "copy(with:)", usr = "c:Box.copy", type = "Any", side = "-"}),
        row({kind = "swift-struct", name = "Holder", usr = "s:Holder", conformances = "Decodable"}),
        row({kind = "swift-class", name = "Base", usr = "c:Base", conformances = "NSCopying", superclass = "NSObject"}),
        row({kind = "swift-class", name = "Sub", usr = "c:Sub", conformances = "NSCopying", superclass = "Base"}),
    }
    local classes = {Base = rows[5], NSObject = row({kind = "swift-class", name = "NSObject", usr = "c:NSObject"})}
    local text, _, witnessed = render.render(rows, "Fix", {Foundation = true}, classes, nil)

    local copies = lines_with(text, "func copy(with zone: NSZone?) -> Any")
    check(#copies == 2, "one copy(with:) for Item and one for Base, not for Box (the model gives it) or Sub (inherited): " .. #copies)
    check(#lines_with(text, "public func copy(with zone: NSZone?) -> Any { fatalError(\"Item.copy(with:)\") }") == 1,
          "Item's copy(with:) is a public member that traps with its name")
    check(#lines_with(text, "public static var supportsSecureCoding: Swift.Bool { fatalError(\"Item.supportsSecureCoding\") }") == 1,
          "Item's supportsSecureCoding is a public static computed property that traps")
    check(#lines_with(text, "class Sub") == 1 and #lines_with(text, "NSCopying") == 3,
          "Sub declares no NSCopying (provided by Base) and no copy: NSCopying appears in Item, Base and Box only")
    check(#lines_with(text, "public init(from decoder: Swift.Decoder) throws") == 1, "Holder's init(from:) is declared")
    check(#lines_with(text, "required init(from") == 0, "a struct's Decodable init is not required")
    check(#lines_with(text, "import Foundation") == 1, "the skeleton imports Foundation, which the witnesses name")

    local sdk_rows = {}
    local ours = {row({kind = "swift-method", container = "Item", name = "copy(with:)", usr = "c:Item.copy", side = "-"}),
                  row({kind = "swift-method", container = "Fix.Other", name = "extra()", usr = "c:Other.extra", side = "-"})}
    local with = roundtrip.compare(sdk_rows, ours, {["Item\tcopy(with:)"] = true})
    check(with.witnessed == 1 and with.extra == 1, "a declared witness is counted as witnessed: witnessed " .. with.witnessed .. ", extra " .. with.extra)
    local without = roundtrip.compare(sdk_rows, ours, nil)
    check(without.witnessed == 0 and without.extra == 2, "with no witnesses the same rows are both extra: extra " .. without.extra)
    check(has_witness_text(witnessed), "the renderer returns its witnesses as a set")

    print("swift witness test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function has_witness_text(witnessed)
    return witnessed["Item\tcopy(with:)"] == true and witnessed["Item\tsupportsSecureCoding"] == true
end

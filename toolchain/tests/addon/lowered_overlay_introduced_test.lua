local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local OVERLAY = table.concat({
    "import Foundation",
    "",
    "extension Gadget {",
    "  @available(swift, obsoleted: 4.0)",
    "  @available(iOS, introduced: 7.0)",
    "  @nonobjc",
    "  public var corners: [Any]! {",
    "    return __corners",
    "  }",
    "",
    "  @available(swift, introduced: 4.0)",
    "  @available(iOS, introduced: 7.0)",
    "  @nonobjc",
    "  public var corners: [Int] {",
    "    return __corners.map { $0.intValue }",
    "  }",
    "",
    "  @available(iOS, introduced: 7.0)",
    "  @nonobjc",
    "  public var spares: [Int] {",
    "    return __spares.map { $0.intValue }",
    "  }",
    "",
    "  @available(macOS, introduced: 10.5) @available(iOS, introduced: 2.0)",
    "  public var early: Int {",
    "    return 0",
    "  }",
    "}",
    "",
}, "\n")

local function gates_before(text, member)
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    local found = 0
    for index, line in ipairs(lines) do
        if line:find("public var " .. member .. ":", 1, true) then
            for back = index - 1, 1, -1 do
                if lines[back]:match("^%s*@") then
                    if lines[back]:match("iOS,%s*introduced:%s*7") then
                        found = found + 1
                    end
                else
                    break
                end
            end
        end
    end
    return found
end

function failures()
    local found = {}
    local output = workspace.run("lowered-overlay-introduced")
    os.rm(output)
    local folder = path.join(output, "stdlib", "public", "Darwin", "Gadgets")
    os.mkdir(folder)
    io.writefile(path.join(folder, "Gadget.swift"), OVERLAY)
    local set = {classes = {Gadget = {["-corners"] = true}}, functions = {}, globals = {}, protocols = {}, types = {}}
    lowered.lower_swift_overlay_folder(output, "Gadgets", set)
    local text = io.readfile(path.join(folder, "Gadget.swift"))
    if gates_before(text, "corners") ~= 0 then
        table.insert(found, "a member written with @available(iOS, introduced: 7.0) keeps its gate although the lowering set names it")
    end
    if gates_before(text, "spares") ~= 1 then
        table.insert(found, "a member the lowering set does not name loses its @available(iOS, introduced: 7.0) gate")
    end
    if not text:find("@available(macOS, introduced: 10.5) @available(iOS, introduced: 2.0)", 1, true) then
        table.insert(found, "a gate for an iOS release the device has is changed")
    end
    if not text:find("@available(swift, obsoleted: 4.0)", 1, true) or not text:find("@available(swift, introduced: 4.0)", 1, true) then
        table.insert(found, "a Swift language gate is removed with the iOS gate")
    end
    return found
end

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "swift-name-render-test")

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
end

local function row(framework, kind, usr, name, header)
    local out = {framework, kind, usr, "-", name, "-", header, "1", "ios=13.0/-/-/0", "-", "-", "-"}
    for column = 13, 21 do
        out[column] = "-"
    end
    return out
end

local function run()
    local cmd = import("gen.cmd_headers", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.rm(SCRATCH)
    local sdk = path.join(SCRATCH, "sdk")
    local headers = path.join(sdk, "System", "Library", "Frameworks", "FixSwift.framework", "Headers")
    write(path.join(headers, "FixSwift.h"), "#pragma clang system_header\n")
    write(path.join(headers, "FixSwift.apinotes"),
          "Name: FixSwift\nClasses:\n- Name: FixBox\n  SwiftName: FixBoxSwift\nProtocols:\n- Name: FixValue\n  SwiftName: __FixObjCValue\n"
          .. "SwiftVersions:\n- Version: 5\n  Protocols:\n  - Name: FixValue\n    SwiftName: FixValueV5\n")
    local rows = {
        row("FixSwift", "interface", "c:objc(cs)FixBox", "FixBox", "FixSwift.h"),
        row("FixSwift", "protocol", "c:objc(pl)FixValue", "FixValue", "FixSwift.h"),
        row("FixSwift", "protocol", "c:objc(pl)FixPlain", "FixPlain", "FixSwift.h"),
    }
    local lines = {}
    for index, columns in ipairs(rows) do
        lines[index] = table.concat(columns, "\t")
    end
    local ir = path.join(SCRATCH, "full.tsv")
    write(ir, table.concat(lines, "\n") .. "\n")
    local tree = path.join(SCRATCH, "tree")
    os.mkdir(path.join(tree, "packages", "frameworks", "apple-backports", "registry"))

    local out = path.join(SCRATCH, "out")
    local port_values = path.join(SCRATCH, "port-values-empty.tsv")
    write(port_values, "# triple=armv7-apple-ios6.1.3 (no values)\n")
    cmd.run({tree = tree, ir = ir, sdk = sdk, out = out, port_values = port_values})

    local header = path.join(out, "Frameworks", "FixSwift.framework", "Headers", "FixSwift.h")
    local text = io.readfile(header) or ""
    check(string.find(text, '__attribute__((swift_name("FixBoxSwift")))\n@interface FixBox', 1, true) ~= nil,
          "the class carries the swift_name its apinotes give, in front of the @interface")
    check(string.find(text, '__attribute__((swift_name("__FixObjCValue")))\n@protocol FixValue', 1, true) ~= nil,
          "the protocol carries the swift_name its apinotes give, in front of the @protocol, not the SwiftVersions one")
    check(string.find(text, "FixBox __attribute__", 1, true) == nil and string.find(text, "FixValue __attribute__", 1, true) == nil,
          "no swift_name is written after the name")
    check(string.find(text, "FixValueV5", 1, true) == nil, "a SwiftVersions entry is not rendered as the default name")
    check(string.find(text, "@protocol FixPlain;", 1, true) ~= nil or string.find(text, "@protocol FixPlain\n", 1, true) ~= nil,
          "a protocol with no apinotes entry has no swift_name")

    local compiled = os.execv("xcrun", {"--sdk", "macosx", "clang", "-fsyntax-only", "-x", "objective-c", header}, {try = true})
    if compiled ~= 0 then print(text) end
    check(compiled == 0, "clang compiles the header with the swift_name attributes")

    os.rm(SCRATCH)
    print("swift name render test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

run()

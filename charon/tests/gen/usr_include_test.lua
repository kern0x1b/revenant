-- The import of a usr/include header that no module map names (the 16.4 SDK's ObjectiveC: objc/NSObject.h and no ObjectiveC module map)
-- is the folder that holds the header, not the framework's name: a header that uses a typedef of NSObject.h imports <objc/NSObject.h>.
-- A framework the SDK holds as a framework is never resolved from usr/include. (A class is forward-declared, not imported.) Pure Lua: the fixture SDK lives under the system's temporary folder.
-- Run: xmake l tests/gen/usr_include_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

-- One IR row of the twenty-one columns: framework, kind, usr, container, name, side, header, line, availability, nullability, type,
-- params, then the columns the renderer reads and this fixture leaves empty.
local function row(framework, kind, usr, name, avail, typ, params, header)
    local out = {framework, kind, usr, "-", name, "-", header, "1", avail, "-", typ, params}
    for column = 13, 21 do
        out[column] = "-"
    end
    return out
end

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
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

    local root = path.join(os.tmpdir(), "usr-include-test-" .. tostring(os.time()))
    local sdk = path.join(root, "sdk")
    write(path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h"), "")
    -- the usr/include folder holds the header and there is no module map for it
    write(path.join(sdk, "usr", "include", "objc", "NSObject.h"), "")
    -- a folder whose subheader refuses a direct import: the folder's umbrella is what a header imports
    write(path.join(sdk, "usr", "include", "dispatch", "dispatch.h"), "")
    write(path.join(sdk, "usr", "include", "dispatch", "queue.h"),
          '#error "Please #include <dispatch/dispatch.h> instead of this file directly."\n')
    -- a module map whose prefix names a folder that does not hold the header (16.4's Darwin names sys/_pthread, which has no socket.h)
    write(path.join(sdk, "usr", "include", "sys", "socket.h"), "")
    write(path.join(sdk, "usr", "include", "Darwin.modulemap"), 'module Darwin [system] {\n  umbrella "sys/_pthread"\n}\n')
    local ir_rows = {
        row("Fixture", "function", "c:@F@FixtureObj", "FixtureObj", "ios=13.0/-/-/0", "FixtureAlias", "(void)", "Fixture.h"),
        row("Fixture", "function", "c:@F@FixtureQueue", "FixtureQueue", "ios=13.0/-/-/0", "dispatch_queue_t", "(void)", "Fixture.h"),
        row("Fixture", "function", "c:@F@FixtureSock", "FixtureSock", "ios=13.0/-/-/0", "sa_thing", "(void)", "Fixture.h"),
        row("ObjectiveC", "typedef", "c:@T@FixtureAlias", "FixtureAlias", "ios=2.0/-/-/0", "int", "-", "NSObject.h"),
        row("Dispatch", "typedef", "c:@T@dispatch_queue_t", "dispatch_queue_t", "ios=2.0/-/-/0", "int", "-", "queue.h"),
        row("Darwin", "typedef", "c:@T@sa_thing", "sa_thing", "ios=2.0/-/-/0", "int", "-", "socket.h"),
        -- the same subheader named by its absolute path, as the IR gives a definition the SDK declares in usr/include
        row("Fixture", "function", "c:@F@FixtureQueueAbs", "FixtureQueueAbs", "ios=13.0/-/-/0", "dispatch_queue_abs_t", "(void)", "Fixture.h"),
        row("Dispatch", "typedef", "c:@T@dispatch_queue_abs_t", "dispatch_queue_abs_t", "ios=2.0/-/-/0", "int", "-",
            path.join(sdk, "usr", "include", "dispatch", "queue.h")),
    }
    local lines = {}
    for index, columns in ipairs(ir_rows) do
        lines[index] = table.concat(columns, "\t")
    end
    local ir = path.join(root, "full.tsv")
    write(ir, table.concat(lines, "\n") .. "\n")

    local out = path.join(root, "out")
    -- an empty run of the port's triple (no enumerator declared for it): the port keeps the IR's values
    local port_values = path.join(root, "port-values.tsv")
    write(port_values, "# triple=armv7-apple-ios6.1.3 (no values)\n")
    cmd.run({tree = root, ir = ir, sdk = sdk, out = out, port_values = port_values})
    local header = io.readfile(path.join(out, "Frameworks", "Fixture.framework", "Headers", "Fixture.h")) or ""
    check(string.find(header, "#import <objc/NSObject.h>", 1, true) ~= nil,
          "a header that uses a typedef of NSObject.h imports the folder that holds it, <objc/NSObject.h>")
    check(string.find(header, "ObjectiveC/NSObject.h", 1, true) == nil,
          "the framework's name is not the prefix of a header the SDK has under usr/include")
    check(string.find(header, "#import <dispatch/dispatch.h>", 1, true) ~= nil and string.find(header, "dispatch/queue.h", 1, true) == nil,
          "a header that refuses a direct import is imported through its folder's umbrella")
    check(string.find(header, "#import <sys/socket.h>", 1, true) ~= nil and string.find(header, "sys/_pthread", 1, true) == nil,
          "a module map's prefix counts only where the header is in that folder")

    os.rm(root)
    print("usr include test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function main()
    run()
end

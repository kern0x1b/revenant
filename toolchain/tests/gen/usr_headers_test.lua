local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "usr-headers-test")

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
end

local function row(framework, kind, usr, name, header, typ, params)
    local out = {framework, kind, usr, "-", name, "-", header, "1", "ios=13.0/-/-/0", "-", typ, params}
    for column = 13, 21 do
        out[column] = "-"
    end
    return out
end

local function run()
    local cmd = import("gen.cmd_headers", {rootdir = TOOLS, anonymous = true})
    local json = import("core.base.json")
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.rm(SCRATCH)
    local sdk = path.join(SCRATCH, "sdk")
    write(path.join(sdk, "usr", "include", "fixture.modulemap"),
          'module Fixture [system] {\n  header "fixture/fixture.h"\n  header "fixture/inner.h"\n  export *\n}\n')
    write(path.join(sdk, "usr", "include", "fixture", "fixture.h"), "")
    write(path.join(sdk, "usr", "include", "fixture", "inner.h"), "")
    local rows = {
        row("Fixture", "function", "c:@F@FixtureFn", "FixtureFn", "fixture.h", "void", "(void)"),
        row("Fixture", "function", "c:@F@FixtureInner", "FixtureInner", "inner.h", "void", "(void)"),
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

    local fixture_h = path.join(out, "usr", "include", "fixture", "fixture.h")
    local inner_h = path.join(out, "usr", "include", "fixture", "inner.h")
    check(os.isfile(fixture_h), "fixture/fixture.h is written under usr/include/fixture")
    check(os.isfile(inner_h), "fixture/inner.h is written under usr/include/fixture")
    check(not os.isfile(path.join(out, "usr", "include", "fixture.h")), "no header is written at the top of usr/include")
    check(not os.isdir(path.join(out, "Frameworks")), "a usr module is not written under Frameworks")
    check(string.find(io.readfile(fixture_h) or "", "FixtureFn", 1, true) ~= nil, "the header carries its declaration")
    check(string.find(io.readfile(inner_h) or "", "FixtureInner", 1, true) ~= nil, "the basename-only header carries its declaration")

    local port_fixture = path.join(out, "port", "6.1.3", "usr", "include", "fixture", "fixture.h")
    check(os.isfile(port_fixture), "the port's fixture.h is written under port/<release>/usr/include/fixture")
    local overlay = json.decode(io.readfile(path.join(out, "port", "6.1.3", "vfs.yaml")))
    local mapped = nil
    for _, dir in ipairs(overlay.roots) do
        if dir.name == path.absolute(path.join(sdk, "usr", "include", "fixture")) then
            for _, file in ipairs(dir.contents) do
                if file.name == "fixture.h" then mapped = file["external-contents"] end
            end
        end
    end
    check(mapped == path.absolute(port_fixture), "the overlay maps the SDK's usr/include/fixture/fixture.h to the port's file")

    os.rm(SCRATCH)
    print("usr headers test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

run()

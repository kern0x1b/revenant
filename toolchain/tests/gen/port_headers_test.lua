local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local function row(kind, usr, name, avail, typ, params)
    local out = {"Fixture", kind, usr, "-", name, "-", "Fixture.h", "1", avail, "-", typ, params}
    for column = 13, 21 do
        out[column] = "-"
    end
    return out
end

local function constant(enum, name, value)
    local out = row("enumconst", "c:@E@" .. enum .. "@" .. name, name, "-", "-", "-")
    out[4], out[14] = enum, value
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
    local json = import("core.base.json")
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local root = path.join(os.tmpdir(), "port-headers-test-" .. tostring(os.time()))
    local sdk = path.join(root, "sdk")
    write(path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h"), "")
    local ir_rows = {
        row("function", "c:@F@FixtureFn", "FixtureFn", "ios=13.0/-/-/0", "void", "(void)"),
        row("function", "c:@F@FixtureOther", "FixtureOther", "ios=13.0/-/-/0", "void", "(void)"),
        row("typedef", "c:@T@FixtureInteger", "FixtureInteger", "-", "long", "-"),
        row("enum", "c:@E@FixtureLimit", "FixtureLimit", "-", "FixtureInteger", "-"),
        constant("FixtureLimit", "FixtureLimitMax", "9223372036854775807"),
        constant("FixtureLimit", "FixtureLimitMin", "-9223372036854775808"),
        constant("FixtureLimit", "FixtureLimitWide", "4611686018427387904"),
    }
    local lines = {}
    for index, columns in ipairs(ir_rows) do
        lines[index] = table.concat(columns, "\t")
    end
    local ir = path.join(root, "full.tsv")
    write(ir, table.concat(lines, "\n") .. "\n")

    local named = path.join(root, "named")
    local bare = path.join(root, "bare")
    write(path.join(named, "packages", "frameworks", "apple-backports", "registry", "Fixture.json"),
          '{"framework": "Fixture", "entries": [{"api": "FixtureFn", "kind": "function", "status": "implemented", "minimum": "6.0"}]}')
    os.mkdir(path.join(bare, "packages", "frameworks", "apple-backports", "registry"))

    local function header(out, release_folder)
        local dir = release_folder and path.join(out, "port", release_folder) or out
        return io.readfile(path.join(dir, "Frameworks", "Fixture.framework", "Headers", "Fixture.h"))
    end

    local port_values = path.join(root, "port-values.tsv")
    write(port_values, "# triple=armv7-apple-ios6.1.3 (fixture)\n"
          .. "enumconst\tFixture\tc:@E@FixtureLimit@FixtureLimitMax\t2147483647\n"
          .. "enumconst\tFixture\tc:@E@FixtureLimit@FixtureLimitMin\t-2147483648\n")
    check(cmd.run({tree = named, ir = ir, sdk = sdk, out = path.join(root, "refused")}) == 2,
          "the headers command refuses to write the port without the port's enumerator values")
    cmd.run({tree = named, ir = ir, sdk = sdk, out = path.join(root, "out-named"), port_values = port_values})
    cmd.run({tree = bare, ir = ir, sdk = sdk, out = path.join(root, "out-bare"), port_values = port_values})

    local faithful = header(path.join(root, "out-named"))
    local ported = header(path.join(root, "out-named"), "6.1.3")
    local bare_faithful = header(path.join(root, "out-bare"))

    check(faithful ~= nil and bare_faithful ~= nil, "the faithful header is written under Frameworks")
    check(ported ~= nil, "the port's header is written under port/<release>/Frameworks")
    check(faithful == bare_faithful, "the faithful headers are the same bytes with and without the registry")
    check(string.find(faithful or "", "introduced=13.0", 1, true) ~= nil and string.find(faithful or "", "FixtureFn", 1, true) ~= nil,
          "the faithful header keeps the SDK's mark for the declaration the registry names")
    check(string.find(ported or "", "introduced=6.1.3", 1, true) ~= nil, "the port's header carries the release for the implemented one")
    check(string.find(ported or "", "FixtureOther", 1, true) ~= nil, "a declaration no entry names is in the port's header too")
    local overlay = io.readfile(path.join(root, "out-named", "port", "6.1.3", "vfs.yaml"))
    local vfs = json.decode(overlay)
    local mapped = nil
    for _, dir in ipairs(vfs.roots) do
        if string.find(dir.name, "Fixture.framework/Headers", 1, true) then
            for _, file in ipairs(dir.contents) do
                if file.name == "Fixture.h" then mapped = file["external-contents"] end
            end
        end
    end
    check(mapped == path.absolute(path.join(root, "out-named", "port", "6.1.3", "Frameworks", "Fixture.framework", "Headers", "Fixture.h")),
          "the overlay maps the SDK's Fixture.h to the port's file")
    local other_mark = string.match(ported or "", "FixtureOther[^\n]*")
    check(other_mark ~= nil and string.find(other_mark, "introduced=13.0", 1, true) ~= nil,
          "a declaration no entry names keeps the SDK's mark in the port's header")
    check(string.find(ported or "", "enum FixtureLimit : FixtureInteger {", 1, true) ~= nil, "the port's enum keeps its fixed type")
    check(string.find(ported or "", "FixtureLimitMax = 2147483647,", 1, true) ~= nil,
          "the port's enumerator takes the triple's value 2147483647 from the run")
    check(string.find(ported or "", "FixtureLimitMin = -2147483648,", 1, true) ~= nil,
          "the port's enumerator takes the triple's value -2147483648 from the run")
    check(string.find(ported or "", "FixtureLimitWide = 4611686018427387904,", 1, true) ~= nil,
          "an enumerator the run does not declare keeps the IR's value")
    check(string.find(faithful or "", "FixtureLimitMax = 9223372036854775807,", 1, true) ~= nil,
          "the faithful header keeps the IR's value of the enumerator")

    os.rm(root)
    print("port headers test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function main()
    run()
end

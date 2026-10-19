-- The port's enumerator values file (tools/found/port_values.lua): the driver runs the extractor over every framework it lists with the
-- port's triple in IR_TARGET, writes the enumerators and the enum types it gives a value, and names each module the extractor does not
-- parse for the triple with its first error. A stand-in extractor (tests/gen/fake_decls.lua) answers for two frameworks: Fixture, which
-- gives its enumerator 2147483647 when IR_TARGET is the port's triple and 9223372036854775807 otherwise, and Broken, which does not
-- parse. The file it writes is read back by tools/gen/port_enums.lua. Run:
--   xmake l tests/gen/port_values_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local REPO = path.join(os.scriptdir(), "..", "..")
local fake = import("fake_decls", {rootdir = path.join(REPO, "tests", "gen"), anonymous = true})

-- The cells of an IR row, the 21 of them, with the given ones by column number (the rest "-"); a value cell may be "%s" (a format).
local function cells(given)
    local out = {}
    for column = 1, 21 do
        out[column] = given[column] or "-"
    end
    return out
end

local function run()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local root = path.join(os.tmpdir(), "port-values-test-" .. tostring(os.time()))
    os.mkdir(root)
    local decls = path.join(root, "decls")
    local out = path.join(root, "port-values.tsv")
    -- the body answers for the framework it is asked about (the third argument: --timeout SECONDS NAME)
    local enumconst = cells({"Fixture", "enumconst", "c:@E@FixtureLimit@FixtureLimitMax", "FixtureLimit", "FixtureLimitMax", "-",
                             "Fixture.h", "1", "-", "-", "-", "-", "-", "%s"})
    local enum = cells({"Fixture", "enum", "c:@E@FixtureLimit", "-", "FixtureLimit", "-", "Fixture.h", "1", "-", "-", "NSInteger"})
    local unparsed = cells({"Broken", "unparsed", "-", "-", "Broken.h:1:1: error: fixture"})
    local body = table.concat({
        "case \"$3\" in",
        "  Fixture)",
        "    case \"$IR_TARGET\" in",
        "      armv7-apple-ios6.1.3) v=2147483647 ;;",
        "      *) v=9223372036854775807 ;;",
        "    esac",
        "    printf '" .. table.concat(enum, "\\t") .. "\\n'",
        "    printf '" .. table.concat(enumconst, "\\t") .. "\\n' \"$v\" ;;",
        "  Broken) printf '" .. table.concat(unparsed, "\\t") .. "\\n' ;;",
        "esac"}, "\n")
    fake.write(decls, body, "fixture-clang target=arm64-apple-ios26.2", "printf 'Fixture\\t/f\\nBroken\\t/b\\n'")

    local output, failure = nil, nil
    try {
        function ()
            output = os.iorunv("xmake", {"l", "./tools/found/port_values.lua"}, {curdir = REPO, envs = {IR_SDK = root,
                IR_PORT_VALUES = out, IR_DECLS = decls, IR_TIMEOUT = "5"}})
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    check(failure == nil, "the driver runs: " .. tostring(failure))
    local written = io.readfile(out) or ""
    check(string.find(output or "", "1 modules unparsed for it", 1, true) ~= nil, "the driver counts the modules it does not parse")
    check(string.find(output or "", "unparsed for armv7-apple-ios6.1.3: Broken: Broken.h:1:1: error: fixture", 1, true) ~= nil,
          "the driver names the module it does not parse for the triple, with its first error")
    check(string.find(written, "# triple=armv7-apple-ios6.1.3", 1, true) ~= nil, "the file's header names the triple")
    check(string.find(written, "enumconst\tFixture\tc:@E@FixtureLimit@FixtureLimitMax\t2147483647\n", 1, true) ~= nil,
          "the enumerator takes the value the triple gives")
    check(string.find(written, "enumtype\tFixture\tc:@E@FixtureLimit\tNSInteger\n", 1, true) ~= nil, "the enum's type is written")
    check(string.find(written, "unparsed\tBroken\t-\tBroken.h:1:1: error: fixture\n", 1, true) ~= nil,
          "the module that does not parse is written with its first error")
    check(string.find(written, "Broken\tc:", 1, true) == nil, "no enumerator of the module that does not parse is written")

    os.rm(root)
    print("port values test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function main()
    run()
end

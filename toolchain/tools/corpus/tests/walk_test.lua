import("core.base.json")

local HERE = os.scriptdir()
local TOOLS = path.join(HERE, "..")
local MODULES = path.join(TOOLS, "..", "..", "modules")
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})
local sw = import("surface_walk", {rootdir = TOOLS, anonymous = true})

local FIXTURE = [[
__attribute__((availability(ios,introduced=13.0)))
@interface FixThing
@property (getter=isEnabled) int enabled;
@property int plain;
- (void)doIt:(int)x;
+ (id)make;
- (void)later __attribute__((availability(ios,introduced=15.0)));
@end
@interface FixThing (Extra)
- (void)extra;
@end
__attribute__((availability(ios,unavailable)))
extern int FixTVOnly;
__attribute__((unavailable))
extern int FixGone;
typedef enum __attribute__((availability(ios,introduced=9.0))) FixMode { FixModeA, FixModeB __attribute__((availability(ios,introduced=10.0))) } FixMode;
extern void FixFunction(void) __attribute__((availability(ios,introduced=8.0,deprecated=12.0)));
static inline int FixInline(void) { return 0; }
static int FixStatic(void);
enum { FixAnonymousA };
]]

local FIXTURE_TARGET = "arm64-apple-ios26.2"

local checks, failures = 0, {}

local function check(condition, message)
    checks = checks + 1
    print("%-4s %s", condition and "ok" or "FAIL", message)
    if not condition then
        table.insert(failures, message)
    end
end

local function raised(f)
    local message = nil
    try {
        function ()
            f()
        end,
        catch {
            function (errors)
                message = tostring(errors)
            end
        }
    }
    return message
end

local function entry(api, status)
    return {api = api, kind = "function", introduced = "9.0", status = status or "implemented", effect = "none", reason = "because"}
end

local function write_registry(root, flat, parts)
    os.mkdir(path.join(root, "Fix"))
    if flat then
        json.savefile(path.join(root, "Fix.json"), {framework = "Fix", entries = flat})
    end
    for name, rows in pairs(parts) do
        json.savefile(path.join(root, "Fix", name), {framework = "Fix", entries = rows})
    end
end

local function version_text(version)
    return version and sw.show_version(version) or "-"
end

local function test_registry_names(scratch)
    local cases = {
        {name = "each name in one file", flat = {entry("fix_one")}, parts = {["part.json"] = {entry("fix_two")}}, refused = false},
        {name = "a name in registry/Fix.json and registry/Fix/part.json", flat = {entry("fix_both")},
         parts = {["part.json"] = {entry("fix_both", "absent")}}, refused = true, named = "fix_both"},
        {name = "a name held by two files however many names each holds", flat = {entry("fix_both"), entry("fix_other")},
         parts = {["part.json"] = {entry("fix_both")}}, refused = true},
    }
    for index, case in ipairs(cases) do
        local root = path.join(scratch, "registry-" .. index)
        write_registry(root, case.flat, case.parts)
        local names = nil
        local said = raised(function () names = sw.registry_names(root, "Fix") end)
        if case.refused then
            check(said ~= nil and said:find("Fix.json", 1, true) ~= nil and said:find("part.json", 1, true) ~= nil
                  and (case.named == nil or said:find(case.named, 1, true) ~= nil),
                  string.format("registry_names refuses %s, naming both files (said: %s)", case.name, tostring(said)))
        else
            check(said == nil and names ~= nil and names.fix_one ~= nil and names.fix_two ~= nil
                  and names.fix_one.status == "implemented" and version_text(names.fix_one.introduced) == "9.0",
                  string.format("registry_names reads %s from both files (said: %s)", case.name, tostring(said)))
        end
    end
end

local function test_surface_fold()
    local surface = sw.new("Test", {full = true})
    surface.target = {api = "TVOnlyThing", kind = "constant", versions = {}}
    surface.target_depth = 0
    surface.target_attrs = {{unavailable = true, platform = "ios"}}
    local detail = surface:resolve("constant")
    check(detail.unavailable and detail.unavailable_ios, "an ios Unavailable availability attribute folds into unavailable_ios")
    local surface2 = sw.new("Test", {full = true})
    surface2.target = {api = "Gone", kind = "constant", versions = {}}
    surface2.target_depth = 0
    surface2.target_attrs = {{unavailable = true}}
    local detail2 = surface2:resolve("constant")
    check(detail2.unavailable and not detail2.unavailable_ios, "an NS_UNAVAILABLE folds into unavailable but not unavailable_ios")
end

local function a_real_api_unavailable_ios(sdk)
    for _, file in ipairs(os.files(path.join(sdk, "System", "Library", "**.h"))) do
        local text = io.readfile(file)
        if text and (text:find("API_UNAVAILABLE(ios)", 1, true) or text:find("API_UNAVAILABLE(ios,", 1, true)) then
            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                if line:find("API_UNAVAILABLE(ios)", 1, true) or line:find("API_UNAVAILABLE(ios,", 1, true) then
                    return path.relative(file, sdk) .. ": " .. line:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 90)
                end
            end
        end
    end
    return nil
end

local function test_platform_check()
    local classify = import("ledger_classify", {rootdir = TOOLS, anonymous = true})
    local tv_only = {api = "TVOnlyThing", kind = "constant", lang = "objc", framework = "SomeFramework"}
    local index = {rows = {TVOnlyThing = {"constant", json.null, true, true}}, macros = {}, flags = {}, typedefs = {}, compiled = {}, failed = {}}
    local status, reason = classify.classify_from_headers("TVOnlyThing", tv_only, index, "6.1.3", {}, {})
    check(status == "not-ios", string.format("a row marked API_UNAVAILABLE(ios) reads not-ios (got %s)", tostring(status)))
    check(tostring(reason):find("leaves the denominator", 1, true) ~= nil, "and the reason says it leaves the denominator")
    local unavailable_here = {api = "DeliberatelyUnavailable", kind = "constant", lang = "objc", framework = "SomeFramework"}
    local index2 = {rows = {DeliberatelyUnavailable = {"constant", json.null, true, false}}, macros = {}, flags = {}, typedefs = {}, compiled = {}, failed = {}}
    local status2, reason2 = classify.classify_from_headers("DeliberatelyUnavailable", unavailable_here, index2, "6.1.3", {}, {})
    check(status2 == "missing" and tostring(reason2):find("NS_UNAVAILABLE", 1, true) ~= nil,
          string.format("NS_UNAVAILABLE stays a row, read missing with that reason (got %s: %s)", tostring(status2), tostring(reason2)))
    local sdk = nil
    local why = raised(function () sdk = workspace.sdk() end)
    if sdk == nil then
        print("skip the SDK half of the platform check: %s", why)
        return
    end
    local found = a_real_api_unavailable_ios(sdk)
    check(found ~= nil, string.format("the SDK's headers do carry API_UNAVAILABLE(ios) declarations, so the mark the test feeds in is a real one (%s)", tostring(found)))
end

local function fixture_sdk(scratch)
    local sdk = path.join(scratch, "FixSDK.sdk")
    io.writefile(path.join(sdk, "System", "Library", "Frameworks", "Fix.framework", "Headers", "Fix.h"), FIXTURE)
    return sdk
end

local function row_text(surface, api)
    local row, detail = surface.rows[api], surface.details[api]
    if row == nil then
        return "missing"
    end
    local parts = {row.kind, version_text(row.version), version_text(detail.introduced), version_text(detail.deprecated),
                   detail.via, detail.unavailable and "unavailable" or "-", detail.unavailable_ios and "ios" or "-",
                   detail.getter or "-", detail.setter or "-"}
    return table.concat(parts, " ")
end

local function test_fixture_walk(sdk)
    local full = sw.declared_surface(sdk, "Fix", FIXTURE_TARGET, true, {})
    local want = {
        {"FixThing", "class 13.0 13.0 - own - - - -"},
        {"FixThing.enabled", "property 13.0 13.0 - container - - isEnabled -"},
        {"FixThing.plain", "property 13.0 13.0 - container - - - -"},
        {"-[FixThing doIt:]", "method 13.0 13.0 - container - - - -"},
        {"+[FixThing make]", "method 13.0 13.0 - container - - - -"},
        {"-[FixThing later]", "method 15.0 15.0 - own - - - -"},
        {"-[FixThing extra]", "method - - - none - - - -"},
        {"FixTVOnly", "constant 999 - - none unavailable ios - -"},
        {"FixGone", "constant - - - none unavailable - - -"},
        {"FixMode", "enum 9.0 9.0 - own - - - -"},
        {"FixModeA", "constant 9.0 9.0 - container - - - -"},
        {"FixModeB", "constant 10.0 10.0 - own - - - -"},
        {"FixFunction()", "function 8.0 8.0 12.0 own - - - -"},
        {"FixInline()", "function - - - none - - - -"},
        {"FixAnonymousA", "constant - - - none - - - -"},
    }
    local order = {}
    for _, item in ipairs(want) do
        local got = row_text(full, item[1])
        check(got == item[2], string.format("the whole-SDK walk reads %s as %s (got %s)", item[1], item[2], got))
        table.insert(order, item[1])
    end
    check(table.concat(full.order, ",") == table.concat(order, ","),
          string.format("the whole-SDK walk keeps the headers' order and nothing else: %s", table.concat(full.order, ",")))
    check(full.anonymous.enum == 1 and full.anonymous.struct == nil and #full.anonymous_order == 1,
          "the enum with no name is counted, and gives no row of its own")
    local plain = sw.declared_surface(sdk, "Fix", FIXTURE_TARGET)
    local names = table.copy(plain.order)
    check(table.concat(names, ",") == "FixThing,FixThing.enabled,FixThing.plain,-[FixThing doIt:],+[FixThing make],-[FixThing later],-[FixThing extra],FixTVOnly,FixGone,FixFunction()",
          string.format("the umbrella walk leaves out enums, cases and inline functions: %s", table.concat(names, ",")))
    check(plain.rows["-[FixThing extra]"].version == nil and sw.same(plain.rows.FixTVOnly.version, sw.unavailable_version()),
          "the umbrella walk gives a category member no version and an ios-unavailable constant the 999 mark")
end

local function run_cli(scratch, arguments)
    local out, err = path.join(scratch, "cli.out"), path.join(scratch, "cli.err")
    local argv = {"l", path.join(TOOLS, "surface-diff.lua")}
    table.join2(argv, arguments)
    local status = os.execv(os.programfile(), argv, {stdout = out, stderr = err, try = true})
    return status, io.readfile(out) or "", io.readfile(err) or ""
end

local function test_cli(scratch, sdk)
    local registry = path.join(scratch, "cli-registry")
    os.mkdir(registry)
    json.savefile(path.join(registry, "Fix.json"), {framework = "Fix", entries = {{api = "FixThing", kind = "class", introduced = "13.0", status = "implemented"}}})
    local rows = path.join(scratch, "rows.tsv")
    local status, stdout, stderr = run_cli(scratch, {"--sdk", sdk, "--target", FIXTURE_TARGET, "--registry", registry, "--list", "--rows", rows, "Fix"})
    local want = table.concat({
        "SDK FixSDK.sdk, target arm64-apple-ios26.2, API that arrived after iOS 6.0",
        "",
        "Fix: 7 declared after iOS 6.0, 2 not decided",
        "  iOS 8   declared     1   decided     0   gap     1",
        "  iOS 13  declared     5   decided     5   gap     0",
        "  iOS 15  declared     1   decided     0   gap     1",
        "    8.0    function  FixFunction()",
        "    15.0   method    -[FixThing later]",
        ""}, "\n")
    check(status == 0 and stdout == want, string.format("surface-diff.lua prints the counts and the gaps (status %s):\n%s%s", tostring(status), stdout, stderr))
    local want_rows = table.concat({
        "Fix\tmethod\t+[FixThing make]\t13.0",
        "Fix\tmethod\t-[FixThing doIt:]\t13.0",
        "Fix\tmethod\t-[FixThing extra]\t",
        "Fix\tmethod\t-[FixThing later]\t15.0",
        "Fix\tfunction\tFixFunction()\t8.0",
        "Fix\tconstant\tFixGone\t",
        "Fix\tconstant\tFixTVOnly\t",
        "Fix\tclass\tFixThing\t13.0",
        "Fix\tproperty\tFixThing.enabled\t13.0",
        "Fix\tproperty\tFixThing.plain\t13.0",
        ""}, "\n")
    local got_rows = io.readfile(rows) or ""
    check(got_rows == want_rows, "surface-diff.lua --rows writes every row in byte order:\n" .. got_rows)
    os.mkdir(path.join(registry, "Fix"))
    json.savefile(path.join(registry, "Fix", "part.json"), {framework = "Fix", entries = {{api = "FixThing", kind = "class", introduced = "13.0", status = "absent"}}})
    local status2, _, stderr2 = run_cli(scratch, {"--sdk", sdk, "--target", FIXTURE_TARGET, "--registry", registry, "Fix"})
    check(status2 ~= 0 and stderr2:find("FixThing is named by both", 1, true) ~= nil and stderr2:find("Fix.json", 1, true) ~= nil
          and stderr2:find("part.json", 1, true) ~= nil,
          string.format("surface-diff.lua stops on a name two registry files hold, naming both (status %s): %s", tostring(status2), stderr2))
end

local function clang_present()
    local ok = try {
        function ()
            os.iorunv("xcrun", {"--find", "clang"})
            return true
        end
    }
    return ok
end

function main()
    local scratch = workspace.fresh("walk-test")
    test_registry_names(scratch)
    test_surface_fold()
    test_platform_check()
    if clang_present() then
        local sdk = fixture_sdk(scratch)
        test_fixture_walk(sdk)
        test_cli(scratch, sdk)
    else
        print("skip the clang walk of the fixture: xcrun finds no clang")
    end
    sw.cleanup()
    os.tryrm(scratch)
    for _, failure in ipairs(failures) do
        print("FAIL %s", failure)
    end
    print("walk_test: %d checks, %d failed", checks, #failures)
    if #failures > 0 then
        os.exit(1)
    end
end

local tool = import("inputs", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local plain_replace, normalize, podspec_public_headers = tool.plain_replace, tool.normalize, tool.podspec_public_headers
local make_rn_codegen, selected, renderer_platform_dirs, compare = tool.make_rn_codegen, tool.selected, tool.renderer_platform_dirs, tool.compare
local byte_less = tool.byte_less
local xml_text, splash_options = tool.xml_text, tool.splash_options
local expo_packages, expo_real, expo_subscribers = tool.expo_packages, tool.expo_real, tool.expo_subscribers
local expo_classes, stub_entries, component_provider, app_optional_components = tool.expo_classes, tool.stub_entries, tool.component_provider, tool.app_optional_components
local app_modules, installed_in_application, expo_dir = tool.app_modules, tool.installed_in_application, tool.expo_dir
local make_app_manifest = tool.make_app_manifest

local DATA = path.join(os.scriptdir(), "data")

local failures = 0

local function check(name, condition, detail)
    if condition then
        print("ok " .. name)
    else
        failures = failures + 1
        print(string.format("FAILED %s%s", name, detail and (": " .. tostring(detail)) or ""))
    end
end

local function sorted(list)
    local copy = table.clone(list)
    table.sort(copy)
    return copy
end

local function same_list(a, b)
    a, b = sorted(a), sorted(b)
    if #a ~= #b then
        return false
    end
    for index = 1, #a do
        if a[index] ~= b[index] then
            return false
        end
    end
    return true
end

local function fresh(name)
    local dir = path.join(os.tmpdir(), "rn-inputs-test", name)
    os.tryrm(dir)
    os.mkdir(dir)
    return dir
end

local function files_under(root)
    local found = {}
    for _, file in ipairs(os.iorunv("find", {root, "-mindepth", "1", "-type", "f"}):split("\n", {plain = true})) do
        if file ~= "" then
            table.insert(found, path.relative(file, root))
        end
    end
    return sorted(found)
end

check("plain_replace replaces every occurrence literally", plain_replace("a%b a%b", "a%b", "x%y") == "x%y x%y")

check("plain_replace leaves the text alone without a match", plain_replace("abc", "z", "y") == "abc")

check("normalize applies the pairs in order", normalize("one two", {{"one", "two"}, {"two", "three"}}) == "three three")

local nitro = podspec_public_headers(path.join(DATA, "NitroModules.podspec"))
check("podspec_public_headers reads the public header list", same_list(nitro, {"cpp/core/AnyMap.hpp", "cpp/core/Null.hpp"}), table.concat(nitro, ","))

local codegen = fresh("codegen")
os.cp(path.join(DATA, "codegen"), path.join(codegen, "codegen"))
make_rn_codegen({build = codegen})
local kept = files_under(path.join(codegen, "rn-codegen"))
check("rn-codegen keeps the component specs and drops the aggregators", same_list(kept, {
    "build/generated/ios/ReactCodegen/FBSpec.h",
    "build/generated/ios/ReactCodegen/RCTSpec.h",
    "build/generated/ios/ReactCodegen/RCTSpecJSI.h"
}), table.concat(kept, ","))

local function error_of(fn)
    local message
    try { fn, catch { function (errors) message = tostring(errors) end } }
    return message
end

local function fails(fn)
    return error_of(fn) ~= nil
end

local message = error_of(function () selected("codegen,not-an-input") end)
check("selected refuses a name that is not an input", message ~= nil and message:find("not-an-input", 1, true) ~= nil, message)

local everything = selected(nil)
local count = 0
for _ in pairs(everything) do
    count = count + 1
end
check("selected chooses every input when none is named", count == 16 and everything["rn-src"] and everything["app-assets"] and everything["app-components"] and everything["app-manifest"], count)

local ordered = {"EXJSI", "EXJavaScript", "ExpoModulesCore", "_private", "a", "b", "é"}
local order_ok = true
for i = 1, #ordered - 1 do
    order_ok = order_ok and byte_less(ordered[i], ordered[i + 1]) and not byte_less(ordered[i + 1], ordered[i])
end
check("byte_less orders by bytes, uppercase before lowercase and multibyte last", order_ok)
check("byte_less puts a prefix first", byte_less("ExpoModules", "ExpoModulesCore") and not byte_less("ExpoModulesCore", "ExpoModules"))

local platforms = renderer_platform_dirs({packages = {["react-native"] = path.join(DATA, "react-native-package")}})
local renderer = path.join(DATA, "react-native-package", "src", "react-native", "ReactCommon", "react", "renderer", "components")
check("renderer_platform_dirs picks ios, or cxx where there is no ios",
    same_list(platforms, {path.join(renderer, "view", "platform", "ios"), path.join(renderer, "text", "platform", "cxx")}), table.concat(platforms, ","))

local left = fresh("compare-left")
local right = fresh("compare-right")
os.mkdir(path.join(left, "rn-codegen"))
os.mkdir(path.join(right, "rn-codegen"))
io.writefile(path.join(left, "rn-codegen", "Spec.h"), "same\n")
io.writefile(path.join(right, "rn-codegen", "Spec.h"), "same\n")
check("compare accepts identical inputs", not fails(function () compare(left, right, {only = "rn-codegen"}) end))

io.writefile(path.join(right, "rn-codegen", "Spec.h"), "changed\n")
check("compare refuses a changed file", fails(function () compare(left, right, {only = "rn-codegen"}) end))

io.writefile(path.join(left, "rn-codegen", "Spec.h"), "path " .. left .. "\n")
io.writefile(path.join(right, "rn-codegen", "Spec.h"), "path " .. right .. "\n")
check("compare reads the built path as the reference path", not fails(function () compare(left, right, {only = "rn-codegen"}) end))

check("xml_text escapes the characters that break a plist string", xml_text("A & <B> C") == "A &amp; &lt;B&gt; C")

local splash = splash_options({plugins = {"expo-router", {"expo-splash-screen", {image = "./logo.png", imageWidth = 200}}}})
check("splash_options reads the expo-splash-screen plugin", splash.image == "./logo.png" and splash.imageWidth == 200)

check("splash_options refuses an application without the plugin", fails(function () splash_options({plugins = {"expo-router"}}) end))

local application = fresh("expo-application")
for _, package in ipairs({"expo", "expo-font", "expo-clipboard", "expo-splash-screen", "expo-audio", "expo-image", "expo-sqlite", "expo-router", "expo-modules-core"}) do
    os.mkdir(path.join(application, "ref", "node_modules", package))
end
local function context(options)
    return {options = options, app = path.join(application, "ref", "packages", "app"), ref = path.join(application, "ref")}
end

local defaults = expo_packages(context({}))
check("the default Expo packages are the real and partial ones the application has", table.contains(defaults, "expo")
    and table.contains(defaults, "expo-font") and table.contains(defaults, "expo-clipboard") and table.contains(defaults, "expo-splash-screen") and table.contains(defaults, "expo-audio") and table.contains(defaults, "expo-image") and table.contains(defaults, "expo-sqlite") and #defaults == 7, table.concat(defaults, ","))

check("the default Expo packages leave out js-only packages and the core even when the application has them", not table.contains(defaults, "expo-router") and not table.contains(defaults, "expo-modules-core"), table.concat(defaults, ","))

local absent = fresh("expo-absent")
os.mkdir(path.join(absent, "ref", "node_modules", "expo"))
local missing = expo_packages({options = {}, app = path.join(absent, "ref", "packages", "app"), ref = path.join(absent, "ref")})
check("the default Expo packages leave out a real package that the application lacks", not table.contains(missing, "expo-font")
    and not table.contains(missing, "expo-battery") and table.contains(missing, "expo"), table.concat(missing, ","))

local parity = expo_packages(context({real = "expo-audio,expo-image"}))
check("--real replaces the default with the parity list on top of the base", table.contains(parity, "expo-audio") and table.contains(parity, "expo-image")
    and table.contains(parity, "expo-asset") and not table.contains(parity, "expo-camera"), table.concat(parity, ","))

check("expo_real marks the packages that the mode builds as real", expo_real(context({}))["expo-font"] and expo_real(context({}))["expo-sqlite"]
    and not expo_real(context({}))["expo-router"] and expo_real(context({real = "expo-audio"}))["expo-audio"])

local xmake_base = {}
for name in (io.readfile(path.join(os.scriptdir(), "..", "src", "expo", "xmake.lua")):match("local EXPO_PARITY_BASE = (%b{})") or ""):gmatch('"([^"]+)"') do
    table.insert(xmake_base, name)
end
local generator_base = expo_packages(context({real = ""}))
check("the parity base in src/expo/xmake.lua is the one of tools/inputs.lua", #xmake_base > 0 and same_list(xmake_base, generator_base),
    table.concat(xmake_base, ",") .. " vs " .. table.concat(generator_base, ","))

local subscribers_app = fresh("expo-subscribers")
local subscriber_ctx = {options = {real = "expo-notifications"}, app = path.join(subscribers_app, "ref", "packages", "app"), ref = path.join(subscribers_app, "ref")}
for _, package in ipairs(expo_packages(subscriber_ctx)) do
    local dir = path.join(subscribers_app, "ref", "node_modules", package)
    if not os.isdir(dir) then
        os.mkdir(dir)
    end
    local config = package == "expo-notifications"
        and '{"apple": {"modules": ["PermissionsModule"], "appDelegateSubscribers": ["NotificationsAppDelegateSubscriber"]}, "android": {"appDelegateSubscribers": ["AndroidOnly"]}}'
        or '{"apple": {"modules": []}}'
    io.writefile(path.join(dir, "expo-module.config.json"), config)
end
local subscribers = expo_subscribers(subscriber_ctx)
check("the app delegate subscribers come from the apple section of the packages that are built", #subscribers == 1
    and subscribers[1] == "      NotificationsAppDelegateSubscriber.self,", table.concat(subscribers, "|"))

local stub_app = fresh("stub-classes")
local stub_ctx = {options = {}, app = path.join(stub_app, "ref", "packages", "app"), ref = path.join(stub_app, "ref")}
local expo_dir_stub = path.join(stub_app, "ref", "node_modules", "expo")
os.mkdir(expo_dir_stub)
io.writefile(path.join(expo_dir_stub, "expo-module.config.json"), '{"apple": {"modules": []}}')
local stub_names = {}
for _, line in ipairs(expo_classes(stub_ctx)) do
    local name = line:match("%(module: (%w+)%.self")
    if name and name:startswith("Stub") then
        table.insert(stub_names, name)
    end
end
local json_names = {}
for _, stub in ipairs(stub_entries()) do
    table.insert(json_names, stub.name)
end
check("the stub classes of the provider are the entries of stubs.json", same_list(stub_names, json_names), table.concat(stub_names, ",") .. " vs " .. table.concat(json_names, ","))

local swift_stubs = io.readfile(path.join(os.scriptdir(), "..", "src", "expo", "StubModules.swift"))
local declared = true
for _, name in ipairs(json_names) do
    if not swift_stubs:find("public final class " .. name .. ":", 1, true) then
        declared = false
    end
end
check("every stub in stubs.json is a class of src/expo/StubModules.swift", declared)

local provider_text = table.concat({
    "  thirdPartyComponents = @{",
    '    @"RNSVGPath": NSClassFromString(@"RNSVGPath"), // react-native-svg',
    "    };",
    '#import "RCTThirdPartyComponentsProvider.h"',
    ""
}, "\n")
local provided = component_provider(provider_text, {"RNCWebView", "RNSVGPath"})
check("the provider is a dictionary of optional components with the macro", provided:find('RNHOST_ADD(@"RNSVGPath", @"RNSVGPath")', 1, true)
    and provided:find('[@"RNCWebView,RNSVGPath" componentsSeparatedByString:@","]', 1, true)
    and provided:find("    thirdPartyComponents = mutableComponents;", 1, true)
    and not provided:find("@{", 1, true), provided)
check("the provider imports RCTLog after the header", provided:find('#import "RCTThirdPartyComponentsProvider.h"\n#import <React/RCTLog.h>\n', 1, true) ~= nil, provided)
check("an empty list keeps the provider of the spike", component_provider(provider_text, {}):find('[@"" componentsSeparatedByString:@","]', 1, true) ~= nil)

local manifest_app = fresh("app-manifest")
io.writefile(path.join(manifest_app, "host.json"), '{"optionalComponents": ["RNCWebView", "RNSVGPath"]}')
check("the app manifest gives the optional components", same_list(app_optional_components({project = manifest_app}), {"RNCWebView", "RNSVGPath"}))
check("a project without host.json is an error, not an empty manifest", fails(function () app_optional_components({project = fresh("no-manifest")}) end))
check("a named manifest that does not exist is an error", fails(function () app_optional_components({project = manifest_app, manifest = path.join(manifest_app, "missing.json")}) end))
local modules_app = fresh("app-modules")
io.writefile(path.join(modules_app, "host.json"), '{"modules": ["@scope/some-module", "plain-module"]}')
check("the app manifest gives the application's own Expo modules", same_list(app_modules({project = modules_app}), {"@scope/some-module", "plain-module"}))
check("an application without host.json has no modules of its own", same_list(app_modules({project = fresh("no-modules")}), {}))
check("a manifest without modules gives none", same_list(app_modules({project = manifest_app}), {}))
check("a named manifest that does not exist is an error for the modules too", fails(function () app_modules({project = modules_app, manifest = path.join(modules_app, "missing.json")}) end))
local bad_modules = fresh("bad-modules")
io.writefile(path.join(bad_modules, "host.json"), '{"modules": ["a,b"]}')
check("a module name with a comma is refused", fails(function () app_modules({project = bad_modules}) end))
local ctx_modules = {options = {}, app = path.join(modules_app, "app"), ref = path.join(modules_app, "ref")}
ctx_modules.options.project = modules_app
check("a module the application does not have is an error", fails(function () expo_packages(ctx_modules) end))
os.mkdir(path.join(modules_app, "app", "node_modules", "@scope", "some-module"))
os.mkdir(path.join(modules_app, "app", "node_modules", "plain-module"))
os.mkdir(path.join(modules_app, "app", "modules", "local-module"))
io.writefile(path.join(modules_app, "host.json"), '{"modules": ["@scope/some-module", "plain-module", "local-module"]}')
check("a module in the application's own modules folder is accepted and resolved there", installed_in_application(ctx_modules, "local-module") and expo_packages(ctx_modules)[#expo_packages(ctx_modules)] == "local-module" and expo_dir(ctx_modules, "local-module"):endswith("/app/modules/local-module"))
io.writefile(path.join(modules_app, "host.json"), '{"modules": ["@scope/some-module", "plain-module"]}')
check("the application's modules join the built packages", (function () local names = expo_packages(ctx_modules); return names[#names - 1] == "@scope/some-module" and names[#names] == "plain-module" end)())
for _, package in ipairs(expo_packages(ctx_modules)) do
    local dir = path.join(modules_app, "app", "node_modules", package)
    if not os.isdir(dir) then
        dir = path.join(modules_app, "ref", "node_modules", package)
    end
    os.mkdir(dir)
    local config = package == "@scope/some-module"
        and '{"platforms": ["ios", "android"], "ios": {"modules": ["SomeModule"], "appDelegateSubscribers": ["SomeSubscriber"]}, "android": {"modules": ["expo.modules.Some"], "appDelegateSubscribers": ["AndroidOnly"]}}'
        or (package == "plain-module" and '{"apple": {"modules": ["PlainModule"]}, "ios": {"modules": ["LegacyModule"]}}' or '{"apple": {"modules": []}}')
    io.writefile(path.join(dir, "expo-module.config.json"), config)
end
local ios_classes = table.concat(expo_classes(ctx_modules), "|")
check("a module under the ios key is in the provider", ios_classes:find("(module: SomeModule.self, name: nil)", 1, true) ~= nil, ios_classes)
check("a module under the apple key still is", ios_classes:find("(module: PlainModule.self, name: nil)", 1, true) ~= nil, ios_classes)
check("the android modules are not", ios_classes:find("expo.modules.Some", 1, true) == nil, ios_classes)
check("a package with both keys registers the apple key and not the ios one", ios_classes:find("LegacyModule", 1, true) == nil, ios_classes)
local ios_subscribers = table.concat(expo_subscribers(ctx_modules), "|")
check("the app delegate subscribers of the ios key are listed, those of android are not", ios_subscribers:find("SomeSubscriber.self", 1, true) ~= nil
    and ios_subscribers:find("AndroidOnly", 1, true) == nil, ios_subscribers)
local named_manifest = fresh("named-manifest")
io.writefile(path.join(named_manifest, "elsewhere.json"), '{"optionalComponents": ["RNSVGPath"]}')
check("the named manifest is read instead of the project's host.json", same_list(app_optional_components({project = fresh("no-manifest-2"), manifest = path.join(named_manifest, "elsewhere.json")}), {"RNSVGPath"}))
local bad_manifest = fresh("bad-manifest")
io.writefile(path.join(bad_manifest, "host.json"), '{"optionalComponents": ["A\\"B"]}')
local json = import("core.base.json")
local manifest_root = fresh("app-manifest-input")
io.writefile(path.join(manifest_root, "host.json"), '{"bundleId": "org.example.app", "optionalComponents": ["RNCWebView"]}')
os.mkdir(path.join(manifest_root, "build"))
make_app_manifest({build = path.join(manifest_root, "build"), options = {project = manifest_root}})
local written = json.decode(io.readfile(path.join(manifest_root, "build", "app-manifest", "host.json")))
check("the app-manifest input carries the application's manifest", written.bundleId == "org.example.app" and written.optionalComponents[1] == "RNCWebView", io.readfile(path.join(manifest_root, "build", "app-manifest", "host.json")))

local refused = false
try {
    function () app_optional_components({project = bad_manifest}) end,
    catch { function () refused = true end }
}
check("a component name with a quote is refused", refused)

local expo_json = import("expo_json", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local hard_rows = '{"rows": [{"id": "expo-a", "group": "expo", "native": true, "status": "real", "note": "resolves {type: opened}, says \\"quoted\\" and {\\"nested\\": {\\"id\\": \\"x\\"}}"}, {"id": "plain", "group": "community", "native": false, "status": "stub", "extra": {"deep": {"id": "inner"}}}]}'
local read_rows = expo_json.coverage_rows(hard_rows)
check("a coverage row whose note has braces, quotes and a nested object with an id is read, and nothing nested is taken for a row", #read_rows == 2 and read_rows[1].id == "expo-a" and read_rows[1].native == true and read_rows[1].status == "real"
    and read_rows[2].id == "plain" and read_rows[2].native == false, #read_rows .. " rows")
local read_names, read_owners = expo_json.stub_entries('{"stubs": [{"file": "src/expo/StubModules.swift", "name": "A{1}", "owner": "expo-a", "note": "{\\"x\\": 1}"}, {"file": "other.swift", "name": "B"}]}')
check("a stub entry with braces in its text is read, and only the entries of StubModules.swift are listed", #read_names == 1 and read_names[1] == "A{1}" and read_owners["A{1}"] == "expo-a", table.concat(read_names, ","))
local nested = expo_json.apple_config('{"platforms": ["apple", "android"], "apple": {"modules": ["One", "Two"], "appDelegateSubscribers": ["Sub"], "info": {"modules": ["NotMine"]}}, "android": {"modules": ["x.Y"]}}')
check("an expo-module.config.json with nested platforms and a nested modules key reads the apple block's own modules and subscribers", table.concat(nested.modules, ",") == "One,Two" and table.concat(nested.subscribers, ",") == "Sub", table.concat(nested.modules, ","))
local legacy = expo_json.apple_config('{"ios": {"modules": ["Legacy"]}}')
check("the ios block is read when there is no apple block", table.concat(legacy.modules, ",") == "Legacy", table.concat(legacy.modules, ","))
local both = expo_json.apple_config('{"ios": {"modules": ["Legacy"]}, "apple": {"modules": ["Current"]}}')
check("the apple block wins when both are present", table.concat(both.modules, ",") == "Current", table.concat(both.modules, ","))
local neither = expo_json.apple_config('{"android": {"modules": ["x.Y"]}}')
check("a config with no apple or ios block has no modules", #neither.modules == 0 and #neither.subscribers == 0, #neither.modules)
local real_rows = expo_json.coverage_rows(io.readfile(path.join(os.scriptdir(), "..", "src", "coverage.json")))
local _, real_ids = io.readfile(path.join(os.scriptdir(), "..", "src", "coverage.json")):gsub('\n   "id":', "")
check("every row of coverage.json is read", #real_rows == real_ids, #real_rows .. " rows, " .. real_ids .. " ids")
local noisy = 'warn {not json} at "x {y}"\n{"name": "App", "extra": {"a": "}{", "list": [{"b": 1}]}, "scheme": "s"}\n'
local printed_text, printed_value = expo_json.printed_object(noisy)
check("the configuration object is found after log lines with braces, and braces inside its strings do not end it", printed_value ~= nil and printed_value.name == "App" and printed_value.extra.a == "}{" and printed_value.extra.list[1].b == 1 and printed_text:find('^{"name"') ~= nil, tostring(printed_text))
check("text with no JSON object has no configuration", expo_json.printed_object("nothing {here}\n") == nil, "a non-JSON brace pair was taken for a configuration")
if failures > 0 then
    raise("%d react-native inputs test(s) failed", failures)
end

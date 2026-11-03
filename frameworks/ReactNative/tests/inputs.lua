local tool = import("inputs", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local plain_replace, normalize, podspec_public_headers = tool.plain_replace, tool.normalize, tool.podspec_public_headers
local make_rn_codegen, selected, renderer_platform_dirs, compare = tool.make_rn_codegen, tool.selected, tool.renderer_platform_dirs, tool.compare
local byte_less = tool.byte_less
local xml_text, splash_options = tool.xml_text, tool.splash_options
local expo_packages, expo_real = tool.expo_packages, tool.expo_real

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
check("selected chooses every input when none is named", count == 14 and everything["rn-src"] and everything["app-assets"], count)

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

local defaults = expo_packages({})
check("the default Expo packages are the real and partial ones of coverage.json", table.contains(defaults, "expo")
    and table.contains(defaults, "expo-font") and table.contains(defaults, "expo-clipboard") and table.contains(defaults, "expo-splash-screen"), table.concat(defaults, ","))

check("the default Expo packages leave out stubs, missing and js-only packages, and the core", not table.contains(defaults, "expo-audio")
    and not table.contains(defaults, "expo-image") and not table.contains(defaults, "expo-router") and not table.contains(defaults, "expo-modules-core"), table.concat(defaults, ","))

local parity = expo_packages({real = "expo-audio,expo-image"})
check("--real replaces the default with the parity list on top of the base", table.contains(parity, "expo-audio") and table.contains(parity, "expo-image")
    and table.contains(parity, "expo-asset") and not table.contains(parity, "expo-camera"), table.concat(parity, ","))

check("expo_real marks the packages that the mode builds as real", expo_real({options = {}})["expo-font"] and not expo_real({options = {}})["expo-audio"]
    and expo_real({options = {real = "expo-audio"}})["expo-audio"])

if failures > 0 then
    raise("%d react-native inputs test(s) failed", failures)
end

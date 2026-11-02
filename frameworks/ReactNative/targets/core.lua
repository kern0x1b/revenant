local inputs = os.getenv("RN_INPUTS") or path.join(os.projectdir(), "build")
local src = path.normalize(path.join(os.scriptdir(), "..", "src"))
local rn = os.getenv("RN_SRC") or path.join(inputs, "rn-src")
local rc = path.join(rn, "ReactCommon")
local generated = path.join(inputs, "codegen", "build", "generated", "ios")
local rn_headers = os.getenv("RN_HEADERS") or path.join(inputs, "rn-headers")
local ref = path.join(inputs, "ref", "paseo")
local dispatch = path.join(src, "ios6", "RNHostDispatch.h")
local RN_FLAGS = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DUSE_HERMES=0", "-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1"}

local function rn_headers_dir()
    if os.isdir(rn_headers) then
        add_includedirs(rn_headers)
    end
end

local function rn_includes()
    rn_headers_dir()
    add_includedirs(rc,path.join(rc, "jsi"), path.join(rc, "yoga"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "reactperflogger"), path.join(rc, "logger"), path.join(rc, "jsiexecutor"), path.join(rc, "jsinspector-modern"), path.join(rc, "cxxreact"), path.join(rc, "react", "nativemodule", "core"), path.join(rc, "oscompat"), path.join(rc, "jserrorhandler"), path.join(rc, "jsitooling"), path.join(rc, "devtoolsruntimesettings"))
end

local function platform_includes()
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
end

local RN_PODS = {
    {package = "@react-native-async-storage/async-storage", codegen = "rnasyncstorage"},
}
if os.getenv("RN_PODS_MORE") then
    for _, pod in ipairs(string.split(os.getenv("RN_PODS_MORE"), ",", {plain = true})) do
        local package, codegen = pod:match("^([^:]+):?(.*)$")
        table.insert(RN_PODS, {package = package, codegen = codegen ~= "" and codegen or nil})
    end
end

local PKG_DIRS = {}
for _, pair in ipairs(string.split(os.getenv("RN_PKG_DIRS") or "", ",", {plain = true})) do
    local name, dir = pair:match("^([^=]+)=(.+)$")
    if name then
        PKG_DIRS[name] = dir
    end
end

local function expo_dir(package)
    if PKG_DIRS[package] then
        return PKG_DIRS[package]
    end
    for _, base in ipairs({path.join(ref, "packages", "app", "node_modules"), path.join(ref, "node_modules")}) do
        if os.isdir(path.join(base, package)) then
            return path.join(base, package)
        end
    end
    return path.join(ref, "node_modules", package)
end

target("rn-jsi")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    add_packages("libcxx")
    add_files(path.join(rn, "ReactCommon", "jsi", "jsi", "jsi.cpp"), path.join(rn, "ReactCommon", "jsi", "jsi", "jsilib-posix.cpp"))
    add_includedirs(path.join(rn, "ReactCommon", "jsi"), {public = true})
    set_languages("c++20")
    set_optimize("fastest")

target("rn-jsc")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    add_packages("libcxx")
    add_deps("rn-jsi")
    add_files(path.join(rc, "jsc", "JSCRuntime.cpp"))
    add_includedirs(path.join(rc, "jsc"), {public = true})
    set_languages("c++20")
    set_optimize("fastest")

target("rn-yoga")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    add_packages("libcxx")
    add_files(path.join(rc, "yoga", "yoga", "**.cpp"))
    add_includedirs(path.join(rc, "yoga"), {public = true})
    set_languages("c++20")
    set_optimize("fastest")

target("rn-core")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly", "socketrocket")
    end
    add_deps("rn-jsi", "rn-jsc", "rn-yoga")
    local function skip(f)
        return f:find("/tests/", 1, true) or f:find("android", 1, true) or f:find("/hermes/", 1, true) or f:find("Test", 1, true)
            or f:find("/benchmarks/", 1, true) or f:find("/fuzzers/", 1, true) or (f:find("/platform/cxx/", 1, true) and os.isdir(path.join(f:sub(1, f:find("/platform/cxx/", 1, true) - 1), "platform", "ios")))
            or (f:find("/platform/cxx/", 1, true) and os.isfile(path.join(f:sub(1, f:find("/platform/cxx/", 1, true) - 1), (f:match("([^/]+)%.cpp$") or "") .. ".mm")))
            or f:find("/PlatformStubs/", 1, true)
            or f:find("/platform/windows", 1, true) or f:find("/jsc/", 1, true) or f:find("/jsi/", 1, true) or f:find("/yoga/", 1, true)
            or f:find("/Libraries/AppDelegate/", 1, true) or (f:find("/RCTSwiftUI", 1, true) and not f:find("RCTSwiftUIContainerViewWrapper.m", 1, true)) or f:find("/Libraries/Wrapper/", 1, true)
            or f:find("/FantomForcedCloneCommitHook.cpp", 1, true)
            or f:find("RCTHermesInstance", 1, true) or f:find("MacOSSwitchShadowNode", 1, true) or f:find("/test_utils/", 1, true)
    end
    for _, f in ipairs(os.files(path.join(rc, "**.cpp"))) do
        if not skip(f) then add_files(f) end
    end
    add_files(path.join(rc, "jsi", "jsi", "JSIDynamic.cpp"))
    add_files(path.join(src, "ios6", "RCTSwiftUIContainerViewWrapper.m"))
    for _, f in ipairs(os.files(path.join(rn, "React", "**.cpp"))) do
        if not skip(f) then add_files(f) end
    end
    add_frameworks("Accelerate", "QuartzCore", "ImageIO", "CoreText", "MobileCoreServices", "AudioToolbox", "CoreGraphics", "UIKit", "Foundation")
    for _, root in ipairs({path.join(rn, "React"), path.join(rn, "Libraries"), rc}) do
        for _, f in ipairs(os.files(path.join(root, "**.m"))) do
            if not skip(f) then add_files(f) end
        end
        for _, f in ipairs(os.files(path.join(root, "**.mm"))) do
            if not skip(f) then
                add_files(f)
            end
        end
    end
    rn_includes()
    add_includedirs(path.join(rn, "ReactApple", "RCTSwiftUIWrapper"), path.join(rn, "React"), path.join(rn, "React", "FBReactNativeSpec"), path.join(rn, "React", "Fabric"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), path.join(rn, "ReactApple", "Libraries", "RCTFoundation"), path.join(rc, "react", "renderer", "components", "switch", "iosswitch"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    add_cxxflags(RN_FLAGS, {force = true})
    add_mxxflags(RN_FLAGS, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    add_mflags("-fobjc-arc", {force = true})
    add_mxxflags("-include", dispatch, {force = true})
    add_mflags("-include", dispatch, {force = true})
    set_languages("gnu11", "c++20")

target("rn-appdelegate")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly", "socketrocket")
    end
    add_deps("rn-jsi", "rn-jsc", "rn-yoga")
    for _, name in ipairs({"RCTReactNativeFactory", "RCTRootViewFactory", "RCTDefaultReactNativeFactoryDelegate", "RCTAppSetupUtils"}) do
        add_files(path.join(rn, "Libraries", "AppDelegate", name .. ".mm"))
    end
    add_files(path.join(generated, "ReactAppDependencyProvider", "RCTAppDependencyProvider.mm"))
    for _, name in ipairs({"RCTModulesConformingToProtocolsProvider", "RCTUnstableModulesRequiringMainQueueSetupProvider", "RCTModuleProviders"}) do
        add_files(path.join(generated, "ReactCodegen", name .. ".mm"))
    end
    add_files(path.join(inputs, "rn-spike-gen", "RCTThirdPartyComponentsProvider.mm"))
    add_includedirs(path.join(generated, "ReactCodegen"))
    add_frameworks("QuartzCore", "CoreGraphics", "UIKit", "Foundation")
    rn_includes()
    add_includedirs(path.join(rn, "Libraries", "AppDelegate"), generated, path.join(generated, "ReactAppDependencyProvider"), path.join(rn, "React"), path.join(rn, "React", "Fabric"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    add_cxxflags(RN_FLAGS, {force = true})
    add_mxxflags(RN_FLAGS, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    set_languages("gnu11", "c++20")

target("rn-pods-objc")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly", "socketrocket")
    end
    local gen = generated
    local added = {}
    for _, pod in ipairs(RN_PODS) do
        local root = expo_dir(pod.package)
        add_includedirs(root)
        for _, sub in ipairs({"ios", "apple", "common/cpp", "Common/cpp", "Common/NativeView", "cpp"}) do
            local base = path.join(root, sub)
            if os.isdir(base) then
                for _, ext in ipairs({"**.m", "**.mm", "**.cpp"}) do
                    for _, f in ipairs(os.files(path.join(base, ext))) do
                        local key = f:lower()
                        local rel = path.relative(f, root)
                        if not added[key] and not rel:find("[Tt]est") and not rel:find("Example") and not f:find("WorkletHermesRuntime") and not f:find("react-native-screens/ios/gamma/", 1, true) and not f:find("react-native-keyboard-controller/ios/", 1, true) and not f:find("UIImage+ImageEffects", 1, true) then
                            added[key] = true
                            add_files(f)
                        end
                    end
                end
                add_includedirs(base)
                for _, dir in ipairs(os.dirs(path.join(base, "**"))) do add_includedirs(dir) end
            end
        end
        if pod.codegen then
            add_files(path.join(gen, "ReactCodegen", pod.codegen, pod.codegen .. "-generated.mm"))
            for _, f in ipairs(os.files(path.join(gen, "ReactCodegen", "react", "renderer", "components", pod.codegen, "*.cpp"))) do add_files(f) end
        end
    end
    add_files(path.join(src, "ios6", "KeyboardControllerStubs.mm"))
    add_includedirs(path.join(src, "ios6", "include"), path.join(rn, "Libraries", "AppDelegate"))
    rn_headers_dir()
    add_includedirs(path.join(inputs, "lib-headers"), gen, path.join(gen, "ReactCodegen"), path.join(rc, "yoga"), rc, path.join(rc, "jsi"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "jsitooling"), path.join(rc, "reactperflogger"), path.join(rc, "cxxreact"), path.join(rn, "React"), path.join(rn, "React", "Fabric"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics", "CoreMotion")
    add_cxxflags(RN_FLAGS, {force = true})
    add_mxxflags(RN_FLAGS, {force = true})
    add_cxxflags("-DWORKLETS_VERSION=0.10.4", "-DREANIMATED_VERSION=4.5.5", "-DREACT_NATIVE_MINOR_VERSION=86", {force = true})
    add_mxxflags("-DWORKLETS_VERSION=0.10.4", "-DREANIMATED_VERSION=4.5.5", "-DREACT_NATIVE_MINOR_VERSION=86", {force = true})
    local podprefix = path.join(src, "pods", "PodPrefix.h")
    add_mxxflags("-fobjc-arc", "-include", podprefix, {force = true})
    add_mflags("-fobjc-arc", "-include", podprefix, {force = true})
    set_languages("gnu11", "c++20")

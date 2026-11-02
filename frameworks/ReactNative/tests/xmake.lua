local inputs = os.getenv("RN_INPUTS") or path.join(os.projectdir(), "build")
local probes = path.join(os.scriptdir(), "probes")
local reactcommon = path.join((os.getenv("RN_SRC") or path.join(inputs, "ref", "paseo", "node_modules", "react-native")), "ReactCommon")

target("rn-jsc-host")
    set_kind("binary")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_files(path.join(probes, "jsc-host", "main.c"))
    add_frameworks("JavaScriptCore")
    set_optimize("fastest")

target("rn-probe-folly")
    set_kind("object")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly")
    end
    add_files(path.join(probes, "folly", "dynamic.cpp"))
    add_includedirs(path.join(reactcommon, "jsi"), path.join(reactcommon, "jsi", "jsi"))
    set_languages("c++20")

target("rn-yoga-test")
    set_kind("binary")
    add_rules("@addon/revenant/apple-ios")
    add_packages("libcxx")
    add_deps("rn-yoga")
    set_default(false)
    add_files(path.join(probes, "yoga", "main.cpp"))
    set_languages("c++20")
    set_optimize("fastest")

target("rn-ios-probe")
    set_kind("object")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    local rn = (os.getenv("RN_SRC") or path.join(inputs, "ref", "paseo", "node_modules", "react-native"))
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly", "socketrocket")
    end
    local file = os.getenv("RN_PROBE_FILE")
    if file then
        add_files(path.join(rn, file))
    elseif os.getenv("RN_PROBE_ALL") then
        for _, slice in ipairs({"Base", "Views", "Modules", "CoreModules", "Fabric"}) do
            add_files(path.join(rn, "React", slice, "**.m"), path.join(rn, "React", slice, "**.mm"))
        end
        remove_files(path.join(rn, "React", "CoreModules", "RCTWebSocketModule.mm"))
    end
    if os.getenv("RN_HEADERS") then
        add_includedirs(os.getenv("RN_HEADERS"))
    end
    add_includedirs(path.join(rn, "React"), path.join(rn, "ReactCommon"), path.join(rn, "ReactCommon", "jsi"), path.join(rn, "ReactCommon", "react", "nativemodule", "core"), path.join(rn, "Libraries"), path.join(rn, "ReactCommon", "yoga"), path.join(rn, "ReactApple", "Libraries", "RCTFoundation"), path.join(rn, "ReactApple"), path.join(rn, "ReactCommon", "callinvoker"), path.join(rn, "ReactCommon", "runtimeexecutor"), path.join(rn, "ReactCommon", "reactperflogger"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do
        add_includedirs(dir)
    end
    add_includedirs(path.join(rn, "React", "Fabric"))
    add_includedirs(path.join(rn, "React", "FBReactNativeSpec"))
    for _, dir in ipairs(os.dirs(path.join(rn, "ReactCommon", "**", "platform", "ios"))) do
        add_includedirs(dir)
    end
    for _, dir in ipairs(os.dirs(path.join(rn, "ReactCommon", "**", "platform", "cxx"))) do
        add_includedirs(dir)
    end
    add_includedirs(path.join(rn, "ReactCommon", "react", "renderer", "components", "switch", "iosswitch"))
    add_mflags("-fobjc-arc", {force = true})
    add_mxflags("-fobjc-arc", {force = true})
    add_mxxflags("-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", {force = true})
    set_languages("gnu11", "c++20")

target("rn-lib-probe")
    set_kind("object")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly", "socketrocket")
    end
    local nm = path.join(inputs, "ref", "paseo", "node_modules")
    local rn = (os.getenv("RN_SRC") or path.join(inputs, "ref", "paseo", "node_modules", "react-native"))
    local rc = path.join(rn, "ReactCommon")
    local appnm = path.join(nm, "..", "packages", "app", "node_modules")
    local libname = os.getenv("RN_LIB") or "react-native-screens"
    local lib = os.isdir(path.join(appnm, libname)) and path.join(appnm, libname) or path.join(nm, libname)
    local function libdir(name) return os.isdir(path.join(appnm, name)) and path.join(appnm, name) or path.join(nm, name) end
    local function skip(f)
        return f:find("/android", 1, true) or f:find("/example", 1, true) or f:find("Tests", 1, true) or f:find("/windows", 1, true)
            or f:find("WorkletHermesRuntime", 1, true)
            or f:find("/macos", 1, true) or f:find("/node_modules/", #lib, true) or f:find("/__tests__/", 1, true)
    end
    for _, ext in ipairs({"m", "mm", "cpp"}) do
        for _, f in ipairs(os.files(path.join(lib, "**." .. ext))) do
            if not skip(f) then add_files(f) end
        end
    end
    local seen = {}
    for _, f in ipairs(os.files(path.join(lib, "**.h*"))) do
        local d = path.directory(f)
        if not skip(f) and not seen[d] then seen[d] = true; add_includedirs(d) end
        local root = d:match("^(.-)/react/renderer/")
        if root and not skip(f) and not seen[root] then seen[root] = true; add_includedirs(root) end
    end
    add_includedirs(lib)
    for d in pairs(table.clone(seen)) do
        local up = path.directory(d)
        while up:startswith(lib) and #up > #lib do
            if not seen[up] then seen[up] = true; add_includedirs(up) end
            up = path.directory(up)
        end
    end
    for _, extra in ipairs((os.getenv("RN_LIB_EXTRA") or ""):split(",", {plain = true})) do
        if extra ~= "" then
            local root = libdir(extra)
            for _, f in ipairs(os.files(path.join(root, "**.h*"))) do
                local d = path.directory(f)
                if not f:find("/android", 1, true) then
                    while d:startswith(root) and #d >= #root do
                        if not seen[d] then seen[d] = true; add_includedirs(d) end
                        d = path.directory(d)
                    end
                end
            end
        end
    end
    add_includedirs(path.join(inputs, "lib-headers"))
    local defs = {"-DREACT_NATIVE_MINOR_VERSION=86", "-DREACT_NATIVE_PATCH_VERSION=3", "-DREACT_NATIVE_VERSION_MAJOR=0", "-DREACT_NATIVE_VERSION_MINOR=86",
                  '-DREANIMATED_VERSION_STRING="4.5.5"', '-DWORKLETS_VERSION_STRING="0.9.0"', "-DRN_SERIAL_NUMBER=1"}
    add_cxxflags(defs, {force = true})
    add_mxxflags(defs, {force = true})
    add_mflags(defs, {force = true})
    if os.getenv("RN_MODULES") then
        add_mflags("-include", path.join(inputs, "keyboard", "prefix.h"), {force = true})
        add_mxxflags("-include", path.join(inputs, "keyboard", "prefix.h"), {force = true})
    else
        add_mflags("-include", "UIKit/UIKit.h", {force = true})
        add_mxxflags("-include", "UIKit/UIKit.h", {force = true})
    end
    local gen = path.join(inputs, "codegen", "build", "generated", "ios")
    add_includedirs(gen, path.join(gen, "ReactCodegen"))
    for _, dir in ipairs(os.dirs(path.join(gen, "ReactCodegen", "*"))) do add_includedirs(dir) end
    if os.getenv("RN_HEADERS") then
        add_includedirs(os.getenv("RN_HEADERS"))
    end
    add_includedirs(rc, path.join(rc, "jsi"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "yoga"), path.join(rc, "react", "nativemodule", "core"), path.join(rn, "React"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), path.join(rn, "React", "Fabric"), path.join(rn, "React", "FBReactNativeSpec"))
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    local flags = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DUSE_HERMES=0", "-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1"}
    add_cxxflags(flags, {force = true})
    add_mxxflags(flags, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    add_mflags("-fobjc-arc", {force = true})
    if os.getenv("RN_MODULES") then
        local modcache = path.join(inputs, "clang-modules")
        local modflags = {"-fmodules", "-fimplicit-module-maps", "-fmodules-cache-path=" .. modcache, "-fmodule-map-file=" .. path.join(inputs, "expo-core", "react.modulemap")}
        add_mflags(modflags, {force = true})
        add_mxxflags(modflags, {force = true})
    end
    set_languages("gnu11", "c++20")

target("rn-cxx-probe")
    set_kind("object")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    if os.getenv("RN_DEPS_REPO") then
        add_packages("folly")
    end
    local rn = (os.getenv("RN_SRC") or path.join(inputs, "ref", "paseo", "node_modules", "react-native"))
    local rc = path.join(rn, "ReactCommon")
    local slice = os.getenv("RN_CXX_SLICE") or "cxxreact"
    for _, f in ipairs(os.files(path.join(rc, slice, "**.cpp"))) do
        if not (f:find("/tests/", 1, true) or f:find("android", 1, true) or f:find("/platform/android", 1, true) or f:find("/hermes/", 1, true) or f:find("/platform/cxx/", 1, true) or f:find("/platform/windows", 1, true) or f:find("Test", 1, true) or f:find("/benchmarks/", 1, true) or f:find("/fuzzers/", 1, true)) then
            add_files(f)
        end
    end
    add_includedirs(rc, path.join(rc, "jsi"), path.join(rc, "yoga"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "reactperflogger"), path.join(rc, "logger"), path.join(rc, "jsiexecutor"), path.join(rc, "jsinspector-modern"), path.join(rc, "cxxreact"), path.join(rc, "react", "nativemodule", "core"), path.join(rc, "oscompat"), path.join(rc, "jserrorhandler"), path.join(rc, "jsitooling"), path.join(rc, "devtoolsruntimesettings"), path.join(rn, "React"), path.join(rn, "React", "FBReactNativeSpec"))
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do
        add_includedirs(dir)
    end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do
        add_includedirs(dir)
    end
    add_cxxflags("-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", {force = true})
    set_languages("c++20")


target("rn-probes")

    set_kind("phony")

    set_default(false)

    add_tests("compile")

    on_test(function (target)

        for _, name in ipairs({"rn-jsc-host", "rn-probe-folly", "rn-yoga-test", "rn-ios-probe", "rn-lib-probe", "rn-cxx-probe"}) do

            os.vrunv(os.programfile(), {"build", "-P", os.projectdir(), "-y", name})

        end

    end)

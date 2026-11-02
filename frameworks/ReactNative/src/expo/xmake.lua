local SOURCES = path.absolute(path.join(os.scriptdir(), ".."))
local EXPO_ONLY = {expo = "Fetch"}
local EXPO_BUILT = {real = true, partial = true}

local function coverage_rows()
    local text = io.readfile(path.join(SOURCES, "coverage.json"))
    local rows = {}
    for object in text:gmatch("{([^{}]-)}") do
        local id = object:match('"id":%s*"([^"]*)"')
        if id then
            table.insert(rows, {
                id = id,
                group = object:match('"group":%s*"([^"]*)"'),
                native = object:match('"native":%s*(%a+)') == "true",
                status = object:match('"status":%s*"([^"]*)"'),
            })
        end
    end
    local _, keys = text:gsub('"id":', "")
    if keys ~= #rows then
        raise("coverage.json: %d ids but %d rows were read", keys, #rows)
    end
    return rows
end

local function modules()
    local expo, real = {}, {}
    for _, row in ipairs(coverage_rows()) do
        if row.native and (row.id == "expo" or row.id:startswith("expo-")) and EXPO_BUILT[row.status] and row.id ~= "expo-modules-core" then
            table.insert(expo, row.id)
            real[row.id] = true
        end
    end
    return expo, real
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
    local ref = path.join(os.projectdir(), "build", "ref", "paseo")
    for _, base in ipairs({path.join(ref, "packages", "app", "node_modules"), path.join(ref, "node_modules")}) do
        if os.isdir(path.join(base, package)) then
            return path.join(base, package)
        end
    end
    return path.join(ref, "node_modules", package)
end

local function react_native()
    return path.join(os.projectdir(), "build", "rn-src")
end

local function react_native_headers()
    return path.join(os.projectdir(), "build", "rn-headers")
end

local function package_store()
    return path.join(os.getenv("REVENANT_CACHE") or path.join(os.projectdir(), ".cache"), "xmake-global", ".xmake", "packages")
end

local function newest_installed(package, version)
    local newest, stamp = nil, 0
    for _, dir in ipairs(os.dirs(path.join(package_store(), package:sub(1, 1), package, version, "*", "include"))) do
        if os.mtime(dir) >= stamp then
            newest, stamp = dir, os.mtime(dir)
        end
    end
    return newest
end

local function response_for_swift_cxx(lines, response)
    return function (target)
        local all = table.copy(lines)
        for _, dep in ipairs({{"folly", "2024.11.18.00"}, {"boost", "1.84.0"}, {"glog", "0.3.5"}, {"fmt", "12.1.0"}, {"double-conversion", "1.1.6"}, {"fast_float", "8.0.0"}}) do
            local dir = newest_installed(dep[1], dep[2])
            if dir then
                table.join2(all, {"-Xcc", "-I" .. dir})
            end
        end
        table.join2(all, {"-Xcc", "-I" .. react_native_headers()})
        local rr = path.join(react_native(), "ReactCommon", "react", "renderer")
        for _, plat in ipairs(os.dirs(path.join(rr, "**", "platform"))) do
            local pick = os.isdir(path.join(plat, "ios")) and "ios" or (os.isdir(path.join(plat, "cxx")) and "cxx" or nil)
            if pick then
                table.join2(all, {"-Xcc", "-I" .. path.join(plat, pick)})
            end
        end
        local rnroot = react_native()
        for _, d in ipairs({path.join(rnroot, "React", "FBReactNativeSpec"), path.join(os.projectdir(), "build", "codegen", "build", "generated", "ios", "ReactCodegen"), path.join(rnroot, "React", "CoreModules"), path.join(rnroot, "ReactCommon", "react", "nativemodule", "core"), path.join(rnroot, "ReactCommon", "react", "nativemodule", "core", "platform", "ios"), path.join(rnroot, "React", "Base"), path.join(rnroot, "ReactCommon", "react", "runtime", "platform", "ios"), path.join(rnroot, "ReactCommon", "jsitooling"), path.join(rnroot, "ReactCommon", "react", "runtime")}) do
            table.join2(all, {"-Xcc", "-I" .. d})
        end
        for _, f in ipairs({"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DRCT_NEW_ARCH_ENABLED=1", "-std=c++20", "-I" .. path.join(react_native(), "ReactCommon", "yoga")}) do
            table.join2(all, {"-Xcc", f})
        end
        io.writefile(response, table.concat(all, "\n") .. "\n")
    end
end

local EXPO_SKIP_FILES = {"FontUtils"}
local EXPO_SKIP_MODULES = {FontUtilsModule = true}
local function expo_skip(f)
    for _, name in ipairs(EXPO_SKIP_FILES) do
        if f:find(name, 1, true) then return true end
    end
    return false
end
local GATE14 = {{"@available(iOS 14, tvOS 14, *)\n", ""}}
local EXPO_REWRITE = {
    ["FileSystemModule.swift"] = {package = "expo-file-system", replace = GATE14},
    ["FileSystemDownload.swift"] = {package = "expo-file-system", replace = GATE14},
    ["FileSystemFileHandle.swift"] = {package = "expo-file-system", replace = GATE14},
}
local LOCAL_COPIES = {
    ["expo-glass-effect"] = "GlassView.swift",
    ["expo-localization"] = "LocalizationModule.swift",
}
local STUB_OWNERS = {StubFontLoaderModule = "expo-font", StubClipboardModule = "expo-clipboard", StubFileSystemModule = "expo-file-system", StubHapticsModule = "expo-haptics", StubAudioModule = "expo-audio", StubSplashScreenModule = "expo-splash-screen", StubSharingModule = "expo-sharing", StubDocumentPickerModule = "expo-document-picker", StubImagePickerModule = "expo-image-picker", StubCameraModule = "expo-camera", StubSQLiteModule = "expo-sqlite", StubImageManipulatorModule = "expo-image-manipulator"}
local STUB_NAMES = {"StubAudioModule", "StubDocumentPickerModule", "StubHapticsModule", "StubImagePickerModule", "StubSharingModule", "StubSplashScreenModule", "StubClipboardModule", "StubFileSystemModule", "StubFontLoaderModule", "StubFontUtilsModule", "StubTwoWayAudioModule", "StubHardwareKeyboardModule", "StubBackgroundNotificationTasksModule", "StubBadgeModule", "StubCameraModule", "StubImageManipulatorModule", "StubNotificationCategoriesModule", "StubNotificationPermissionsModule", "StubNotificationPresenterModule", "StubNotificationSchedulerModule", "StubNotificationsEmitterModule", "StubNotificationsHandlerModule", "StubPushTokenManagerModule", "StubSQLiteModule", "StubServerRegistrationModule"}

if is_plat("iphoneos") then

target("expo-jsi-probe")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
    set_default(false)
    set_values("swift.module", "ExpoModulesJSI")
    add_packages("swift-runtime", "libcxx")
    add_packages("folly")
    local rn = react_native()
    local rc = path.join(rn, "ReactCommon")
    local pkg = path.join(os.projectdir(), "build", "ref", "paseo", "node_modules", "expo-modules-jsi", "apple")
    local src = path.join(pkg, "Sources")
    local modmap = path.join(os.projectdir(), "build", "expo-jsi", "module.modulemap")
    add_files(path.join(src, "ExpoModulesJSI", "**.swift"))
    add_files(path.join(SOURCES, "expo", "JSIUtils.cpp"))
    add_files(path.join(src, "ExpoModulesJSI-Cxx", "TypedArray.cpp"))
    local swinc = {}
    local incs = {rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), path.join(rc, "react", "renderer", "debug"), path.join(rc, "react", "timing"), path.join(rc, "react", "debug"), path.join(rc, "react", "performance", "timeline"), path.join(src, "ExpoModulesJSI-Cxx", "include"), path.join(src, "ExpoModulesJSI-Cxx", "include", "Public")}
    for _, d in ipairs(os.dirs(path.join(package_store(), "s", "swift", "*", "*", "include"))) do table.insert(swinc, d) end
    add_includedirs(incs)
    add_includedirs(swinc)
    local flags = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1"}
    add_cxxflags(flags, {force = true})
    local sw = {"-swift-version", "6", "-cxx-interoperability-mode=default", "@" .. path.join(os.projectdir(), "build", "expo-jsi", "features.rsp"), "-Xcc", "-fmodule-map-file=" .. modmap}
    for _, d in ipairs(incs) do
        table.insert(sw, "-Xcc")
        table.insert(sw, "-I" .. d)
    end
    local pkg_apinotes = path.join(pkg, "APINotes")
    local hdrrsp = path.join(os.projectdir(), "build", "expo-jsi", "libcxx.rsp")
    table.insert(sw, "@" .. hdrrsp)
    on_config(function (target)
        local libcxx = target:pkg("libcxx")
        local rt = target:pkg("swift-runtime")
        if libcxx and rt then
            local exec = table.wrap((rt:envs() or {}).SWIFT_EXEC)[1]
            local lines = {"-Xcc", "-isystem", "-Xcc", path.join(libcxx:installdir(), "include", "c++", "v1")}
            if exec then
                table.join2(lines, {"-Xcc", "-I" .. path.join(path.directory(path.directory(exec)), "include")})
            end
            table.join2(lines, {"-Xcc", "-fapinotes-modules", "-Xcc", "-iapinotes-modules", "-Xcc", pkg_apinotes})
            io.writefile(hdrrsp, table.concat(lines, "\n") .. "\n")
        end
    end)
    add_values("swift.flags", table.unpack(sw))
    set_languages("c++20")

target("expo-core-probe")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
    set_default(false)
    set_values("swift.module", "ExpoModulesCore")
    add_deps("expo-jsi-probe")
    add_packages("swift-runtime", "libcxx", "combine", "cryptokit", "swiftui")
    add_packages("folly")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local core = path.join(nm, "expo-modules-core", "ios")
    add_files(path.join(core, "**.swift"))
    remove_files(path.join(core, "WorkletsTests", "**.swift"))
    remove_files(path.join(core, "Worklets", "**.swift"), path.join(core, "WorkletsAdapter", "**.swift"))
    local ecore = path.join(proj, "build", "expo-core")
    local rc = path.join(react_native(), "ReactCommon")
    local jsisrc = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local incs = {path.join(ecore, "include"), core, rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsisrc, path.join(jsisrc, "Public")}
    add_includedirs(incs)
    local xcc = {"-fmodule-map-file=" .. path.join(proj, "build", "expo-jsi", "module.modulemap"), "-fmodule-map-file=" .. path.join(ecore, "module.modulemap"), "-fmodule-map-file=" .. path.join(ecore, "react.modulemap")}
    for _, d in ipairs(incs) do
        table.insert(xcc, "-I" .. d)
    end
    local lines = {}
    for _, f in ipairs(xcc) do
        table.join2(lines, {"-Xcc", f})
    end
    local corersp = path.join(ecore, "flags.rsp")
    on_config(response_for_swift_cxx(lines, corersp))
    local sw = {"-swift-version", "6", "-cxx-interoperability-mode=default", "@" .. path.join(proj, "build", "expo-jsi", "features.rsp"),
                "@" .. path.join(proj, "build", "expo-jsi", "libcxx.rsp"), "@" .. corersp, "-import-underlying-module",
                "-emit-objc-header", "-emit-objc-header-path", path.join(ecore, "swift-header", "ExpoModulesCore", "ExpoModulesCore-Swift.h")}
    add_values("swift.flags", table.unpack(sw))
    set_languages("c++20")

target("expo-core-objc")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_deps("expo-core-probe")
    add_packages("libcxx")
    add_packages("folly", "socketrocket")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local core = path.join(nm, "expo-modules-core", "ios")
    local ecore = path.join(proj, "build", "expo-core")
    local rn = react_native()
    local rc = path.join(rn, "ReactCommon")
    local jsisrc = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    for _, f in ipairs(os.files(path.join(core, "**.m"))) do
        if not f:find("Tests", 1, true) and not f:find("Worklets", 1, true) then add_files(f) end
    end
    for _, f in ipairs(os.files(path.join(core, "**.mm"))) do
        if not f:find("Tests", 1, true) and not f:find("Worklets", 1, true) then add_files(f) end
    end
    for _, f in ipairs(os.files(path.join(core, "**.cpp"))) do
        if not f:find("Tests", 1, true) and not f:find("Worklets", 1, true) then add_files(f) end
    end
    local common = path.join(nm, "expo-modules-core", "common", "cpp")
    for _, f in ipairs(os.files(path.join(common, "**.cpp"))) do
        if path.filename(f) ~= "TypedArray.cpp" then add_files(f) end
    end
    add_includedirs(common, path.join(common, "fabric"), path.join(common, "JSI"))
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore")
    local jsiinclude = path.join(proj, "build", "expo-jsi", "include")
    local podinclude = path.join(proj, "build", "expo-pods")
    local POD_DIR_NAMES = {["expo-constants"] = "EXConstants"}
    on_load(function (target)
        local expo = modules()
        for _, package in ipairs(expo) do
            local only = EXPO_ONLY[package]
            local base = path.join(expo_dir(package), "ios", only or "")
            for _, f in ipairs(os.files(path.join(base, "**.m"))) do target:add("files", f) end
            for _, f in ipairs(os.files(path.join(base, "**.mm"))) do target:add("files", f) end
            target:add("includedirs", path.join(expo_dir(package), "ios"))
        end
    end)
    on_config(function (target)
        local expo = modules()
        os.mkdir(jsiinclude)
        os.tryrm(path.join(jsiinclude, "ExpoModulesJSI"))
        os.ln(path.join(jsisrc, "Public"), path.join(jsiinclude, "ExpoModulesJSI"))
        os.mkdir(podinclude)
        for _, package in ipairs(expo) do
            local ios = path.join(expo_dir(package), "ios")
            if not os.isdir(ios) then
                raise("%s is listed as a built Expo module in coverage.json, but %s has no ios folder", package, ios)
            end
            local pod = POD_DIR_NAMES[package]
            for _, spec in ipairs(os.files(path.join(ios, "*.podspec"))) do
                pod = pod or io.readfile(spec):match("s%.name%s*=%s*['\"]([%w_]+)['\"]")
            end
            if pod then
                local dir = path.join(podinclude, pod)
                os.tryrm(dir)
                os.mkdir(dir)
                for _, header in ipairs(os.files(path.join(ios, "**.h"))) do
                    local link = path.join(dir, path.filename(header))
                    if not os.exists(link) then os.ln(header, link) end
                end
            end
        end
    end)
    add_includedirs(jsiinclude, podinclude, path.join(ecore, "swift-header"), path.join(ecore, "swift-header", "ExpoModulesCore"))
    add_includedirs(react_native_headers())
    add_includedirs(path.join(rc, "yoga"), path.join(ecore, "include"), path.join(ecore, "include", "ExpoModulesCore"), core, jsisrc, path.join(jsisrc, "Public"), rc, path.join(rc, "jsi"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "jsitooling"), path.join(rc, "reactperflogger"), path.join(rc, "cxxreact"), path.join(rn, "React"), path.join(rn, "React", "Fabric"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    local flags = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DUSE_HERMES=0", "-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1"}
    add_cxxflags(flags, {force = true})
    add_mxxflags(flags, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    add_files(path.join(SOURCES, "expo", "RNHostClassName.m"), {mflags = {"-fobjc-arc"}})
    local classname = path.join(SOURCES, "expo", "RNHostClassName.h")
    add_mflags("-fobjc-arc", "-Wno-incompatible-pointer-types", "-DEXPO_MODULES_CORE_VERSION=57.0.23", "-include", classname, {force = true})
    add_mxxflags("-DEXPO_MODULES_CORE_VERSION=57.0.23", "-include", classname, {force = true})
    set_languages("gnu11", "c++20")

target("expo-app-modules")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
    set_default(false)
    set_values("swift.module", "ExpoAppModules")
    add_deps("expo-core-probe")
    add_packages("swift-runtime", "libcxx", "combine", "cryptokit", "swiftui", "uniformtypeidentifiers")
    add_packages("folly")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local ecore = path.join(proj, "build", "expo-core")
    local staged = path.join(proj, "build", "expo-src")
    add_files(path.join(SOURCES, "expo", "GlassView.swift"))
    add_files(path.join(SOURCES, "expo", "LocalizationModule.swift"))
    add_files(path.join(SOURCES, "expo", "StubModules.swift"))
    local provider = path.join(ecore, "ExpoModulesProvider.swift")
    add_files(provider, path.join(SOURCES, "expo", "InsecureMD5Shim.swift"))
    on_load(function (target)
        local expo, real = modules()
        local seen, duplicates = {}, {}
        for _, package in ipairs(expo) do
            for _, f in ipairs(os.files(path.join(expo_dir(package), "ios", EXPO_ONLY[package] or "", "**.swift"))) do
                local name = path.filename(f)
                if expo_skip(f) or LOCAL_COPIES[package] == name then
                elseif EXPO_REWRITE[name] and EXPO_REWRITE[name].package == package then
                    seen[name] = true
                    table.insert(duplicates, {f, path.join(staged, package .. "-" .. name), EXPO_REWRITE[name].replace})
                elseif seen[name] then
                    table.insert(duplicates, {f, path.join(staged, package .. "-" .. name)})
                else
                    seen[name] = true
                    target:add("files", f)
                end
            end
        end
        for _, pair in ipairs(duplicates) do
            local text = io.readfile(pair[1])
            for _, change in ipairs(pair[3] or {}) do
                text = text:gsub(change[1]:gsub("%p", "%%%0"), (change[2]:gsub("%%", "%%%%")))
            end
            io.writefile(pair[2], text)
            target:add("files", pair[2])
        end
        local macros = path.join(nm, "@expo", "expo-modules-macros-plugin", "apple", "ExpoModulesMacros-tool")
        local bridging = path.join(ecore, "bridging.h")
        local lines = {}
        for _, package in ipairs(expo) do
            for _, header in ipairs(os.files(path.join(expo_dir(package), "ios", EXPO_ONLY[package] or "", "**.h"))) do
                if os.isfile(header:gsub("%.h$", ".m")) or os.isfile(header:gsub("%.h$", ".mm")) then
                    table.insert(lines, "#import \"" .. header .. "\"")
                end
            end
        end
        io.writefile(bridging, "#import <Foundation/Foundation.h>\n" .. table.concat(lines, "\n") .. "\n")
        io.writefile(path.join(ecore, "implicit.rsp"), "-Xfrontend\n-import-module\n-Xfrontend\nFoundation\n-Xfrontend\n-import-module\n-Xfrontend\nUIKit\n-Xfrontend\n-import-module\n-Xfrontend\nCoreText\n-Xcc\n-I" .. path.join(proj, "build", "expo-pods") .. "\n-import-objc-header\n" .. bridging .. "\n-load-plugin-executable\n" .. macros .. "#ExpoModulesMacros\n")
        local classes = {}
        for _, package in ipairs(expo) do
            local config = io.readfile(path.join(expo_dir(package), "expo-module.config.json"))
            local apple = config:match('"apple"%s*:%s*{.-"modules"%s*:%s*%[(.-)%]')
            for name in (apple or ""):gmatch('"([^"]+)"') do
                if not EXPO_SKIP_MODULES[name] then
                    table.insert(classes, string.format("      (module: %s.self, name: nil),", name))
                end
            end
        end
        for _, name in ipairs(STUB_NAMES) do
            local owner = STUB_OWNERS[name]
            if not (owner and real[owner]) then
                table.insert(classes, string.format("      (module: %s.self, name: nil),", name))
            end
        end
        io.writefile(provider, table.concat({
            "import ExpoModulesCore",
            "",
            "@objc(ExpoModulesProvider)",
            "public final class ExpoModulesProvider: ModulesProvider {",
            "  public override func getModuleClasses() -> [ExpoModuleTupleType] {",
            "    return [",
            table.concat(classes, "\n"),
            "    ]",
            "  }",
            "",
            "  public override func getAppDelegateSubscribers() -> [ExpoAppDelegateSubscriber.Type] {",
            "    return []",
            "  }",
            "",
            "  public override func getReactDelegateHandlers() -> [ExpoReactDelegateHandlerTupleType] {",
            "    return []",
            "  }",
            "",
            "  public override func getAppCodeSignEntitlements() -> AppCodeSignEntitlements {",
            "    return AppCodeSignEntitlements.from(json: \"{}\")",
            "  }",
            "}",
            ""}, "\n"))
    end)
    local sw = {"-swift-version", "5", "-cxx-interoperability-mode=default", "@" .. path.join(proj, "build", "expo-jsi", "features.rsp"),
                "@" .. path.join(proj, "build", "expo-jsi", "libcxx.rsp"), "@" .. path.join(ecore, "flags.rsp"), "@" .. path.join(ecore, "implicit.rsp")}
    add_values("swift.flags", table.unpack(sw))
    set_languages("c++20")

target("nitro-objc")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_packages("libcxx")
    add_packages("folly", "socketrocket")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local nroot = path.join(nm, "react-native-nitro-modules")
    local rn = react_native()
    local rc = path.join(rn, "ReactCommon")
    for _, f in ipairs(os.files(path.join(nroot, "cpp", "**.cpp"))) do add_files(f) end
    for _, f in ipairs(os.files(path.join(nroot, "ios", "**.cpp"))) do add_files(f) end
    for _, f in ipairs(os.files(path.join(nroot, "ios", "**.mm"))) do add_files(f) end
    add_files(path.join(proj, "build", "codegen", "build", "generated", "ios", "ReactCodegen", "NitroModulesSpec", "NitroModulesSpec-generated.mm"))
    add_files(path.join(SOURCES, "nitro", "IteratorInstantiation.cpp"))
    local ncpp = path.join(nroot, "cpp")
    local core = path.join(nroot, "ios")
    add_includedirs(path.join(proj, "build", "lib-headers"), ncpp, core, path.join(proj, "build", "nitro"))
    for _, sub in ipairs({"core", "jsi", "utils", "registry", "templates", "threading", "views", "prototype", "platform", "entrypoint"}) do
        add_includedirs(path.join(ncpp, sub))
    end
    for _, sub in ipairs({"core", "utils", "platform", "threading", "turbomodule", "views"}) do
        add_includedirs(path.join(core, sub))
    end
    add_includedirs(react_native_headers())
    add_includedirs(rc, path.join(rc, "jsi"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "jsitooling"), path.join(rc, "reactperflogger"), path.join(rc, "cxxreact"), path.join(rn, "React"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), rn)
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    local gen = path.join(proj, "build", "codegen", "build", "generated", "ios")
    add_includedirs(gen, path.join(gen, "ReactCodegen"))
    add_frameworks("UIKit", "Foundation")
    local flags = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DUSE_HERMES=0", "-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1"}
    add_cxxflags(flags, {force = true})
    add_mxxflags(flags, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    set_languages("c++20")

target("nitro-probe")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
    set_default(false)
    set_values("swift.module", "NitroModules")
    add_packages("swift-runtime", "libcxx", "combine", "cryptokit", "swiftui")
    add_packages("folly")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local core = path.join(nm, "react-native-nitro-modules", "ios")
    add_files(path.join(core, "**.swift"))
    local ncpp = path.join(nm, "react-native-nitro-modules", "cpp")
    local ecore = path.join(proj, "build", "nitro")
    local rc = path.join(react_native(), "ReactCommon")
    local jsisrc = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local incs = {path.join(proj, "build", "lib-headers"), ncpp, path.join(ncpp, "core"), path.join(ncpp, "jsi"), path.join(ncpp, "utils"), path.join(ncpp, "registry"), path.join(ncpp, "templates"), path.join(ncpp, "threading"), path.join(ncpp, "views"), path.join(ncpp, "prototype"), path.join(ncpp, "platform"), core, path.join(core, "core"), path.join(core, "utils"), rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsisrc, path.join(jsisrc, "Public")}
    add_includedirs(incs)
    local xcc = {"-fmodule-map-file=" .. path.join(proj, "build", "expo-jsi", "module.modulemap"), "-fmodule-map-file=" .. path.join(ecore, "module.modulemap")}
    for _, d in ipairs(incs) do
        table.insert(xcc, "-I" .. d)
    end
    local lines = {}
    for _, f in ipairs(xcc) do
        table.join2(lines, {"-Xcc", f})
    end
    local corersp = path.join(ecore, "flags.rsp")
    on_config(response_for_swift_cxx(lines, corersp))
    local sw = {"-swift-version", "5", "-cxx-interoperability-mode=default",
                "@" .. path.join(proj, "build", "expo-jsi", "libcxx.rsp"), "@" .. corersp, "@" .. path.join(proj, "build", "nitro", "imports.rsp"), "-import-underlying-module"}
    add_values("swift.flags", table.unpack(sw))
    set_languages("c++20")

target("unistyles-objc")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios")
    set_default(false)
    add_deps("unistyles-probe")
    add_packages("libcxx", "swift-runtime")
    add_packages("folly", "socketrocket")
    on_config(function (target)
        local rt = target:pkg("swift-runtime")
        local exec = rt and table.wrap((rt:envs() or {}).SWIFT_EXEC)[1]
        if exec then
            local root = path.directory(path.directory(exec))
            for _, flag in ipairs({"-isystem" .. path.join(root, "lib", "swift"), "-isystem" .. path.join(root, "include")}) do
                target:add("cxxflags", flag, {force = true})
                target:add("mxxflags", flag, {force = true})
            end
        end
    end)
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local uroot = path.join(nm, "react-native-unistyles")
    local ugen = path.join(uroot, "nitrogen", "generated")
    local nroot = path.join(nm, "react-native-nitro-modules")
    local rn = react_native()
    local rc = path.join(rn, "ReactCommon")
    for _, f in ipairs(os.files(path.join(uroot, "cxx", "**.cpp"))) do add_files(f) end
    for _, f in ipairs(os.files(path.join(ugen, "shared", "c++", "**.cpp"))) do add_files(f) end
    add_files(path.join(ugen, "ios", "c++", "HybridNativePlatformSpecSwift.cpp"), path.join(ugen, "ios", "Unistyles-Swift-Cxx-Bridge.cpp"), path.join(uroot, "ios", "UnistylesModuleOnLoad.mm"), path.join(proj, "build", "codegen", "build", "generated", "ios", "ReactCodegen", "TurboUnistyles", "TurboUnistyles-generated.mm"))
    add_includedirs(path.join(proj, "build", "unistyles", "swift-header"), path.join(ugen, "ios"), path.join(ugen, "ios", "c++"), path.join(ugen, "shared", "c++"), path.join(uroot, "ios"), path.join(uroot, "cxx"), path.join(proj, "build", "lib-headers"))
    for _, dir in ipairs(os.dirs(path.join(uroot, "cxx", "**"))) do add_includedirs(dir) end
    local ncpp = path.join(nroot, "cpp")
    add_includedirs(ncpp, path.join(nroot, "ios"))
    for _, sub in ipairs({"core", "jsi", "utils", "registry", "templates", "threading", "views", "prototype", "platform", "entrypoint"}) do
        add_includedirs(path.join(ncpp, sub))
    end
    for _, sub in ipairs({"core", "utils", "platform", "threading", "views"}) do
        add_includedirs(path.join(nroot, "ios", sub))
    end
    add_includedirs(react_native_headers())
    local gen = path.join(proj, "build", "codegen", "build", "generated", "ios")
    add_includedirs(gen, path.join(gen, "ReactCodegen"), path.join(rc, "yoga"), rc, path.join(rc, "jsi"), path.join(rc, "callinvoker"), path.join(rc, "runtimeexecutor"), path.join(rc, "jsitooling"), path.join(rc, "reactperflogger"), path.join(rc, "cxxreact"), path.join(rn, "React"), path.join(rn, "React", "Fabric"), path.join(rn, "Libraries"), path.join(rn, "ReactApple"), rn)
    for _, dir in ipairs(os.dirs(path.join(rn, "React", "Fabric", "**"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "ios"))) do add_includedirs(dir) end
    for _, dir in ipairs(os.dirs(path.join(rc, "**", "platform", "cxx"))) do add_includedirs(dir) end
    add_frameworks("UIKit", "Foundation", "QuartzCore")
    local flags = {"-faligned-allocation", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1", "-DUSE_HERMES=0", "-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1"}
    add_cxxflags(flags, {force = true})
    add_mxxflags(flags, {force = true})
    add_mxxflags("-fobjc-arc", {force = true})
    set_languages("c++20")

target("unistyles-probe")
    set_kind("static")
    add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
    set_default(false)
    set_values("swift.module", "Unistyles")
    add_deps("nitro-probe")
    add_packages("swift-runtime", "libcxx", "combine", "cryptokit", "swiftui")
    add_packages("folly")
    local proj = os.projectdir()
    local nm = path.join(proj, "build", "ref", "paseo", "node_modules")
    local core = path.join(nm, "react-native-unistyles", "ios")
    add_files(path.join(core, "**.swift"), path.join(nm, "react-native-unistyles", "nitrogen", "generated", "ios", "swift", "**.swift"))
    local ncpp = path.join(nm, "react-native-nitro-modules", "cpp")
    local ecore = path.join(proj, "build", "unistyles")
    local nitromap = path.join(proj, "build", "nitro", "module.modulemap")
    local ugen = path.join(nm, "react-native-unistyles", "nitrogen", "generated", "ios")
    local rc = path.join(react_native(), "ReactCommon")
    local jsisrc = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
    local incs = {path.join(proj, "build", "unistyles", "stub"), ugen, path.join(ugen, "c++"), path.join(ugen, "..", "shared", "c++"), path.join(nm, "react-native-unistyles", "cxx"), path.join(proj, "build", "lib-headers"), ncpp, path.join(ncpp, "core"), path.join(ncpp, "jsi"), path.join(ncpp, "utils"), path.join(ncpp, "registry"), path.join(ncpp, "templates"), path.join(ncpp, "threading"), path.join(ncpp, "views"), path.join(ncpp, "prototype"), path.join(ncpp, "platform"), core, path.join(core, "core"), path.join(core, "utils"), path.join(nm, "react-native-nitro-modules", "ios"), path.join(nm, "react-native-nitro-modules", "ios", "core"), path.join(nm, "react-native-nitro-modules", "ios", "utils"), path.join(nm, "react-native-nitro-modules", "ios", "platform"), path.join(nm, "react-native-nitro-modules", "ios", "threading"), rc, path.join(rc, "jsi"), path.join(rc, "runtimeexecutor"), path.join(rc, "callinvoker"), jsisrc, path.join(jsisrc, "Public")}
    add_includedirs(incs)
    local xcc = {"-fmodule-map-file=" .. nitromap, "-fmodule-map-file=" .. path.join(proj, "build", "expo-core", "react.modulemap"), "-I" .. react_native_headers(), "-fmodule-map-file=" .. path.join(proj, "build", "expo-jsi", "module.modulemap"), "-fmodule-map-file=" .. path.join(ecore, "module.modulemap")}
    for _, d in ipairs(incs) do
        table.insert(xcc, "-I" .. d)
    end
    local lines = {}
    for _, f in ipairs(xcc) do
        table.join2(lines, {"-Xcc", f})
    end
    local corersp = path.join(ecore, "flags.rsp")
    on_config(response_for_swift_cxx(lines, corersp))
    local sw = {"-swift-version", "5", "-cxx-interoperability-mode=default",
                "@" .. path.join(proj, "build", "expo-jsi", "libcxx.rsp"), "@" .. corersp, "-import-underlying-module",
                "-emit-clang-header-path", path.join(ecore, "swift-header", "Unistyles-Swift.h")}
    add_values("swift.flags", table.unpack(sw))
    set_languages("c++20")

end

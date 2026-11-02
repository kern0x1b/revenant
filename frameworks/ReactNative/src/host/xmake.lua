local here = os.scriptdir()

option("rn-bundle")
    set_showmenu(true)
    set_description("Metro bundle (.js) to copy into the app; default is the committed test bundle")
    set_default(path.join(here, "test-bundle.js"))
option_end()

local RN_JSC_FRAMEWORK = (not os.getenv("RN_LINK_ALL")) and (not os.getenv("RN_JSC_BUNDLE")) and (not os.getenv("RN_WEBKIT")) and "JavaScriptCore" or nil
local RN_SOURCE = os.getenv("RN_SRC") or path.join(os.projectdir(), "build", "ref", "paseo", "node_modules", "react-native")
if os.getenv("RN_HERMES") then
    add_requires("revenant@hermes", {alias = "hermes"})
end

target("RNHost")
    add_rules("@addon/revenant/app")
    add_packages("libcxx")
    add_deps("rn-jsc", "rn-yoga")
    if os.getenv("RN_HERMES") then
        add_packages("hermes")
        local rc = path.join(RN_SOURCE, "ReactCommon")
        add_includedirs(rc, path.join(rc, "react", "runtime", "platform", "ios", "ReactCommon"))
        add_files(path.join(rc, "react", "runtime", "hermes", "HermesInstance.cpp"),
            path.join(rc, "react", "runtime", "platform", "ios", "ReactCommon", "RCTHermesInstance.mm"))
        for _, f in ipairs(os.files(path.join(rc, "hermes", "inspector-modern", "chrome", "*.cpp"))) do
            if not f:find("/tests/", 1, true) then add_files(f) end
        end
        add_cxxflags("-DRN_HERMES=1", {force = true})
        add_mxxflags("-DRN_HERMES=1", {force = true})
    end
    if os.getenv("RN_WEBKIT") then
        add_packages("webkit-engine-prefixed")
        add_ldflags("-Wl,-rpath,@executable_path/Frameworks", {force = true})
        on_config(function (target)
            local engine = target:pkg("webkit-engine-prefixed"):installdir()
            local linkdir = path.join(target:autogendir(), "jsc-link")
            os.mkdir(linkdir)
            os.tryrm(path.join(linkdir, "libJavaScriptCore.dylib"))
            os.ln(path.join(engine, "bundle", "Frameworks", "JavaScriptCore.framework", "JavaScriptCore"), path.join(linkdir, "libJavaScriptCore.dylib"))
            target:add("linkdirs", linkdir)
            target:add("links", "JavaScriptCore", {force = true})
        end)
    end
    if os.getenv("RN_JSC_BUNDLE") then
        add_ldflags("-Wl,-rpath,@executable_path/Frameworks", {force = true})
        add_ldflags(path.join(os.getenv("RN_JSC_BUNDLE"), "Frameworks", "JavaScriptCore.framework", "JavaScriptCore"), {force = true})
        add_values("app.resources", path.relative(os.getenv("RN_JSC_BUNDLE"), here))
    end
    if os.getenv("RN_JSC_ENGINE") then
        add_packages("rn-jsc-engine")
        add_ldflags("-Wl,-rpath,@executable_path/Frameworks", {force = true})
        on_load(function (target)
            local engine = target:pkg("rn-jsc-engine"):installdir()
            target:add("ldflags", path.join(engine, "bundle", "Frameworks", "JavaScriptCore.framework", "JavaScriptCore"), {force = true})
        end)
    end
    if os.getenv("RN_LINK_ALL") then
        if os.getenv("RN_BACKPORTS") then
            add_packages("backports")
        end
        add_deps("rn-core", "rn-appdelegate")
        if os.getenv("RN_WEBKIT_BACKPORTS") then
            add_ldflags(os.getenv("RN_WEBKIT_BACKPORTS"), {force = true})
        end
        if os.getenv("RN_EXPO") then
            add_deps("expo-core-objc", "expo-app-modules", "nitro-objc", "nitro-probe", "unistyles-objc", "unistyles-probe", "rn-pods-objc")
            add_packages("swift-runtime", "combine", "cryptokit", "swiftui", "uniformtypeidentifiers")
            local ecore = path.join(os.projectdir(), "build", "expo-core")
            local nm = path.join(os.projectdir(), "build", "ref", "paseo", "node_modules")
            local jsisrc = path.join(nm, "expo-modules-jsi", "apple", "Sources", "ExpoModulesJSI-Cxx", "include")
            add_includedirs(path.join(ecore, "include"), path.join(ecore, "include", "ExpoModulesCore"), path.join(nm, "expo-modules-core", "ios"), jsisrc, path.join(jsisrc, "Public"))
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
            add_cxxflags("-DRN_EXPO=1", {force = true})
            add_mxxflags("-DRN_EXPO=1", {force = true})
        end
        local rn = RN_SOURCE
        local generated = path.join(os.projectdir(), "build", "codegen", "build", "generated", "ios")
        if os.getenv("RN_HEADERS") then
            add_includedirs(os.getenv("RN_HEADERS"))
        end
        add_includedirs(path.join(rn, "Libraries", "AppDelegate"), path.join(generated, "ReactAppDependencyProvider"), generated,
            path.join(rn, "ReactCommon"), path.join(rn, "ReactCommon", "jsitooling"), path.join(rn, "ReactCommon", "jsi"),
            path.join(rn, "ReactCommon", "callinvoker"), path.join(rn, "ReactCommon", "runtimeexecutor"), path.join(rn, "ReactCommon", "react", "runtime", "platform", "ios"), path.join(rn, "React"), path.join(rn, "ReactCommon", "cxxreact"))
        for _, dir in ipairs(os.dirs(path.join(rn, "ReactCommon", "**", "platform", "ios"))) do add_includedirs(dir) end
        for _, dir in ipairs(os.dirs(path.join(rn, "ReactCommon", "**", "platform", "cxx"))) do add_includedirs(dir) end
        add_cxxflags("-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1", "-faligned-allocation", {force = true})
        add_mxxflags("-DUSE_THIRD_PARTY_JSC=1", "-DRCT_NEW_ARCH_ENABLED=1", "-faligned-allocation", {force = true})
        add_packages("folly", "socketrocket")
        add_ldflags("-Wl,-all_load", {force = true})
    end
    add_files("main.m", "RNHostAppDelegate.mm", "RNHostViewController.mm", "RNHostRuntime.mm", "RNHostHostFunctions.mm", "RNHostYoga.mm", "RNHostFoundationShim.m", "RNHostTouch.m")
    add_frameworks("UIKit", "Foundation", "CoreGraphics")
    if RN_JSC_FRAMEWORK then
        add_frameworks(RN_JSC_FRAMEWORK)
    end
    add_mflags("-fobjc-arc", {force = true})
    add_mxflags("-fobjc-arc", {force = true})
    set_languages("c++20")
    set_optimize("fastest")
    local app_assets = os.getenv("RN_APP_ASSETS")
    set_values("app.plist-file", app_assets and path.relative(path.join(app_assets, "Info.plist"), os.scriptdir()) or "Info.plist")
    set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.paseo-ios6.rnhost")
    if not app_assets then
        add_values("app.plist", "CFBundleDisplayName=RNHost")
    else
        for _, file in ipairs(os.files(path.join(app_assets, "*.png"))) do
            add_values("app.resources", path.relative(file, os.scriptdir()))
        end
    end
    add_values("app.resources", path.relative(get_config("rn-bundle"), os.scriptdir()))
    set_values("app.frameworks", "libcxx")
    if os.getenv("RN_WEBKIT") then
        add_values("app.frameworks", "webkit-engine-prefixed")
    end
    if os.getenv("RN_JSC_ENGINE") then
        add_values("app.frameworks", "rn-jsc-engine")
    end
    if os.getenv("RN_EXPO") then
        add_rules("@addon/revenant/swift")
        add_values("app.frameworks", "cryptokit", "uniformtypeidentifiers")
        set_values("revenant.waive.thumb-interworking", "libswiftDarwin.dylib is checked a second time after it was stripped, because the runtime libraries reach the app both through swift-runtime and through the cryptokit package; the unstripped copies pass the check")
    end
    set_values("revenant.control", path.join(os.projectdir(), "packaging", "control-rnhost"))
    if os.getenv("RN_BACKPORTS") then
        set_values("revenant.rebind", "RNHost")
    end
    set_values("revenant.waive.weak-imports", "UIAccessibilityPriority*, UIAccessibilitySpeechAttributeAnnouncementPriority: RCTAccessibilityManager.mm:335 inside @available(iOS 17.0); UITextContentType{Birthdate*,CreditCard*}: RCTTextInputUtils.mm:228 and RCTBaseTextInputView.mm:316 inside @available(iOS 17.0); UITextContentType{DateTime,FlightNumber,ShipmentTrackingNumber}: same files inside @available(iOS 15.0); UITextContentTypeCellular*: same files inside @available(iOS 17.4); UIMenuAutoFill: RCTUITextField.mm:189 and RCTUITextView.mm:318 inside @available(iOS 17.0); preadv, pwritev: folly SysUio.cpp takes the address only inside __builtin_available(iOS 14.0) and otherwise uses preadv_fallback/pwritev_fallback; UIContentSizeCategoryDidChangeNotification, UIContentSizeCategoryNewValueKey, UIApplicationLaunchOptionsUserActivityDictionaryKey, UIApplicationLaunchOptionsUserActivityTypeKey: each use is behind an address-of != NULL test added by rn-spike/patches/ios6-weak-guards.patch")
    set_values("revenant.version", "0.1.0")

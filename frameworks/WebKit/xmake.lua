option("webkit_host_tests", {default = false, showmenu = true,
                             description = "Build ICU for this Mac and the WebKit port's host tests of its data, run with ./xmakew test -P . icu-sanity/* icu-locales/*."})

if get_config("component") ~= "" then
    return
end

includes("src/device-tools")

local stubs = path.join(os.scriptdir(), "src", "compat", "stubs")
local version = "0.1.0"

if is_plat("iphoneos") then
    add_requires("webkit-engine", {alias = "webkit-engine"})
    add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}})
    add_requires("webkit-device-tools")
    add_requires("revenant@wasm3", {alias = "wasm3"})
    add_requires("revenant@openssl", {alias = "openssl"})
    add_requires("revenant@openssl-host 4.0.2", {alias = "openssl-host", host = true})

    add_cxflags("-mcpu=cortex-a9", "-mfpu=neon")
    add_defines("WEBKIT_IOS6_NO_READLINE")

    local function packaged(target)
        target:set("values", "revenant.version", version)
        target:set("values", "revenant.control", "src/packaging/control")
        target:set("values", "revenant.maintainer-scripts", "src/packaging/DEBIAN")
        target:set("values", "revenant.licenses", "LICENSE", "../../docs/reference/webkit/third-party.md")
    end

    target("RevSafari")
        add_rules("@addon/revenant/tweak")
        add_files("src/platform/safari/rev-safari-tweak.c")
        add_cflags("-Wall")
        set_optimize("faster")
        add_frameworks("CoreFoundation")
        add_packages("webkit-engine")
        set_values("tweak.filter", "src/platform/safari/rev-safari.plist")
        on_load(packaged)
        on_config(function (target)
            target:add("installfiles", path.join(target:pkg("webkit-engine"):installdir(), "stage", "(**)"), {prefixdir = "/"})
        end)

    target("rev-safari-compat")
        add_rules("@addon/revenant/tweak")
        set_values("revenant.install", "/usr/lib")
        add_files("src/platform/safari/safari-compat.mm", "src/platform/safari/RevWasm.m")
        add_packages("wasm3")
        add_mflags("-Wall", "-fno-objc-arc", "-Wno-deprecated-declarations", "-Wno-unused")
        add_mxxflags("-Wall", "-fno-objc-arc", "-Wno-deprecated-declarations", "-Wno-unused")
        add_cxflags("-U_FORTIFY_SOURCE", "-D_FORTIFY_SOURCE=0")
        set_optimize("faster")
        add_shflags("-nostdlib++")
        add_frameworks("Foundation", "CoreFoundation")
        add_syslinks("objc", "sqlite3")
        on_load(packaged)

    target("rev-TLS")
        add_rules("@addon/revenant/tweak")
        set_values("revenant.install", "/usr/lib")
        add_files("src/platform/safari/tls-openssl.c")
        add_packages("openssl")
        add_cflags("-Wall")
        set_optimize("faster")
        add_frameworks("CoreFoundation", "Security")
        on_load(packaged)

    target("RevPrefs")
        add_rules("@addon/revenant/tweak")
        set_values("revenant.install", "/Library/PreferenceBundles/RevPrefs.bundle")
        add_files("src/platform/prefs/RevRootListController.m", "src/platform/prefs/RevAppsListController.m")
        add_includedirs("src/platform/prefs")
        add_mflags("-Wall", "-fno-objc-arc", "-Wno-deprecated-declarations", "-Wno-unused")
        set_optimize("smallest")
        add_frameworks("Foundation", "CoreFoundation", "UIKit")
        add_syslinks("objc")
        add_installfiles("src/platform/prefs/Resources/(*)", {prefixdir = "/Library/PreferenceBundles/RevPrefs.bundle"})
        add_installfiles("src/platform/prefs/entry.plist", {prefixdir = "/Library/PreferenceLoader/Preferences", filename = "RevWebKit.plist"})
        on_load(function (target)
            packaged(target)
            target:set("extension", "")
            target:set("shflags", "-install_name", "/Library/PreferenceBundles/RevPrefs.bundle/RevPrefs", {force = true})
            target:add("shflags", "-undefined", "dynamic_lookup", "-flat_namespace", {force = true})
        end)

    -- The packages the org.revenant.webkit-engine deb is written from, and nothing to compile: the
    -- packaging step builds this target to install them, and reads the prefixed engine from it.
    target("WebKitEngine")
        set_kind("phony")
        set_default(false)
        add_packages("webkit-engine-prefixed", "libcxx")

    target("RevWebViewHost")
        add_rules("@addon/revenant/app")
        set_default(false)
        add_files("examples/webview-host/rev-webview-host.m", "examples/webview-host/ModernTLSURLProtocol.m", "examples/webview-host/WebKitUIKitDelegate.m")
        add_packages("webkit-engine-prefixed", "openssl", "libcxx")
        add_mflags("-g", "-fno-objc-arc", "-include", path.join(stubs, "ios6_class_prefix.h"))
        add_ldflags("-Wl,-dead_strip", "-Wl,-rpath,@executable_path/Frameworks", {force = true})
        add_frameworks("WebKitLegacy", "UIKit", "Foundation", "QuartzCore", "CoreGraphics", "ImageIO", "MobileCoreServices")
        add_syslinks("z")
        set_values("revenant.entitlements", "examples/webview-host/entitlements.xml")
        set_values("app.plist-file", "examples/webview-host/Info.plist")
        set_values("app.url-scheme", "revwebviewhost")
        set_values("app.frameworks", "libcxx")
        add_values("app.resources", "examples/webview-host/cacert.pem", "examples/webview-host/start.html")
        on_config(function (target)
            local engine = target:pkg("webkit-engine-prefixed"):installdir()
            target:add("frameworkdirs", path.join(engine, "frameworks"))
            target:add("sysincludedirs", path.join(engine, "webcore", "PrivateHeaders"))
            target:add("values", "app.resources", path.relative(path.join(engine, "bundle"), target:scriptdir()))
        end)
elseif has_config("webkit_host_tests") then
    add_requires("revenant@icu", {alias = "icu"})

    target("icu-sanity")
        set_kind("binary")
        set_default(false)
        set_languages("c++17")
        add_files("tests/host/icu-sanity.cpp")
        add_packages("icu")
        add_tests("encodings", {runargs = {path.join(os.scriptdir(), "tests", "host", "required-encodings.txt"),
                                           path.join(os.scriptdir(), "tests", "host", "known-missing-encodings.txt")}})

    target("icu-locales")
        set_kind("binary")
        set_default(false)
        set_languages("c++17")
        add_files("tests/host/icu-locales.cpp")
        add_packages("icu")
        add_tests("locales")
end

target("webkit-cacert")
    add_rules("@addon/revenant/check")
    set_values("check.command", "./xmakew", "l", "frameworks/WebKit/tools/check_cacert.lua")
    set_values("check.files", "frameworks/WebKit/examples/webview-host/cacert.pem", "frameworks/WebKit/tools/check_cacert.lua")

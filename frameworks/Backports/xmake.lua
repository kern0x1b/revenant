option("backports_min_ios", {default = "6.0", showmenu = true,
    description = "The oldest iOS a build supports: the backports hold every member introduced after it, and every member of a framework absent at it."})

if get_config("component") == "Swift" then
    includes("src/Swift")
    return
end

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.absolute(path.join(os.scriptdir(), "tools"))
local TESTS = path.absolute(path.join(os.scriptdir(), "tests"))
local SKELETON = path.join(ROOT, "build", "generated", "backports", "skeleton")
local INSTALL_FOLDER = "/usr/lib/revenant/org.revenant.backports"
local SRC = path.absolute(path.join(os.scriptdir(), "src"))

local SELECTED = os.getenv("REVENANT_BACKPORTS_LIBRARIES")
SELECTED = SELECTED ~= "" and SELECTED or nil
includes("tools/library_list.lua")
includes("tools/subset.lua")
local LIBRARIES = backports_subset(backports_libraries(), SELECTED)

if is_plat("iphoneos") then
    for _, package in ipairs(backports_requires(LIBRARIES)) do
        add_requires(package.requirement, {alias = package.name, configs = package.configs})
    end
end

if is_plat("iphoneos") then
    local generator

    local FLAGS = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    local OBJC_FLAGS = table.join(FLAGS, {"-fobjc-arc", "-Werror=objc-missing-property-synthesis", "-fmacro-prefix-map=" .. ROOT .. "/="})
    local function open_gap(name, cause)
        before_build(function (target)
            local toolchain = target:toolchain("apple-ios")
            toolchain:load()
            raise("%s is not yet backported to iOS %s: %s; see the open gaps in frameworks/Backports/README.md", name,
                toolchain:config("deployment"), cause)
        end)
    end

    local CODING = path.join(SRC, "Intents", "coding")
    local WEBAUTH = path.join(SRC, "CloudKit", "webauth")
    local TWEAK = path.join(SRC, "CallKit", "tweak")

    target("RevenantCoding")
        set_kind("static")
        add_rules("@addon/revenant/apple-ios")
        set_optimize("smallest")
        add_cflags("-Os", "-fvisibility=hidden")
        add_mflags("-fobjc-arc")
        add_files(path.join(CODING, "*.m"))
        add_headerfiles(path.join(CODING, "*.h"))
        add_includedirs(CODING, {public = true})

    if backports_uses(LIBRARIES, "RevenantCKWebAuth") then
        target("RevenantCKWebAuth")
            set_kind("static")
            add_rules("@addon/revenant/apple-ios")
            set_optimize("smallest")
            add_cflags("-Os", "-fvisibility=hidden", "-fno-strict-aliasing")
            add_files(path.join(WEBAUTH, "RevenantCKWebAuth.c"))
            add_headerfiles(path.join(WEBAUTH, "RevenantCKWebAuth.h"))
            add_includedirs(WEBAUTH, {public = true})
            add_packages("micro-ecc", {public = true})
    end

    target("revenant-callkit-screen")
        set_default(false)
        add_rules("@addon/revenant/tweak")
        add_files(path.join(TWEAK, "RevenantCallScreenTweak.m"))
        add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
        set_values("tweak.filter", path.join(TWEAK, "springboard.plist"))
        set_values("revenant.control", path.join(TWEAK, "control"))
        set_values("revenant.version", "1.0.0")

    local ALTICON = path.join(SRC, "UIKit", "tweak")

    target("revenant-alticon")
        set_default(false)
        add_rules("@addon/revenant/tweak")
        add_files(path.join(ALTICON, "RevenantAlternateIconTweak.m"))
        add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
        set_values("tweak.filter", path.join(ALTICON, "springboard.plist"))
        set_values("revenant.control", path.join(ALTICON, "control"))
        set_values("revenant.version", "1.0.0")

    for _, library in ipairs(LIBRARIES) do
        target(library.name)
            set_kind("shared")
            add_rules("@addon/revenant/apple-ios")
            if library.gap then
                open_gap(table.unpack(library.gap))
            end
            set_optimize("smallest")
            set_symbols("none")
            add_cflags(table.join(FLAGS, {"-fvisibility=hidden", "-fmacro-prefix-map=" .. ROOT .. "/="}))
            add_mflags(OBJC_FLAGS)
            add_mxxflags(table.join(OBJC_FLAGS, {"-fno-rtti", "-fvisibility-inlines-hidden"}))
            if library.folder == "Vision" then
                add_cxxflags("-std=c++20", "-fvisibility-inlines-hidden")
            end
            if library.name == "MLComputeBackports" then
                add_files(path.join(SRC, "MLCompute", "ggml", "ggml-libcxx.cpp"))
                add_cxxflags("-std=c++17", "-fno-exceptions", "-fno-rtti", "-fvisibility=hidden", "-fvisibility-inlines-hidden")
            end
            add_shflags("-install_name", INSTALL_FOLDER .. "/lib" .. library.name .. ".dylib", "-Wno-incompatible-sysroot",
                        "-Wl,-no_encryption", "-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__port_catlist", {force = true})
            if library.name == "NetworkBackports" then
                add_shflags("-Wl,-current_version,1", "-Wl,-compatibility_version,1", {force = true})
            end
            add_syslinks("objc")
            if library.folder ~= "Vision" and (#os.files(path.join(SRC, library.folder, "*.mm")) > 0 or #os.files(path.join(SRC, library.folder, "*.cpp")) > 0) then
                add_syslinks("c++")
            end
            add_files(table.join(os.files(path.join(SRC, library.folder, "*.m")), os.files(path.join(SRC, library.folder, "*.mm")),
                                 os.files(path.join(SRC, library.folder, "*.cpp")), os.files(path.join(SRC, library.folder, "*.c")), {path.join(SRC, "attach.c")}))
            if library.name == "NetworkBackports" then
                after_build(function (target)
                    local stub = import("network_stub", {rootdir = path.join(os.scriptdir(), "src", "Swift"), anonymous = true}).stub()
                    local exported = os.iorunv("nm", {"-gU", target:targetfile()})
                    for _, symbol in ipairs(stub.symbols) do
                        if not exported:find(" " .. symbol .. "\n", 1, true) then
                            raise("%s does not export %s, so the link stub generated for swiftNetwork would not resolve it", target:targetfile(), symbol)
                        end
                    end
                end)
            end
            if library.name == "PhotosBackports" then
                after_build(function (target)
                    local load = os.iorunv("otool", {"-l", target:targetfile()})
                    if not load:find("LC_LOAD_WEAK_DYLIB%s+cmdsize %d+%s+name [^%s]*PhotosUI%.framework/PhotosUI") then
                        raise("%s must weak-link PhotosUI, which an iOS 6 device does not have, so a strong link would stop the app from launching", target:targetfile())
                    end
                end)
            end
            for _, name in ipairs(library.libraries) do
                if name:endswith("Backports") then
                    add_deps(name)
                else
                    add_syslinks(name)
                end
            end
            for _, framework in ipairs(library.frameworks) do
                add_shflags("-Wl,-weak_framework," .. framework, {force = true})
            end
            for _, name in ipairs(library.archives) do
                if backports_is_target(name) then
                    add_deps(name)
                else
                    add_packages(name)
                end
            end
            for _, name in ipairs(library.system) do
                add_syslinks(name)
            end
            on_load(function (target)
                generator = import("generate", {rootdir = TOOLS, anonymous = true})
            end)
            on_config(function (target)
                generator.skeleton_for(library.folder)
                local files = {}
                for _, file in ipairs({path.join(SKELETON, library.folder .. ".m"), path.join(SKELETON, library.folder .. ".c")}) do
                    if os.isfile(file) then
                        table.insert(files, file)
                    end
                end
                if #files > 0 then
                    table.insert(files, path.join(SKELETON, "registrar.m"))
                    target:add("files", table.unpack(files))
                end
            end)
            if library.name == "NetworkBackports" then
                before_build(function (target)
                    local boringssl = target:pkg("boringssl")
                    if not boringssl then
                        local names = {}
                        for _, pkg in pairs(target:pkgs() or {}) do
                            table.insert(names, tostring(pkg:name()))
                        end
                        raise("NetworkBackports has no boringssl package attached (pkgs: %s, requires: %s)", table.concat(names, ","),
                              table.concat(table.wrap(target:get("packages")), ","))
                    end
                    target:add("cflags", "-I" .. boringssl:installdir() .. "/include")
                end)
            end
    end
end

if not is_plat("iphoneos") and is_arch("arm64", "x86_64") then
    add_requires("revenant@zxing-cpp v3.1.1", {alias = "zxing-cpp"})
    add_requires("revenant@tesseract 5.5.3", {alias = "tesseract"})
    add_requires("revenant@leptonica 1.85.0", {alias = "leptonica"})
    add_requires("revenant@tessdata", {alias = "tessdata", configs = {languages = "all"}})
end

local function backports_tests(name, scripts)
    target(name)
        set_kind("phony")
        set_default(false)
        for suite in pairs(scripts) do
            add_tests(suite)
        end
        on_test(function (target, opt)
            local ok = os.execv(os.programfile(), {"l", "-P", ROOT, path.join(TESTS, scripts[path.filename(opt.name)])}, {try = true, curdir = ROOT})
            if ok ~= 0 then
                opt.errors = path.filename(opt.name) .. " failed"
            end
            return ok == 0
        end)
    target_end()
end

if is_plat("iphoneos") then
    backports_tests("subset", {subset = "subset_test.lua"})
end

if is_plat("iphoneos") and not SELECTED then
    target("BackportsLayoutProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/app")
        add_files("tests/layout/main.m", "src/AVFoundation/AVCaptureMetadataOutput+RectOfInterest7.m", "src/AVFoundation/AVCaptureVideoPreviewLayer+MetadataRect7.m",
                  "src/UIKit/UIViewController+ExtendedLayout.m")
        add_mflags("-fobjc-arc")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "AVFoundation")
        set_values("app.plist-file", "tests/layout/Info.plist")
        set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.backports.layout", "CFBundleDisplayName=BackportsLayoutProbe")
        set_values("revenant.control", "tests/layout/control")
        set_values("revenant.version", "1.0.0")
    target_end()

    target("BackportsQRMetadataProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/app")
        add_files("tests/qr_metadata/main.m", "src/AVFoundation/AVCaptureMetadataOutput+MachineReadableCode7.m",
                  "src/AVFoundation/AVCaptureMetadataOutput+RectOfInterest7.m", "src/AVFoundation/AVCaptureVideoPreviewLayer+MetadataRect7.m",
                  "src/AVFoundation/AVMetadataMachineReadableCodeObject7.m", "src/AVFoundation/AVFoundationNames7.m", "src/AVFoundation/RevenantQRCode.c", "src/AVFoundation/RevenantQRECI.c")
        add_mflags("-fobjc-arc")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "AVFoundation", "CoreMedia", "CoreVideo")
        set_values("app.plist-file", "tests/qr_metadata/Info.plist")
        set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.backports.qrmetadata", "CFBundleDisplayName=BackportsQRMetadataProbe")
        set_values("revenant.control", "tests/qr_metadata/control")
        set_values("revenant.version", "1.0.0")
    target_end()

    target("MetalDeviceProbe")
        set_default(false)
        add_rules("@addon/revenant/daemon")
        add_files("tests/gpu_probe/probe.m")
        add_frameworks("Foundation", "OpenGLES", "CoreFoundation")
        add_syslinks("objc")
    target_end()

    target("MetalDeviceTrace")
        set_default(false)
        add_rules("@addon/revenant/library")
        add_files("tests/gpu_probe/gltrace.c")
        add_frameworks("IOKit", "CoreFoundation")
    target_end()

    target("MetalQueueProbe")
        set_default(false)
        add_rules("@addon/revenant/daemon")
        add_files("tests/gpu_probe/queue.m")
        add_frameworks("Foundation", "CoreFoundation", "OpenGLES", "IOKit")
        add_syslinks("objc")
    target_end()

    target("BackportsDeviceProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/app")
        add_files("tests/device_probe/main.m", "src/UIKit/RevenantAnimationDuration.m", "src/UIKit/UIView+InheritedAnimationDuration9.m", "src/UIKit/UIView+iOS13.m",
                  "src/UIKit/UIView+KeyframeAnimation7.m", "src/UIKit/UIResponder+TextInput7.m", "src/UIKit/UITextField+ContentType.m",
                  "src/UIKit/RevenantTextContentType.m", "src/UIKit/NSParagraphStyle+Text9.m", "src/UIKit/UILabel+Tightening9.m",
                  "src/UIKit/RevenantTightening.m", "src/Metal/*.m")
        add_mflags("-fobjc-arc")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "SystemConfiguration", "OpenGLES")
        set_values("app.plist-file", "tests/device_probe/Info.plist")
        set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.backports.deviceprobe", "CFBundleDisplayName=BackportsDeviceProbe")
        set_values("revenant.control", "tests/device_probe/control")
        set_values("revenant.guarded_selectors", "modifyAnimationsWithRepeatCount:autoreverses:animations:")
        set_values("revenant.version", "1.0.0")
    target_end()

    target("BackportsSceneKitProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/app")
        add_files("tests/device_probe/main.m", "src/UIKit/RevenantAnimationDuration.m", "src/UIKit/UIView+InheritedAnimationDuration9.m",
                  "src/UIKit/UIView+iOS13.m", "src/UIKit/UIView+KeyframeAnimation7.m", "src/UIKit/UIResponder+TextInput7.m",
                  "src/UIKit/UITextField+ContentType.m", "src/UIKit/RevenantTextContentType.m", "src/UIKit/NSParagraphStyle+Text9.m",
                  "src/UIKit/UILabel+Tightening9.m", "src/UIKit/RevenantTightening.m", "src/Metal/*.m")
        add_defines("REVENANT_PROBE_SCENEKIT")
        add_deps("SceneKitBackports")
        add_mflags("-fobjc-arc")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "SystemConfiguration", "OpenGLES")
        set_values("app.plist-file", "tests/device_probe/Info.plist")
        set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.backports.scenekitprobe", "CFBundleDisplayName=BackportsSceneKitProbe")
        set_values("revenant.control", "tests/device_probe/control")
        set_values("revenant.guarded_selectors", "modifyAnimationsWithRepeatCount:autoreverses:animations:")
        set_values("revenant.version", "1.0.0")
    target_end()

    backports_tests("backports_uikit", {uikit = "uikit_test.lua"})
    backports_tests("backports_avfoundation", {avfoundation = "avfoundation_test.lua"})
else
    backports_tests("backports", {generator = "backports_test.lua", libsystem = "libsystem_test.lua", webauth = "webauth_test.lua", demand = "demand_test.lua",
                                  uti = "uti_test.lua", cryptokit = "cryptokit_test.lua", naturallanguage = "nl_test.lua",
                                  network = "network_test.lua", networkpath = "network_path_test.lua", networktls = "network_tls_test.lua", networktlslistener = "network_tls_listener_test.lua", storekit = "storekit_test.lua", contracts = "contracts_test.lua", ios6members = "ios6_members_test.lua", attachment = "attachment_bounds_test.lua", protocols = "protocols_test.lua", lowering = "lowering_test.lua", modcache = "model_cache_test.lua", facts_cache = "facts_cache_test.lua",
                                  members = "lowered_members_test.lua", device = "device_members_test.lua", compression = "compression_roundtrip_test.lua",
                                  presentation = "presentation_intent_test.lua", exports = "lowered_exports_test.lua", constants = "constants_test.lua", passkitbutton = "passkit_button_test.lua", iosurface = "iosurface_test.lua",
                                  vfs = "lowered_vfs_test.lua", modules = "lowered_modules_test.lua", runtime_judge = "runtime/judge_test.lua", runtime_once = "runtime/once_test.lua", runtime_fingerprint = "runtime/fingerprint_test.lua", baseline_offset = "baseline_offset_oracle_test.lua", sec_access_control = "security_access_control_test.lua", sec_shared_web = "security_shared_web_test.lua", sec_items = "security_item_test.lua", sec_keys = "security_key_test.lua", la_passcode = "localauth_passcode_test.lua", air2es = "air2es_test.lua",
                                  webkitvalues = "webkit_values_test.lua", webkitmessage = "webkit_script_message_test.lua", webkitdocument = "webkit_document_start_test.lua",
                                  webkitwindow = "webkit_window_test.lua", webkitdownload = "webkit_download_test.lua", webkithistoryplan = "webkit_history_plan_test.lua",
                                  clock = "clock_uptime_test.lua", coretelephony = "coretelephony_test.lua"})
end

option("backports_libs", {type = "string", default = "", showmenu = true,
    description = "A folder of the Backports libraries (lib*Backports.dylib) that the runtime test app links and installs, for example the unpacked backports-libraries artifact of CI; empty uses the libraries this build makes."})

local RUNTIME = path.absolute(path.join(os.scriptdir(), "tests", "runtime"))
local RUNTIME_LIBS = get_config("backports_libs")
local RUNTIME_LINKS = {"FoundationBackports", "UIKitBackports", "AVFoundationBackports", "OpenGLESBackports", "SceneKitBackports", "CoreFoundationBackports", "CoreGraphicsBackports", "GraphicsBackports", "PhotosBackports", "CloudKitBackports"}

if is_plat("iphoneos") and get_config("tests") == "device" and not SELECTED then
    add_requires("revenant@emulator-guest", {alias = "emulator-guest"})

    target("backports_runtime_app")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(RUNTIME, "app", "main.m"), path.join(RUNTIME, "cases", "*.m"))
        add_includedirs(path.join(RUNTIME, "app"))
        add_deps("RevenantInterposeProbe")
        add_mflags("-fobjc-arc")
        if RUNTIME_LIBS and RUNTIME_LIBS ~= "" then
            add_linkdirs(RUNTIME_LIBS)
            add_links(table.unpack(RUNTIME_LINKS))
        else
            add_deps("RevenantSystemProbe", "FoundationBackports", "UIKitBackports", "IOSurfaceBackports", "AVFoundationBackports", "OpenGLESBackports", "SceneKitBackports", "PhotosBackports", "CloudKitBackports")
        end
        add_frameworks("Foundation", "UIKit", "CoreGraphics", "QuartzCore", "OpenAL", "AudioToolbox", "AssetsLibrary")
        add_syslinks("objc")
    target_end()

    target("RevenantWeakProbe")
        set_kind("shared")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(RUNTIME, "probe", "weak_probe.c"))
        add_frameworks("Foundation")
    target_end()

    target("RevenantInterposeProbe")
        set_kind("shared")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(RUNTIME, "probe", "interpose_probe.c"))
        add_shflags("-Wl,-install_name,/usr/lib/revenant/org.revenant.backports/libRevenantInterposeProbe.dylib", {force = true})
    target_end()

    target("RevenantMissingProbe")
        set_kind("shared")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(RUNTIME, "probe", "missing_probe.c"))
        add_frameworks("Foundation")
        add_shflags("-Wl,-U,_OBJC_CLASS_$_RevenantNoSuchClass", {force = true})
    target_end()

    target("RevenantSystemProbe")
        set_kind("shared")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(RUNTIME, "probe", "system_stand_in.m"))
        add_frameworks("Foundation")
        add_shflags("-install_name", INSTALL_FOLDER .. "/libRevenantSystemProbe.dylib", "-Wno-incompatible-sysroot", {force = true})
    target_end()

    target("backports_runtime")
        set_kind("phony")
        set_default(false)
        set_group("device")
        add_deps("backports_runtime_app", "RevenantWeakProbe", "RevenantMissingProbe", "RevenantSystemProbe")
        add_packages("emulator-guest")
        add_tests("foundation_url_components")
        add_tests("loader_class_backport")
        add_tests("flat_class_launch")
        add_tests("screenshot_notification")
        add_tests("directory_attributes")
        add_tests("photos_assets")
        add_tests("weak_class_binding")
        add_tests("missing_class_binding")
        add_tests("keybag_lock_state")
        add_tests("iosurface_surface")
        add_tests("interpose_launch", {should_fail = true})
        add_tests("scenekit_audio")
        add_tests("scenekit_render")
        add_tests("scenekit_members")
        add_tests("alias_public_name")
        add_tests("alias_system_class")
        add_tests("protocol_uimutabletraits")
        add_tests("trait_style_default")
        add_tests("protocol_ck_key_value_setting")
        on_test(function (target, opt)
            local case = path.filename(opt.name)
            local failures = import("driver", {rootdir = RUNTIME, anonymous = true}).failures(case, target)
            for _, failure in ipairs(failures) do
                cprint("${red}%s: %s", case, failure)
            end
            if opt.should_fail then
                return #failures > 0 and failures[1]:find("^the check must pass", 1) ~= nil
            end
            return #failures == 0
        end)
    target_end()
end

if is_plat("iphoneos") and not SELECTED then
    target("BackportsProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(os.scriptdir(), "tests", "probe", "probe.m"))
        add_mflags("-fobjc-arc", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability")
        add_deps("HealthKitBackports")
        add_syslinks("objc")
        add_frameworks("Foundation")
    target_end()

    target("SecurityProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(os.scriptdir(), "tests", "Security", "device", "probe.c"))
        add_cflags("-Wno-deprecated-declarations")
        set_values("revenant.entitlements", "tests/Security/device/entitlements.xml")
        add_frameworks("Foundation", "Security", "CoreFoundation")
    target_end()

    target("LocalAuthProbe")
        set_kind("binary")
        set_default(false)
        add_rules("@addon/revenant/apple-ios")
        add_files(path.join(os.scriptdir(), "tests", "LocalAuthentication", "device", "probe.m"),
                  path.join(os.scriptdir(), "src", "LocalAuthentication", "LAContext.m"),
                  path.join(os.scriptdir(), "src", "LocalAuthentication", "LAErrorDomain.m"),
                  path.join(os.scriptdir(), "src", "LocalAuthentication", "RevenantPasscode.m"),
                  path.join(os.scriptdir(), "src", "LocalAuthentication", "RevenantPasscodeKeyBag.m"))
        add_mflags("-fobjc-arc", "-Wno-unguarded-availability")
        add_frameworks("Foundation")
    target_end()
end

option("air2cpu", {default = false, showmenu = true,
    description = "Build air2cpu, the host tool that turns the AIR of a Metal compute kernel into the C kernel table the Metal port reads. It reads LLVM IR, so it needs revenant@llvm with its libraries; the configure is not for iphoneos."})

option("air2es", {default = false, showmenu = true,
    description = "Build air2es, the host tool that turns the AIR of a Metal render library into the OpenGL ES 2 folder (`<metallib>.es2/`) the Metal port loads. It reads LLVM IR, so it needs revenant@llvm with its libraries; the configure is not for iphoneos."})

if not is_plat("iphoneos") and (has_config("air2cpu") or has_config("air2es")) then
    add_requires("revenant@llvm 23.1.3", {alias = "llvm", configs = {libraries = true}})
end

if not is_plat("iphoneos") and has_config("air2cpu") then
    target("air2cpu")
        set_kind("binary")
        set_default(false)
        add_files(path.join(SRC, "air2cpu", "air2cpu.cpp"))
        add_packages("llvm")
    target_end()
end

rule("air2es.llvm")
    on_config(function (target)
        local llvm = target:pkg("llvm")
        if llvm then
            local prefix = llvm:installdir()
            target:add("sysincludedirs", path.join(prefix, "include"))
            target:add("linkdirs", path.join(prefix, "lib"))
            target:add("rpathdirs", path.join(prefix, "lib"))
        end
        target:add("defines", "_GNU_SOURCE", "__STDC_CONSTANT_MACROS", "__STDC_FORMAT_MACROS", "__STDC_LIMIT_MACROS")
        target:add("cxxflags", "-fno-rtti")
    end)
rule_end()

if not is_plat("iphoneos") and has_config("air2es") then
    target("air2es")
        set_kind("binary")
        set_default(false)
        set_languages("c++20")
        add_rules("air2es.llvm")
        add_files(path.join(SRC, "air2es", "*.cpp"))
        add_packages("llvm")
        add_links("LLVM")
    target_end()
end

local FOUNDATION_TESTS = {
    progress_keys = {"NSProgressKeys7.m"},
    metadata_query = {"NSMetadataQuery+Enumerate7.m"},
    text_checking = {"NSTextCheckingResult+Alternatives7.m"},
    expression = {"NSExpression+AllowEvaluation7.m"},
    date_components = {"NSDateComponents+Component8.m"},
    calendar_identifiers = {"NSCalendarIdentifiers8.m"},
    validated_format = {"NSString+ValidatedFormat.m"},
    file_relationship = {"NSFileManager+Relationship8.m"},
    underlying_errors = {"NSError+UnderlyingErrors14.m"},
    identifier_keys = {"NSAttributedStringKeys15.m", "NSAttributedStringKeys26.m", "NSLocalizedNumberFormatRule18.m", "NSURLUbiquitousKeys145.m", "FoundationIdentifiers17.m"},
    expression_members = {"NSExpression+AnyKey7.m", "NSExpression+ConditionalMembers9.m", "NSExpression+Conditional.m"},
    calendar_next_date = {"NSCalendar+NextDate8.m", "NSCalendar+Components.m", "NSDateComponents+Component8.m", "RevenantCalendarUnits.m"},
    calendar_day_changed = {"NSCalendarDayChanged8.m"},
    expiring_activity = {"NSProcessInfo+ExpiringActivity82.m"},
    coder_minimum_length = {"NSCoder+MinimumLength184.m"},
    bundle_localizations = {"NSBundle+Localizations184.m"},
    date_components_day = {"NSDateComponents+DayOfYear18.m", "NSDateComponents+RepeatedDay26.m", "NSDateComponents+Component8.m", "NSCalendar+Components.m", "RevenantCalendarUnits.m"},
    task_progress = {"RevenantTaskProgress.m"},
    cookie_storage = {"RevenantCookieStorage.m", "NSHTTPCookieStorage+Task8.m"},
    shared_observers = {"NSKeyValueSharedObservers18.m"},
    progress_publish = {"NSProgress+Publish7.m"},
    measurement_formatter = {"NSMeasurementFormatter.m", "RevenantMeasurementData.m", "RevenantUnitFormat.m"},
    attributed_format_context = {"NSAttributedStringLocalizedFormat15.m", "NSAttributedStringKeys15.m"},
    url_cache_since = {"NSURLCache+Since8.m"},
    formatting_context = {"NSFormattingContext8.m"},
    file_items = {"NSFileManager+Trash11.m", "NSURL+AliasFile8.m", "NSFileVersion+Properties8.m", "NSString+VariantWidth9.m"},
    header_bytes = {"RevenantHeaderBytes.m"},
    metadata_items = {"NSMetadataQuery+Items7.m"},
    nsurlsession_delegates = {"nsurlsession_delegates_test.m"},
    iso8601_date_formatter = {"iso8601_date_formatter_test.m"},
}

local QUARTZCORE_TESTS = {
    protocols = {"QuartzCoreProtocols10.m"},
    spring_animation = {"RevenantSpringSolver.m", "RevenantSpringKeyframes.m", "CASpringAnimation.m"},
}

local CORETEXT_TESTS = {
    open_type_feature = {"CTFontOpenTypeFeatureKeys8.m"},
}

local SCENEKIT_TESTS = {
    action_math = {"RevenantSCNActionMath.m"},
    clock = {"RevenantSCNClock.m"},
    jitter = {"RevenantSCNJitter.m"},
    picking = {"RevenantSCNGeometry.m"},
    action_run = {"SCNAction.m", "RevenantSCNActionRun.m", "RevenantSCNActionMath.m", "SCNAudioSource.m", "SCNAudioPlayer.m", "RevenantSCNSoundEngine.m", "RevenantSCNStream.m"},
    audio = {"SCNAudioSource.m", "SCNAudioPlayer.m", "RevenantSCNSoundEngine.m", "RevenantSCNStream.m"},
}

local function host_tests(folder, tests, library, frameworks, options)
    options = options or {}
    local TESTS = path.join(os.scriptdir(), "tests", folder)
    for name, sources in pairs(tests) do
        target(folder .. "Backports_" .. name .. "_test")
            set_kind("binary")
            set_plat("macosx")
            set_arch("arm64")
            set_default(false)
            add_files(path.join(TESTS, name .. "_test." .. (options.extension or "m")))
            for _, source in ipairs(sources) do
                add_files(path.join(SRC, library or folder, source))
            end
            add_includedirs(TESTS, path.join(os.scriptdir(), "tests", "Foundation"), path.join(SRC, "Foundation"), path.join(SRC, library or folder))
            add_mflags("-fobjc-arc")
            add_mxxflags("-fobjc-arc")
            add_ldflags("-fobjc-arc")
            add_cxxflags(table.unpack(options.cxxflags or {}))
            add_frameworks(table.unpack(frameworks or {"Foundation"}))
            add_syslinks(table.unpack(options.syslinks or {}))
            for _, package in ipairs(options.packages or {}) do
                add_packages(package)
            end
            for _, define in ipairs(options.defines or {}) do
                add_defines(define)
            end
            add_tests("default")
            add_tests("negative", {runargs = {"--negative"}, expect_failure = true})
            on_test(function (target, opt)
                if options.arguments then
                    opt.runargs = table.join(opt.runargs or {}, options.arguments(target, TESTS))
                end
                return import("@addon.revenant.host_test", {anonymous = true}).run(target, opt)
            end)
        target_end()
    end
end

if not is_plat("iphoneos") then
    add_requires("revenant@ffmpeg", {alias = "ffmpeg"})
    host_tests("Foundation", FOUNDATION_TESTS, nil, {"Foundation"}, {syslinks = {"sqlite3"}})
    host_tests("AVFoundation", {qr_decoder = {"RevenantQRCode.c", "RevenantQRECI.c"}, audio_preset = {"RevenantAudioUnitPreset.m"}}, nil, {"Foundation", "CoreImage", "CoreGraphics", "AudioToolbox"})
    if is_arch("arm64", "x86_64") then
        host_tests("Vision", {barcode = {"VNBarcodeDecoderCore.cpp", "VNBarcodeDecoder.mm", "VNGrayscale.m"}}, nil, {"Foundation", "CoreImage", "CoreGraphics", "CoreVideo"}, {extension = "mm", packages = {"zxing-cpp"}, cxxflags = {"-std=c++20", "-Wno-deprecated-declarations"}})
        host_tests("Vision", {text = {"VNTextRecognizerCore.cpp", "VNTextRecognizer.mm", "VNGrayscale.m"}}, nil, {"Foundation", "Vision", "CoreImage", "CoreGraphics", "CoreVideo", "ImageIO"}, {extension = "mm", packages = {"tesseract", "leptonica", "tessdata"}, cxxflags = {"-std=c++20", "-Wno-deprecated-declarations"}, arguments = function (target, tests) return {path.join(tests, "data", "text"), path.join(target:pkg("tessdata"):installdir(), "share", "tessdata")} end})
    end
    host_tests("Vision", {rectangle = {"VNRectangleDetector.c", "VNRectangleImage.m", "VNConstants.m"}}, nil, {"Foundation", "Vision", "CoreImage", "CoreGraphics", "CoreVideo"}, {extension = "mm"})
    host_tests("QuartzCore", QUARTZCORE_TESTS, "UIKit", {"Foundation", "QuartzCore", "CoreGraphics"},
               {syslinks = {"sqlite3"}, defines = {"REVENANT_HOST_BUILD"}})
    host_tests("CoreMedia", {timebase = {"CMTimebase6.c"}}, nil, {"CoreMedia", "Foundation"})
    host_tests("CoreText", CORETEXT_TESTS, nil, {"CoreText", "Foundation"})
    host_tests("SceneKit", SCENEKIT_TESTS, nil, {"SceneKit", "Foundation", "QuartzCore", "OpenAL", "AudioToolbox", "AVFoundation"})
    host_tests("PassKit", {payment_network = {"PKPaymentNetworks8.m"}})
    host_tests("Intents", {message_types = {"RevenantIntents10.m", "coding/RevenantCoding.m"}, object = {"RevenantIntents120.m", "RevenantIntentsResolution.m", "coding/RevenantCoding.m"}, result = {"RevenantIntents120.m", "RevenantIntentsResolution.m", "coding/RevenantCoding.m"}}, nil, {"Foundation", "Intents"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("Metal", {binary_archive = {"RevenantMetalBinaryArchive.m"}}, nil, {"Foundation", "Metal"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("CoreImage", {render_destination = {"CIRenderDestination11.m"}}, "Graphics", {"Foundation", "CoreImage", "CoreGraphics", "CoreVideo", "IOSurface", "Metal", "OpenGL"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("VideoToolbox", {conversion = {"VTCreateCGImage9_0.m", "VTConvertBiPlanar.c"}, hardware = {"VTIsHardwareDecodeSupported11_0.m"}}, nil, {"VideoToolbox", "CoreMedia", "CoreVideo", "CoreGraphics", "Foundation"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("VideoToolbox", {hevc = {"VTDecompressionSession8_0.m", "VTSession8_0.m", "VTDecompressionSessionHEVC.m", "VTDecodeHEVC.c", "VTConvertBiPlanar.c", "VTInterleave.c", "VTSystem.c"}}, nil, {"VideoToolbox", "CoreMedia", "CoreVideo", "CoreGraphics", "CoreFoundation", "Foundation"}, {defines = {"REVENANT_HOST_BUILD", "REVENANT_VT_FIXTURE_DIR=\"" .. path.join(os.scriptdir(), "tests", "data", "VideoToolbox") .. "\""}, packages = {"ffmpeg"}, syslinks = {"iconv"}})
    host_tests("LinkPresentation", {metadata = {"RevenantLinkPresentation.m", "RevenantLinkFetch.m", "LPLinkMetadata.m", "LPMetadataProvider.m"}}, nil, {"Foundation", "LinkPresentation"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("DeviceCheck", {device = {"DCDevice.m", "DCAppAttestService.m"}}, nil, {"Foundation", "DeviceCheck"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("WebKit", {webkit = {"WKSnapshotConfiguration.m", "WKURLSchemes.m", "WKSecurityOrigin.m"}}, nil, {"Foundation", "WebKit", "CoreGraphics"}, {defines = {"REVENANT_HOST_BUILD"}})
    host_tests("Photos", {image_source = {"RevenantPhotosImageSource.c"}, image_cache = {"RevenantPhotosImageCache.m"}, photo_moves = {"RevenantPhotoMoves.c"}})
    host_tests("UIKit", {animation_duration = {"RevenantAnimationDuration.m"}, tightening = {"RevenantTightening.m"}}, nil, {"Foundation"})
    host_tests("AuthenticationServices", {authorization = {"ASAuthorizationController.m", "ASAuthorizationPlatformPublicKeyCredentialProvider.m", "ASAuthorizationPlatformPublicKeyCredentialRequests.m", "ASAuthorizationRequest.m", "ASConstants13_0.m", "RevenantASAppleIDButtonMetrics.m"}}, nil, {"Foundation", "AuthenticationServices", "AppKit"}, {defines = {"REVENANT_HOST_BUILD"}})
end

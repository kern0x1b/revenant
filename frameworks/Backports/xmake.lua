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

local LIBRARIES = {
    {name = "FoundationBackports", folder = "Foundation", frameworks = {"Foundation", "CoreFoundation", "SystemConfiguration"}, libraries = {"icucore", "CoreFoundationBackports"}, archives = {}, system = {}},
    {name = "CloudKitBackports", folder = "CloudKit", frameworks = {"Foundation", "CoreLocation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"RevenantCKWebAuth", "micro-ecc"}, system = {}},
    {name = "AppTrackingTransparencyBackports", folder = "AppTrackingTransparency", frameworks = {"AppTrackingTransparency", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "AdServicesBackports", folder = "AdServices", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "AppClipBackports", folder = "AppClip", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "AccountsBackports", folder = "Accounts", frameworks = {"Accounts", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CFNetworkBackports", folder = "CFNetwork", frameworks = {"CFNetwork", "CoreFoundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "IOSurfaceBackports", folder = "IOSurface", frameworks = {"IOSurface", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreServicesBackports", folder = "CoreServices", frameworks = {"CoreServices", "CoreFoundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "IOKitBackports", folder = "IOKit", frameworks = {"IOKit", "CoreFoundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "BrowserKitBackports", folder = "BrowserKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreNFCBackports", folder = "CoreNFC", frameworks = {"Foundation", "CoreFoundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "GameKitBackports", folder = "GameKit", frameworks = {"GameKit", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "GraphicsBackports", folder = "Graphics", frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "ImageIO", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"apple-compat"}, system = {}},
    {name = "UIKitBackports", folder = "UIKit", frameworks = {"UIKit", "Foundation", "CFNetwork", "CoreGraphics", "QuartzCore", "MobileCoreServices", "ImageIO", "CoreLocation"}, libraries = {"FoundationBackports", "GraphicsBackports", "CoreGraphicsBackports"}, archives = {"box2d"}, system = {}},
    {name = "CoreLocationBackports", folder = "CoreLocation", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreTextBackports", folder = "CoreText", frameworks = {"CoreText", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreDataBackports", folder = "CoreData", frameworks = {"CoreData", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SecurityBackports", folder = "Security", frameworks = {"Security", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"RevenantCKWebAuth", "micro-ecc"}, system = {}},
    {name = "CommonCryptoBackports", folder = "CommonCrypto", frameworks = {"Security"}, libraries = {}, archives = {}, system = {}},
    {name = "CoreBluetoothBackports", folder = "CoreBluetooth", frameworks = {"Foundation"}, libraries = {}, archives = {}, system = {}},
    {name = "CompressionBackports", folder = "Compression", frameworks = {}, libraries = {}, archives = {"lzfse", "zlib", "lz4", "xz"}, system = {}},
    {name = "SpatialBackports", folder = "Spatial", frameworks = {}, libraries = {}, archives = {}, system = {}},
    {name = "SQLite3Backports", folder = "SQLite3", frameworks = {}, libraries = {"sqlite3"}, archives = {}, system = {}},
    {name = "SpriteKitBackports", folder = "SpriteKit", frameworks = {"Foundation", "CoreGraphics", "UIKit", "QuartzCore", "OpenGLES"}, libraries = {}, archives = {}, system = {}},
    {name = "AccelerateBackports", folder = "Accelerate", frameworks = {"Accelerate", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"suitesparse-ordering"}, system = {}},
    {name = "AVFoundationBackports", folder = "AVFoundation", frameworks = {"AVFoundation", "CoreMedia", "CoreVideo", "AudioToolbox", "CoreImage", "ImageIO", "CoreGraphics", "QuartzCore", "Accelerate", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports", "CoreFoundationBackports", "CoreMediaBackports"}, archives = {"RevenantCoding"}, system = {}},
    {name = "AVFAudioBackports", folder = "AVFAudio", frameworks = {"AudioToolbox", "CoreAudio", "AVFoundation", "UIKit", "Foundation", "Accelerate", "QuartzCore"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports", "AVFoundationBackports"}, archives = {}, system = {}},
    {name = "WebKitBackports", folder = "WebKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {}, system = {}},
    {name = "LocalAuthenticationBackports", folder = "LocalAuthentication", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "OpenGLESBackports", folder = "OpenGLES", frameworks = {"OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SafariServicesBackports", folder = "SafariServices", frameworks = {"SafariServices", "UIKit", "Foundation", "CoreGraphics", "QuartzCore", "MobileCoreServices"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "AuthenticationServicesBackports", folder = "AuthenticationServices", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "SafariServicesBackports"}, archives = {}, system = {}},
    {name = "BackgroundTasksBackports", folder = "BackgroundTasks", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "PhotosBackports", folder = "Photos", frameworks = {"AssetsLibrary", "AVFoundation", "CoreLocation", "CoreGraphics", "ImageIO", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "GameControllerBackports", folder = "GameController", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreMLBackports", folder = "CoreML", frameworks = {"CoreML", "CoreVideo", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "VisionBackports", folder = "Vision", frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "CoreML", "Foundation"}, libraries = {"FoundationBackports", "CoreMLBackports"}, archives = {}, system = {}},
    {name = "MetalBackports", folder = "Metal", frameworks = {"QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "MetalKitBackports", folder = "MetalKit", frameworks = {"MetalKit", "Metal", "ModelIO", "UIKit", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports", "ModelIOBackports"}, archives = {}, system = {}},
    {name = "MPSBackports", folder = "MetalPerformanceShaders", frameworks = {"Metal", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports"}, archives = {}, system = {}},
    {name = "MPSGraphBackports", folder = "MetalPerformanceShadersGraph", frameworks = {"Metal", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports", "MPSBackports"}, archives = {}, system = {}},
    {name = "CoreTelephonyBackports", folder = "CoreTelephony", frameworks = {"CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreMIDIBackports", folder = "CoreMIDI", frameworks = {"CoreMIDI", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CallKitBackports", folder = "CallKit", frameworks = {"CoreTelephony", "AVFoundation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "ContactsBackports", folder = "Contacts", frameworks = {"AddressBook", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports", "CoreFoundationBackports"}, archives = {}, system = {}},
    {name = "HomeKitBackports", folder = "HomeKit", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"monocypher"}, system = {}},
    {name = "CoreSpotlightBackports", folder = "CoreSpotlight", frameworks = {"CoreSpotlight", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "PushKitBackports", folder = "PushKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "JavaScriptCoreBackports", folder = "JavaScriptCore", frameworks = {"JavaScriptCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SceneKitBackports", folder = "SceneKit", frameworks = {"UIKit", "QuartzCore", "OpenGLES", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "OpenGLESBackports"}, archives = {}, system = {}},
    {name = "MediaPlayerBackports", folder = "MediaPlayer", frameworks = {"MediaPlayer", "AVFoundation", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "MessageUIBackports", folder = "MessageUI", frameworks = {"MessageUI", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "MessagesBackports", folder = "Messages", frameworks = {"MessageUI", "Messages", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "MetricKitBackports", folder = "MetricKit", frameworks = {"MetricKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SensorKitBackports", folder = "SensorKit", frameworks = {"SensorKit", "CoreMedia", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SecurityUIBackports", folder = "SecurityUI", frameworks = {"SecurityUI", "Security", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "UserNotificationsUIBackports", folder = "UserNotificationsUI", frameworks = {"UserNotificationsUI", "UserNotifications", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {}, system = {}},
    {name = "NotificationCenterBackports", folder = "NotificationCenter", frameworks = {"NotificationCenter", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {}, system = {}},
    {name = "AVKitBackports", folder = "AVKit", frameworks = {"UIKit", "AVFoundation", "CoreMedia", "CoreVideo", "CoreImage", "MediaPlayer", "QuartzCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports", "CoreMediaBackports"}, archives = {}, system = {}},
    {name = "MapKitBackports", folder = "MapKit", frameworks = {"MapKit", "UIKit", "CoreGraphics", "CoreLocation", "QuartzCore", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "PassKitBackports", folder = "PassKit", frameworks = {"PassKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreMediaBackports", folder = "CoreMedia", frameworks = {"CoreMedia", "CoreVideo", "AudioToolbox", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "CoreVideoBackports"}, archives = {}, system = {}},
    {name = "CoreFoundationBackports", folder = "CoreFoundation", frameworks = {"CoreFoundation", "Foundation"}, libraries = {}, archives = {}, system = {}},
    {name = "StoreKitBackports", folder = "StoreKit", frameworks = {"StoreKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreGraphicsBackports", folder = "CoreGraphics", frameworks = {"CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"apple-compat"}, system = {}},
    {name = "AddressBookUIBackports", folder = "AddressBookUI", frameworks = {"AddressBookUI", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "CoreVideoBackports", folder = "CoreVideo", frameworks = {"CoreVideo", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"apple-compat"}, system = {}},
    {name = "CoreMotionBackports", folder = "CoreMotion", frameworks = {"CoreMotion", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "ReplayKitBackports", folder = "ReplayKit", frameworks = {"ReplayKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "SpeechBackports", folder = "Speech", frameworks = {"Speech", "AVFoundation", "Foundation"}, libraries = {"AVFoundationBackports", "FoundationBackports"}, archives = {}, system = {}},
    {name = "CarPlayBackports", folder = "CarPlay", frameworks = {"CarPlay", "MapKit", "UIKit", "CoreGraphics", "CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "FileProviderBackports", folder = "FileProvider", frameworks = {"FileProvider", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "NetworkBackports", folder = "Network", frameworks = {"Network", "Foundation", "Security"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "IntentsBackports", folder = "Intents", frameworks = {"Intents", "UIKit", "CoreLocation", "EventKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {"RevenantCoding"}, system = {}},
    {name = "AccessibilityBackports", folder = "Accessibility", frameworks = {"Accessibility", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"RevenantCoding"}, system = {}},
    {name = "IntentsUIBackports", folder = "IntentsUI", frameworks = {"IntentsUI", "Intents", "UIKit", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports", "IntentsBackports"}, archives = {}, system = {}},
    {name = "ARKitBackports", folder = "ARKit", frameworks = {"ARKit", "AVFoundation", "CoreMotion", "CoreLocation", "CoreMedia", "CoreVideo", "CoreGraphics", "ImageIO", "QuartzCore", "OpenGLES", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "AVFoundationBackports", "SceneKitBackports"}, archives = {}, system = {}},
    {name = "HealthKitBackports", folder = "HealthKit", frameworks = {"HealthKit", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {"sqlite3"}},
    {name = "MLComputeBackports", folder = "MLCompute", frameworks = {"Accelerate", "Foundation"}, libraries = {"FoundationBackports", "AccelerateBackports"}, archives = {"ggml"}, system = {}},
    {name = "VideoToolboxBackports", folder = "VideoToolbox", frameworks = {"VideoToolbox", "CoreMedia", "CoreVideo", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports", "CoreMediaBackports"}, archives = {}, system = {}},
    {name = "ModelIOBackports", folder = "ModelIO", frameworks = {"ModelIO", "CoreGraphics", "ImageIO", "MobileCoreServices", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "GameplayKitBackports", folder = "GameplayKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "PDFKitBackports", folder = "PDFKit", frameworks = {"PDFKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
    {name = "NetworkExtensionBackports", folder = "NetworkExtension", frameworks = {"NetworkExtension", "Foundation", "SystemConfiguration"}, libraries = {"FoundationBackports"}, archives = {}, system = {}},
}

if is_plat("iphoneos") then
    add_requires("revenant@lzfse lzfse-1.0", {alias = "lzfse"})
    add_requires("revenant@zlib v1.3.2", {alias = "zlib"})
    add_requires("revenant@lz4 v1.9.2", {alias = "lz4"})
    add_requires("revenant@xz v5.8.4", {alias = "xz"})
    add_requires("revenant@box2d 2.2.1", {alias = "box2d"})
    add_requires("revenant@micro-ecc", {alias = "micro-ecc"})
    add_requires("revenant@monocypher 4.0.2", {alias = "monocypher"})
    add_requires("revenant@suitesparse-ordering v7.12.2", {alias = "suitesparse-ordering"})
    add_requires("revenant@ggml 0.25.3", {alias = "ggml"})

    local generator

    local FLAGS = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    local OBJC_FLAGS = table.join(FLAGS, {"-fobjc-arc", "-Werror=objc-missing-property-synthesis", "-fmacro-prefix-map=" .. ROOT .. "/="})
    local OURS = {RevenantCoding = true, RevenantCKWebAuth = true}
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

    target("RevenantCKWebAuth")
        set_kind("static")
        add_rules("@addon/revenant/apple-ios")
        set_optimize("smallest")
        add_cflags("-Os", "-fvisibility=hidden", "-fno-strict-aliasing")
        add_files(path.join(WEBAUTH, "RevenantCKWebAuth.c"))
        add_headerfiles(path.join(WEBAUTH, "RevenantCKWebAuth.h"))
        add_includedirs(WEBAUTH, {public = true})
        add_packages("micro-ecc", {public = true})

    target("revenant-callkit-screen")
        set_default(false)
        add_rules("@addon/revenant/tweak")
        add_files(path.join(TWEAK, "RevenantCallScreenTweak.m"))
        add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
        set_values("tweak.filter", path.join(TWEAK, "springboard.plist"))
        set_values("revenant.control", path.join(TWEAK, "control"))

    for _, library in ipairs(LIBRARIES) do
        target(library.name)
            set_kind("shared")
            add_rules("@addon/revenant/apple-ios")
            set_optimize("smallest")
            set_symbols("none")
            add_cflags(table.join(FLAGS, {"-fvisibility=hidden", "-fmacro-prefix-map=" .. ROOT .. "/="}))
            add_mflags(OBJC_FLAGS)
            add_mxxflags(table.join(OBJC_FLAGS, {"-fno-rtti", "-fvisibility-inlines-hidden"}))
            add_shflags("-install_name", INSTALL_FOLDER .. "/lib" .. library.name .. ".dylib", "-Wno-incompatible-sysroot",
                        "-Wl,-no_encryption", "-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__port_catlist", {force = true})
            add_syslinks("objc")
            if #os.files(path.join(SRC, library.folder, "*.mm")) > 0 then
                add_syslinks("c++")
            end
            add_files(table.join(os.files(path.join(SRC, library.folder, "*.m")), os.files(path.join(SRC, library.folder, "*.mm")),
                                 os.files(path.join(SRC, library.folder, "*.c")), {path.join(SRC, "attach.c")}))
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
                if OURS[name] then
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
    end

    target("MLComputeBackports")
        add_files(path.join(SRC, "MLCompute", "ggml", "ggml-libcxx.cpp"))
        add_cxxflags("-std=c++17", "-fno-exceptions", "-fno-rtti", "-fvisibility=hidden", "-fvisibility-inlines-hidden")
    target_end()
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
    backports_tests("backports_uikit", {uikit = "uikit_test.lua"})
else
    backports_tests("backports", {generator = "backports_test.lua", webauth = "webauth_test.lua", demand = "demand_test.lua"})
end

option("air2cpu", {default = false, showmenu = true,
    description = "Build air2cpu, the host tool that turns the AIR of a Metal compute kernel into the C kernel table the Metal port reads. It reads LLVM IR, so it needs revenant@llvm with its libraries; the configure is not for iphoneos."})

if not is_plat("iphoneos") and has_config("air2cpu") then
    add_requires("revenant@llvm 23.1.3", {alias = "llvm", configs = {libraries = true}})

    target("air2cpu")
        set_kind("binary")
        set_default(false)
        add_files(path.join(SRC, "air2cpu", "air2cpu.cpp"))
        add_packages("llvm")
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
}

if not is_plat("iphoneos") then
    local TESTS = path.join(os.scriptdir(), "tests", "Foundation")
    for name, sources in pairs(FOUNDATION_TESTS) do
        target("FoundationBackports_" .. name .. "_test")
            set_kind("binary")
            set_plat("macosx")
            set_arch("arm64")
            set_default(false)
            add_files(path.join(TESTS, name .. "_test.m"))
            for _, source in ipairs(sources) do
                add_files(path.join(SRC, "Foundation", source))
            end
            add_includedirs(TESTS)
            add_mflags("-fobjc-arc")
            add_ldflags("-fobjc-arc")
            add_frameworks("Foundation")
            add_tests("default")
            add_tests("negative", {runargs = {"--negative"}, should_fail = true})
        target_end()
    end
end

import("macho")
import("dyld")
import("firmware")
import("signing")
import("objc")
import("core.base.json")
import("core.base.scheduler")
import("cache")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

LIBRARIES = {
    {name = "FoundationBackports", folder = "Foundation", frameworks = {"Foundation", "CoreFoundation", "SystemConfiguration"}, libraries = {"icucore"}},
    {name = "CloudKitBackports", folder = "CloudKit", frameworks = {"Foundation", "CoreLocation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"micro-ecc"}, c_archives = {"micro-ecc"}},
    {name = "AppTrackingTransparencyBackports", folder = "AppTrackingTransparency", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AdServicesBackports", folder = "AdServices", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AppClipBackports", folder = "AppClip", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AccountsBackports", folder = "Accounts", frameworks = {"Accounts", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CFNetworkBackports", folder = "CFNetwork", frameworks = {"CFNetwork", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "IOSurfaceBackports", folder = "IOSurface", frameworks = {"IOSurface", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreServicesBackports", folder = "CoreServices", frameworks = {"CoreServices", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "IOKitBackports", folder = "IOKit", frameworks = {"IOKit", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "BrowserKitBackports", folder = "BrowserKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreNFCBackports", folder = "CoreNFC", frameworks = {"Foundation", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "GameKitBackports", folder = "GameKit", frameworks = {"GameKit", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "GraphicsBackports", folder = "Graphics", generated = {"ImageIO", "CoreImage"}, frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "ImageIO", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"apple-compat"}, c_archives = {"apple-compat"}},
    {name = "UIKitBackports", folder = "UIKit", frameworks = {"UIKit", "Foundation", "CFNetwork", "CoreGraphics", "QuartzCore", "MobileCoreServices", "ImageIO", "CoreLocation"}, libraries = {"FoundationBackports", "GraphicsBackports"}, archives = {"box2d"}},
    {name = "CoreLocationBackports", folder = "CoreLocation", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreTextBackports", folder = "CoreText", frameworks = {"CoreText", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreDataBackports", folder = "CoreData", frameworks = {"CoreData", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SecurityBackports", folder = "Security", frameworks = {"Security", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"micro-ecc"}, c_archives = {"micro-ecc"}},
    {name = "CommonCryptoBackports", folder = "CommonCrypto", frameworks = {"Security"}, libraries = {}},
    {name = "CoreBluetoothBackports", folder = "CoreBluetooth", frameworks = {"Foundation"}, libraries = {}},
    {name = "CompressionBackports", folder = "Compression", frameworks = {}, libraries = {}, archives = {"lzfse", "zlib", "lz4", "xz"}, c_archives = {"lzfse", "zlib", "lz4", "xz"}},
    {name = "SpatialBackports", folder = "Spatial", frameworks = {}, libraries = {}},
    {name = "SQLite3Backports", folder = "SQLite3", frameworks = {}, libraries = {"sqlite3"}},
    {name = "SpriteKitBackports", folder = "SpriteKit", frameworks = {"Foundation", "CoreGraphics", "UIKit", "QuartzCore", "OpenGLES"}, libraries = {}},
    {name = "AccelerateBackports", folder = "Accelerate", frameworks = {"Accelerate", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"suitesparse-ordering"}, c_archives = {"suitesparse-ordering"}},
    {name = "AVFoundationBackports", folder = "AVFoundation", frameworks = {"AVFoundation", "CoreMedia", "CoreVideo", "AudioToolbox", "CoreImage", "ImageIO", "CoreGraphics", "QuartzCore", "Accelerate", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports"}, archives = {"revenant-coding"}, c_archives = {"revenant-coding"}},
    {name = "AVFAudioBackports", folder = "AVFAudio", frameworks = {"AudioToolbox", "CoreAudio", "AVFoundation", "UIKit", "Foundation", "Accelerate", "QuartzCore"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports", "AVFoundationBackports"}},
    {name = "WebKitBackports", folder = "WebKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "LocalAuthenticationBackports", folder = "LocalAuthentication", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "OpenGLESBackports", folder = "OpenGLES", frameworks = {"OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SafariServicesBackports", folder = "SafariServices", frameworks = {"UIKit", "Foundation", "CoreGraphics", "QuartzCore", "MobileCoreServices"}, libraries = {"FoundationBackports"}},
    {name = "AuthenticationServicesBackports", folder = "AuthenticationServices", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "SafariServicesBackports"}},
    {name = "BackgroundTasksBackports", folder = "BackgroundTasks", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PhotosBackports", folder = "Photos", frameworks = {"AssetsLibrary", "AVFoundation", "CoreLocation", "CoreGraphics", "ImageIO", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "GameControllerBackports", folder = "GameController", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreMLBackports", folder = "CoreML", frameworks = {"CoreML", "CoreVideo", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "VisionBackports", folder = "Vision", frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "CoreML", "Foundation"}, libraries = {"FoundationBackports", "CoreMLBackports"}},
    {name = "MetalBackports", folder = "Metal", frameworks = {"QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MetalKitBackports", folder = "MetalKit", frameworks = {"UIKit", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports"}},
    {name = "MPSBackports", folder = "MetalPerformanceShaders", frameworks = {"Metal", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports"}},
    {name = "MPSGraphBackports", folder = "MetalPerformanceShadersGraph", frameworks = {"Metal", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports", "MPSBackports"}},
    {name = "CoreTelephonyBackports", folder = "CoreTelephony", frameworks = {"CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreMIDIBackports", folder = "CoreMIDI", frameworks = {"CoreMIDI", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CallKitBackports", folder = "CallKit", frameworks = {"CoreTelephony", "AVFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "ContactsBackports", folder = "Contacts", frameworks = {"AddressBook", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "HomeKitBackports", folder = "HomeKit", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"monocypher"}, c_archives = {"monocypher"}},
    {name = "CoreSpotlightBackports", folder = "CoreSpotlight", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PushKitBackports", folder = "PushKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "JavaScriptCoreBackports", folder = "JavaScriptCore", frameworks = {"JavaScriptCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SceneKitBackports", folder = "SceneKit", frameworks = {"UIKit", "QuartzCore", "OpenGLES", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "OpenGLESBackports"}},
    {name = "MediaPlayerBackports", folder = "MediaPlayer", frameworks = {"MediaPlayer", "AVFoundation", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MessageUIBackports", folder = "MessageUI", frameworks = {"MessageUI", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MessagesBackports", folder = "Messages", frameworks = {"MessageUI", "Messages", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MetricKitBackports", folder = "MetricKit", frameworks = {"MetricKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SensorKitBackports", folder = "SensorKit", frameworks = {"SensorKit", "CoreMedia", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SecurityUIBackports", folder = "SecurityUI", frameworks = {"SecurityUI", "Security", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "UserNotificationsUIBackports", folder = "UserNotificationsUI", frameworks = {"UserNotificationsUI", "UserNotifications", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "NotificationCenterBackports", folder = "NotificationCenter", frameworks = {"NotificationCenter", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "AVKitBackports", folder = "AVKit", frameworks = {"UIKit", "AVFoundation", "CoreMedia", "CoreVideo", "CoreImage", "MediaPlayer", "QuartzCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "MapKitBackports", folder = "MapKit", frameworks = {"MapKit", "UIKit", "CoreGraphics", "CoreLocation", "QuartzCore", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PassKitBackports", folder = "PassKit", frameworks = {"PassKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreMediaBackports", folder = "CoreMedia", frameworks = {"CoreMedia", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreFoundationBackports", folder = "CoreFoundation", frameworks = {"CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "StoreKitBackports", folder = "StoreKit", frameworks = {"StoreKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreGraphicsBackports", folder = "CoreGraphics", frameworks = {"CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AddressBookUIBackports", folder = "AddressBookUI", frameworks = {"AddressBookUI", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreVideoBackports", folder = "CoreVideo", frameworks = {"CoreVideo", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreMotionBackports", folder = "CoreMotion", frameworks = {"CoreMotion", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "ReplayKitBackports", folder = "ReplayKit", frameworks = {"UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SpeechBackports", folder = "Speech", frameworks = {"Speech", "AVFoundation", "Foundation"}, libraries = {"AVFoundationBackports", "FoundationBackports"}},
    {name = "CarPlayBackports", folder = "CarPlay", frameworks = {"CarPlay", "MapKit", "UIKit", "CoreGraphics", "CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "FileProviderBackports", folder = "FileProvider", frameworks = {"FileProvider", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "NetworkBackports", folder = "Network", frameworks = {"Network", "Foundation", "Security"}, libraries = {"FoundationBackports"}},
    {name = "IntentsBackports", folder = "Intents", frameworks = {"Intents", "UIKit", "CoreLocation", "EventKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {"revenant-coding"}, c_archives = {"revenant-coding"}},
    {name = "AccessibilityBackports", folder = "Accessibility", frameworks = {"Accessibility", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"revenant-coding"}, c_archives = {"revenant-coding"}},
    {name = "IntentsUIBackports", folder = "IntentsUI", frameworks = {"IntentsUI", "Intents", "UIKit", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports", "IntentsBackports"}},
    {name = "ARKitBackports", folder = "ARKit", frameworks = {"ARKit", "AVFoundation", "CoreMotion", "CoreLocation", "CoreMedia", "CoreVideo", "CoreGraphics", "ImageIO", "QuartzCore", "OpenGLES", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "AVFoundationBackports", "SceneKitBackports"}},
    {name = "HealthKitBackports", folder = "HealthKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}, system = {"sqlite3"}},
    {name = "MLComputeBackports", folder = "MLCompute", frameworks = {"Accelerate", "Foundation"}, libraries = {"FoundationBackports", "AccelerateBackports"}, archives = {"ggml"}},
    {name = "VideoToolboxBackports", folder = "VideoToolbox", frameworks = {"VideoToolbox", "CoreMedia", "CoreVideo", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "ModelIOBackports", folder = "ModelIO", frameworks = {"ModelIO", "CoreGraphics", "ImageIO", "MobileCoreServices", "Foundation"}, libraries = {"FoundationBackports", "MetalKitBackports"}},
    {name = "GameplayKitBackports", folder = "GameplayKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PDFKitBackports", folder = "PDFKit", frameworks = {"PDFKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "NetworkExtensionBackports", folder = "NetworkExtension", frameworks = {"NetworkExtension", "Foundation", "SystemConfiguration"}, libraries = {"FoundationBackports"}},
}
PACKAGE = "org.revenant.apple-backports"
INSTALL_FOLDER = "/usr/lib/revenant/" .. PACKAGE
COMPATIBLE = {armv7 = {"armv7", "armv7s"}, armv7s = {"armv7s"}, arm64 = {"arm64"}}
NOT_ENCRYPTED = "-Wl,-no_encryption"

function libraries()
    return LIBRARIES
end

local function keeps(opt, name)
    return not opt.libraries or table.contains(opt.libraries, name)
end

local function staged_libraries(opt)
    local staged = {}
    for _, library in ipairs(LIBRARIES) do
        if keeps(opt, library.name) then
            table.insert(staged, library)
        end
    end
    return staged
end

function package_name()
    return PACKAGE
end

function compatible(architecture)
    return COMPATIBLE[architecture] or {architecture}
end

function held_cache(architecture, release)
    for _, candidate in ipairs(compatible(architecture)) do
        local held = dyld.held_source(path.join(dyld.root(), release), candidate)
        if held then
            return held
        end
    end
end

local KEYS, SYMBOLS = {}, {}

local function internal_symbol(name)
    if name:startswith("_OBJC_IVAR_$_") or name:startswith("_OBJC_PROTOCOL_$_") or name:find("$shim", 1, true) then
        return true
    end
    local bare = name:match("^_OBJC_%u*CLASS_%$_(.+)$") or name:match("^_(.+)$") or name
    return bare:startswith("revenant_") or bare:startswith("Revenant")
end

local function symbols_where(file, wanted, kind)
    local memo = kind and KEYS[file] and (KEYS[file] .. kind)
    if memo and SYMBOLS[memo] then
        return SYMBOLS[memo]
    end
    local found = symbols_of(file, wanted)
    if memo then
        SYMBOLS[memo] = found
    end
    return found
end

function symbols_of(file, wanted)
    local data = macho.read(file)
    local found = {}
    for _, image in ipairs(macho.images(data)) do
        if image.symtab then
            local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
            local entry = image.wide and 16 or 12
            for index = 0, nsyms - 1 do
                local strx, kind, _, _, value = string.unpack(image.wide and "<I4BBI2I8" or "<I4BBI2I4", data, image.base + symoff + index * entry + 1)
                if wanted(kind, value) then
                    local finish = data:find("\0", image.base + stroff + strx + 1, true)
                    found[data:sub(image.base + stroff + strx + 1, finish - 1)] = true
                end
            end
        end
    end
    return table.orderkeys(found)
end

local function defined_symbols(file, hidden)
    return symbols_where(file, function (kind)
        return kind & 0xE0 == 0 and kind & 0x0E == 0x0E and (hidden or (kind & 0x10 == 0 and kind & 0x01 ~= 0))
    end, hidden and "hidden" or "defined")
end

local function undefined_symbols(file)
    return symbols_where(file, function (kind, value)
        return kind & 0xE0 == 0 and kind & 0x0E == 0 and kind & 0x01 ~= 0 and value == 0
    end, "undefined")
end

local function exported_symbols(file)
    local found = {}
    for _, symbol in ipairs(defined_symbols(file)) do
        if not internal_symbol(symbol) then
            table.insert(found, symbol)
        end
    end
    return found
end

function seam_symbols(root, library)
    local found = {}
    local folder = path.join(root, library.folder)
    for _, file in ipairs(os.files(path.join(folder, "*"))) do
        if file:endswith(".h") or file:endswith(".m") or file:endswith(".mm") or file:endswith(".c") then
            for line in io.lines(file) do
                local rest = line:match("^%s*REVENANT_SEAM(.*)")
                local name = rest and rest:match("([%a_][%w_]*)%s*%(")
                if name then
                    found["_" .. name] = true
                end
            end
        end
    end
    return found
end

function archive_of(archives, name)
    if not archives then
        return nil
    end
    if archives[name] then
        return archives[name]
    end
    for key, archive in pairs(archives) do
        if (key:match("^(%S+)") or key) == "revenant@" .. name then
            return archive
        end
    end
    return nil
end

local function driver(opt, arguments)
    if opt.cc then
        return opt.cc, arguments
    end
    return "xcrun", table.join({"clang"}, arguments)
end

local function clang(opt, arguments, objective_c)
    local given = {"-target", opt.triple, "-isysroot", opt.sdkdir}
    if objective_c then
        table.insert(given, "-fobjc-arc")
        if dyld.compare_versions(opt.deployment, "5.0") < 0 then
            table.join2(given, {"-Xclang", "-fobjc-runtime-has-weak"})
        end
    end
    table.join2(given, arguments)
    return driver(opt, given)
end

local SCANNED, CONTENT = {}, {}

local function directives(file)
    local found = SCANNED[file]
    if found == nil then
        found = {}
        for line in io.readfile(file):gmatch("[^\n]+") do
            local rest = line:match("^%s*#%s*include_next(.*)$") or line:match("^%s*#%s*include(.*)$") or line:match("^%s*#%s*import(.*)$")
            if rest then
                local open, name = rest:match('^%s*(["<])([^">]+)[">]')
                if not open then
                    found = false
                    break
                end
                table.insert(found, {quoted = open == '"', name = name})
            end
        end
        SCANNED[file] = found
    end
    return found
end

local function content(file)
    CONTENT[file] = CONTENT[file] or hash.strhash128(io.readfile(file))
    return CONTENT[file]
end

local function reached(source, folders)
    local seen, order = {}, {}
    local function visit(file)
        local found = directives(file)
        if not found then
            return false
        end
        for _, include in ipairs(found) do
            local candidates = include.quoted and {path.directory(file)} or {}
            table.join2(candidates, folders)
            for _, folder in ipairs(candidates) do
                local header = path.normalize(path.join(folder, include.name))
                if not seen[header] and os.isfile(header) then
                    seen[header] = true
                    table.insert(order, header)
                    if visit(header) == false then
                        return false
                    end
                end
            end
        end
        return true
    end
    if visit(source) == false then
        return nil
    end
    return order
end

local OWN_TEXT

local function own_text()
    OWN_TEXT = OWN_TEXT or hash.strhash128(io.readfile(path.join(os.scriptdir(), "backports.lua")))
    return OWN_TEXT
end

local ENVIRONMENT = {"CPATH", "C_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJCPLUS_INCLUDE_PATH",
                     "SDKROOT", "DEVELOPER_DIR", "IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET",
                     "CCC_OVERRIDE_OPTIONS", "LIBRARY_PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"}
local function environment()
    local parts = {}
    for _, name in ipairs(ENVIRONMENT) do
        local value = os.getenv(name)
        if value then
            table.insert(parts, name .. "=" .. value)
        end
    end
    return table.concat(parts, "\n")
end

function object_key(opt, program, arguments, source, object)
    if not opt.store or not opt.root then
        return nil
    end
    local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
    local function portable(text)
        local at = text:find(checkout, 1, true)
        return at and text:sub(1, at - 1) .. "@checkout" .. portable(text:sub(at + #checkout)) or text
    end
    local folders = {}
    for index, argument in ipairs(arguments) do
        local folder = argument:match("^%-I(.+)$") or (argument == "-I" and arguments[index + 1])
        if folder then
            folder = path.normalize(path.absolute(folder))
            if folder:startswith(checkout) then
                table.insert(folders, folder)
            end
        end
    end
    local headers = reached(source, folders)
    if not headers then
        return nil
    end
    local parts = {"revenant-object-2", program, environment()}
    for _, argument in ipairs(arguments) do
        table.insert(parts, argument == object and "@object" or portable(argument))
    end
    table.insert(parts, content(source))
    for _, header in ipairs(headers) do
        table.insert(parts, portable(header) .. "=" .. content(header))
    end
    return hash.strhash128(table.concat(parts, "\n"))
end

local function unit(opt, source, object)
    if not source:startswith("/") then
        source = path.join(opt.root, source)
    end
    local objective_c = not source:endswith(".c")
    local arguments = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    if objective_c then
        table.insert(arguments, "-Werror=objc-missing-property-synthesis")
    else
        table.insert(arguments, "-fvisibility=hidden")
    end
    if source:endswith(".mm") then
        table.join2(arguments, {"-fno-rtti", "-fvisibility-inlines-hidden"})
    end
    for _, name in ipairs(table.orderkeys(opt.archives or {})) do
        table.insert(arguments, "-I" .. opt.archives[name].includedir)
    end
    if opt.root then
        local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
        table.insert(arguments, "-fmacro-prefix-map=" .. checkout .. "/=")
    end
    local program, arguments = clang(opt, table.join(arguments, {"-c", source, "-o", object}), objective_c)
    local key = object_key(opt, program, arguments, source, object)
    KEYS[object] = key
    return program, arguments, key and path.join(opt.store, key:sub(1, 2), key .. ".o")
end

local function store_folder(folder)
    try { function () os.mkdir(folder) end }
    assert(os.isdir(folder), "cannot create the store folder " .. folder)
end

local function place(object, stored)
    os.tryrm(object)
    if stored and os.isfile(stored) then
        os.ln(stored, object)
        os.touch(stored)
        return true
    end
    return false
end

function compile_arguments(opt, source)
    local objective_c = not source:endswith(".c")
    local arguments = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    for _, folder in ipairs(opt.includes or {}) do
        table.insert(arguments, "-I" .. folder)
    end
    if opt.root then
        local folder = path.filename(path.directory(source))
        for _, dir in ipairs({path.join(opt.root, ".gen", folder), path.join(opt.root, folder)}) do
            if os.isdir(dir) then
                table.insert(arguments, "-I" .. dir)
            end
        end
    end
    if objective_c then
        table.insert(arguments, "-Werror=objc-missing-property-synthesis")
    else
        table.insert(arguments, "-fvisibility=hidden")
    end
    if source:endswith(".mm") then
        table.join2(arguments, {"-fno-rtti", "-fvisibility-inlines-hidden"})
    end
    for _, name in ipairs(table.orderkeys(opt.archives or {})) do
        table.insert(arguments, "-I" .. opt.archives[name].includedir)
    end
    if opt.root then
        local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
        table.insert(arguments, "-fmacro-prefix-map=" .. checkout .. "/=")
    end
    return arguments, objective_c
end

function compile(opt, source, object)
    local flags, objective_c = compile_arguments(opt, source)
    local program, arguments = clang(opt, table.join(flags, {"-c", source, "-o", object}), objective_c)
    local program, argv = cache.wrapped(program, arguments)
    os.vrunv(program, argv, opt.root and {curdir = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))} or nil)
    if stored then
        store_folder(path.directory(stored))
        local temporary = stored .. "." .. hash.strhash32(object .. os.mclock()) .. ".tmp"
        os.cp(object, temporary)
        os.mv(temporary, stored)
    end
    return true
end

function sweep_store(store, seconds)
    local KEY = string.rep("%x", 32)
    local kinds = {
        {"*", "*.o", "^" .. KEY .. "%.o"},
        {"links/*", "*.dylib", "^" .. KEY .. "%.dylib"},
        {"releases/*", "*.lua", "^" .. KEY .. "%.lua"},
        {"inventories", "*.lua", "^" .. KEY .. "%.lua"}}
    local mark = path.join(store, "swept")
    if not os.isdir(store) or (os.isfile(mark) and os.time() - os.mtime(mark) < 3600) then
        return
    end
    io.writefile(mark, "")
    local now, removed = os.time(), 0
    for _, kind in ipairs(kinds) do
        for _, file in ipairs(os.files(path.join(store, kind[1], kind[2] .. "*"))) do
            local name = path.filename(file)
            if name:match(kind[3] .. "$") or name:match(kind[3] .. "%.%x+%.tmp$") then
                if now - os.mtime(file) > seconds then
                    os.tryrm(file)
                    removed = removed + 1
                end
            end
        end
    end
    return removed
end

local function width(opt)
    if scheduler.co_count() > 1 then
        return 1
    end
    if opt.width then
        return opt.width
    end
    return math.max(1, tonumber(os.getenv("FLEET_HEAVY_CPUS") or "") or 1)
end

local COMPILED

local function compile_all(opt, jobs)
    local count = width(opt)
    local missing = {}
    for _, job in ipairs(jobs) do
        local _, _, stored = unit(job.opt, job.source, job.object)
        if not place(job.object, stored) then
            table.insert(missing, job)
        end
    end
    COMPILED = COMPILED or 0
    if count <= 1 or #missing < 2 then
        for _, job in ipairs(missing) do
            if compile(job.opt, job.source, job.object, job.library) then
                COMPILED = COMPILED + 1
            end
        end
        return
    end
    import("async.runjobs")("backports", function (index)
        local job = missing[index]
        if compile(job.opt, job.source, job.object, job.library) then
            COMPILED = COMPILED + 1
        end
    end, {comax = count, total = #missing})
end

local function sections_of(file)
    local names = {}
    for _, image in ipairs(macho.images(macho.read(file))) do
        for _, section in ipairs(image.sections) do
            names[section.segment .. "," .. section.name] = true
        end
    end
    return names
end

local generated = {}
function generate(root, sdkdir)
    local snapshot = path.join(root, "spec")
    if not os.isdir(snapshot) then
        raise("package root %s has no spec/ snapshot (%s): the generated layer in .gen/ cannot be written", root, snapshot)
    end
    if generated[root] then
        return
    end
    generated[root] = true
    local tree = path.absolute(path.join(root, "..", "..", ".."))
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        raise("the generated layer needs REVENANT_GEN_SDK: the iPhoneOS SDK whose release the spec snapshot is measured on (gen --sdk)")
    end
    os.runv(os.programfile(), {"l", path.join(tree, "tools", "gen.lua"), "gen", "--tree", tree, "--all", "--sdk", sdk})
    if os.isdir(path.join(root, "Intents")) then
        local workspace = import("workspace", {rootdir = path.join(tree, "modules"), anonymous = true})
        local arguments = {"l", path.join(tree, "tools", "intents", "objects.lua"), "--sdk", sdk,
            "--out", path.join(root, ".gen", "Intents"), "--work", workspace.run("intents-generation")}
        if sdkdir then
            table.join2(arguments, {"--port-sdk", sdkdir})
        end
        os.runv(os.programfile(), arguments)
    end
    if os.isfile(path.join(root, "spec", "ImageIO", "names.tsv")) then
        os.runv(os.programfile(), {"l", path.join(tree, "tools", "gen", "imageio_names.lua"), "", tree, "--objects"})
    end
end

function sources(root, library)
    local found = table.join(os.files(path.join(root, library.folder, "*.m")), os.files(path.join(root, library.folder, "*.mm")),
                             os.files(path.join(root, library.folder, "*.c")), os.files(path.join(root, ".gen", library.folder, "*.m")),
                             os.files(path.join(root, ".gen", library.folder, "*.c")))
    for _, folder in ipairs(library.generated or {}) do
        found = table.join(found, os.files(path.join(root, ".gen", folder, "*.m")))
    end
    byteorder.sort(found)
    return found
end

local function conforms_in(text, wanted, found, filename)
    for declaration in text:gmatch("@interface%s+[%w_]+[^\n]*") do
        local list = declaration:match("<([^>]*)>%s*$") or declaration:match("<([^>]*)>")
        if list then
            for conformed in list:gmatch("[%w_]+") do
                if wanted[conformed] and not found[conformed] then found[conformed] = filename end
            end
        end
    end
    for declaration in text:gmatch("@protocol%s+[%w_]+[^\n]*") do
        local list = declaration:match("<([^>]*)>%s*$") or declaration:match("<([^>]*)>")
        if list then
            for conformed in list:gmatch("[%w_]+") do
                if wanted[conformed] and not found[conformed] then found[conformed] = filename end
            end
        end
    end
    return found
end

function conforming_protocols(opt, library, names, found)
    found = found or {}
    local wanted = {}
    for name in pairs(names) do wanted[name] = true end
    for _, file in ipairs(os.files(path.join(opt.root, library.folder, "*"))) do
        local filename = path.filename(file)
        if filename:endswith(".h") or filename:endswith(".m") or filename:endswith(".c") or filename:endswith(".mm") then
            local text = io.readfile(file)
            if text then conforms_in(text, wanted, found, library.folder .. "/" .. filename) end
        end
    end
    if not opt.sdkdir then return found end
    for _, framework in ipairs(library.frameworks or {}) do
        for _, file in ipairs(os.files(path.join(opt.sdkdir, "System/Library/Frameworks", framework .. ".framework/Headers/*.h"))) do
            local text = io.readfile(file)
            if text then conforms_in(text, wanted, found, framework .. ".framework/Headers/" .. path.filename(file)) end
        end
    end
    return found
end

function protocol_sources(opt, library, folder, umbrella)
    local root = opt.root
    local bands, floors_of = {}, {}
    for _, file in ipairs(table.join(os.files(path.join(root, "registry", library.folder, "*.json")),
                                 os.files(path.join(root, "registry", library.folder .. ".json")))) do
        local held = json.loadfile(file)
        if type(held) == "table" and held.entries == nil and #held == 0 then
            held = {entries = {}}
        end
        for _, entry in ipairs((held.entries or held)) do
            if entry.kind == "protocol" and entry.status == "implemented" then
                local introduced = entry.introduced or "0"
                bands[introduced] = bands[introduced] or {}
                table.insert(bands[introduced], entry.api)
                if entry.minimum and (not floors_of[introduced] or dyld.compare_versions(entry.minimum, floors_of[introduced]) > 0) then
                    floors_of[introduced] = entry.minimum
                end
            end
        end
    end
    local wanted = {}
    for _, names in pairs(bands) do
        for _, name in ipairs(names) do wanted[name] = true end
    end
    local carried = conforming_protocols(opt, library, wanted)
    local written, floor = {}, {}
    for introduced, names in pairs(bands) do
        byteorder.sort(names)
        local file = path.join(folder, library.name .. "Protocols" .. introduced .. ".m")
        local text = string.format([[// %sProtocols%s.m — written by modules/apple/backports.lua, not by hand.
// Every @protocol() below is named so clang emits __OBJC_PROTOCOL_$_<name> into this object, which is the
// metadata the release carries for that protocol in %s.framework itself. One file per release the rows
// arrived in, so every symbol here first appears in one release and release-split is clean.
// A protocol this library's own sources already emit is NOT named here, and the comment says which file
// emits it: naming it in both places is what two definers of one symbol meant.
#import "Revenant%sProtocols.h"

static void revenant_%s_protocols(void) __attribute__((used));
static void revenant_%s_protocols(void)
{
]], library.name, introduced, library.name, library.folder, library.name, library.name)
        for _, name in ipairs(names) do
            if carried[name] then
                text = text .. string.format("    // __OBJC_PROTOCOL_$_%s is emitted by %s\n", name, carried[name])
            else
                text = text .. string.format("    (void)@protocol(%s);\n", name)
            end
        end
        text = text .. "}\n"
        io.writefile(file, text)
        table.insert(written, file)
        floor[file] = floors_of[introduced]
    end
    byteorder.sort(written)
    return written, floor
end

local function names_a_class(symbols)
    for _, symbol in ipairs(symbols) do
        if symbol:startswith("_OBJC_CLASS_$_") or symbol:startswith("_OBJC_METACLASS_$_") or symbol:startswith("_OBJC_IVAR_$_") then
            return true
        end
    end
    return false
end

function band(release_exports, objects, arrived, range)
    local kept, reexported, left = {}, {}, {}
    for _, object in ipairs(objects) do
        local minimum = range and range.minimums[object]
        local ends = range and range.maximums and range.maximums[object]
        local symbols = exported_symbols(object)
        local present = {}
        for _, symbol in ipairs(symbols) do
            if release_exports[symbol] then
                table.insert(present, symbol)
            end
        end
        if minimum and dyld.compare_versions(range.release, minimum) < 0 then
            table.insert(left, object)
        elseif ends and dyld.compare_versions(range.release, ends) >= 0 then
            table.insert(left, object)
        elseif #present == 0 or (arrived and not names_a_class(present) and arrived(object)) then
            table.insert(kept, object)
        elseif #present == #symbols then
            table.join2(reexported, symbols)
        else
            local absent = {}
            for _, symbol in ipairs(symbols) do
                if not release_exports[symbol] then
                    table.insert(absent, symbol)
                end
            end
            raise("%s defines %s, which the release already exports, together with %s, which it does not; an object carries API that arrived in one release, so split it",
                  path.filename(object), table.concat(present, " "), table.concat(absent, " "))
        end
    end
    return kept, reexported, left
end

local function compiled(opt)
    local attach = path.join(opt.builddir, "objects", "attach.o")
    os.mkdir(path.directory(attach))
    io.writefile(path.join(opt.builddir, "objects", "sdkdir"), opt.sdkdir)
    compile(opt, path.join(opt.root, "attach.c"), attach)
    local placed, windows_of = floors(opt)
    windows_of = windows_of or {}
    local objects, origins, minimums, maximums = {}, {}, {}, {}
    local pending = {}
    for _, library in ipairs(LIBRARIES) do
        objects[library.name] = {}
    end
    for _, library in ipairs(staged_libraries(opt)) do
        local generated = path.join(opt.builddir, "protocols", library.folder)
        os.mkdir(generated)
        local written, floor = protocol_sources(opt, library, generated, library.frameworks[1])
        for _, source in ipairs(written) do
            local object = path.join(opt.builddir, "objects", library.folder, "protocols", path.filename(source) .. ".o")
            os.mkdir(path.directory(object))
            local job = table.join(opt, {includes = {path.join(opt.root, library.folder)}})
            local minimum = floor[source]
            if minimum and dyld.compare_versions(minimum, opt.deployment) > 0 then
                job = table.join(job, {deployment = minimum, triple = opt.architecture .. "-apple-ios" .. minimum})
                minimums[object] = minimum
            end
            pending[#pending + 1] = {opt = job, source = source, object = object}
            table.insert(objects[library.name], object)
            origins[object] = source
        end
        for _, source in ipairs(sources(opt.root, library)) do
            local object
            if placed[source] then
                object = placed[source].object
                minimums[object] = placed[source].minimum
            else
                object = path.join(opt.builddir, "objects", library.folder, path.basename(source) .. ".o")
                os.mkdir(path.directory(object))
                table.insert(pending, {opt = opt, source = source, object = object,
                                       library = library})
            end
            table.insert(objects[library.name], object)
            origins[object] = source
        end
    end
    compile_all(opt, pending)
    for object, source in pairs(origins) do
        maximums[object] = windows_of[source]
    end
    return attach, objects, origins, minimums, maximums
end

local function exported_through(release, install, seen)
    local found = release.libraries[install]
    if not found or seen[install] then
        return {}
    end
    seen[install] = true
    local names = table.keys(found.exports)
    for _, other in ipairs(found.reexports or {}) do
        table.join2(names, exported_through(release, other, seen))
    end
    return names
end

local function provides(release, install, symbol, seen)
    local found = release.libraries[install]
    if not found or seen[install] then
        return false
    end
    seen[install] = true
    if found.exports[symbol] then
        return true
    end
    for _, other in ipairs(found.reexports or {}) do
        if provides(release, other, symbol, seen) then
            return true
        end
    end
    return false
end

local function write_stub(architecture, folder, install, symbols, classes)
    local target = architecture .. "-ios"
    local file = path.join(folder, path.basename(install) .. ".tbd")
    io.writefile(file, table.concat({"--- !tapi-tbd", "tbd-version: 4", "targets: [ " .. target .. " ]", "install-name: '" .. install .. "'", "exports:",
                                     "  - targets: [ " .. target .. " ]", "    symbols: [ " .. table.concat(symbols, ", ") .. " ]",
                                     "    objc-classes: [ " .. table.concat(classes, ", ") .. " ]", "..."}, "\n") .. "\n")
    return file
end

function stubs(architecture, library, reexported, releases, folder)
    local preferred = {}
    for index, framework in ipairs(library.frameworks) do
        preferred[framework] = index
    end
    local chosen = {}
    for _, symbol in ipairs(reexported) do
        local candidates = {}
        for install in pairs(releases[1].libraries) do
            local everywhere = true
            for _, release in ipairs(releases) do
                everywhere = everywhere and provides(release, install, symbol, {})
            end
            if everywhere then
                table.insert(candidates, install)
            end
        end
        if #candidates == 0 then
            raise("no library exports %s in every release a band of %s is checked against", symbol, library.name)
        end
        table.sort(candidates, function (a, b)
            local left, right = preferred[path.basename(a)] or math.huge, preferred[path.basename(b)] or math.huge
            if left ~= right then
                return left < right
            end
            return byteorder.less(a, b)
        end)
        chosen[candidates[1]] = chosen[candidates[1]] or {}
        table.insert(chosen[candidates[1]], symbol)
    end
    local files = {}
    for _, install in ipairs(table.orderkeys(chosen)) do
        local symbols, classes = {}, {}
        for _, symbol in ipairs(exported_through(releases[1], install, {})) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                table.insert(classes, class)
            elseif not symbol:startswith("_OBJC_METACLASS_$_") then
                table.insert(symbols, symbol)
            end
        end
        byteorder.sort(symbols)
        byteorder.sort(classes)
        table.insert(files, write_stub(architecture, folder, install, symbols, classes))
    end
    return files
end

function framework_install_path(library, releases)
    local found = {}
    for _, framework in ipairs(library.frameworks) do
        local suffix = "/" .. framework .. ".framework/" .. framework
        local install
        for candidate in pairs(releases[1].libraries) do
            if candidate:endswith(suffix) then
                install = install or candidate
            end
        end
        if install then
            local everywhere = true
            for _, release in ipairs(releases) do
                everywhere = everywhere and release.libraries[install] ~= nil
            end
            if not everywhere then
                raise("%s is at %s in one release this band covers and not in another: a band spanning both needs the same install path in every release it covers, or it should be split at the release where the framework moved",
                      framework, install)
            end
            found[framework] = install
        end
    end
    return found
end

function reexports(deployment)
    return dyld.compare_versions(deployment, "4.2") >= 0
end

local INVENTORIES = {}

local INVENTORY_STORE

local function release_inventory(cache)
    if not INVENTORIES[cache] and INVENTORY_STORE and os.isfile(cache) then
        local parts = {"revenant-inventory-1", cache, tostring(os.filesize(cache)), tostring(os.mtime(cache))}
        for _, name in ipairs({"objc.lua", "dyld.lua", "macho.lua"}) do
            table.insert(parts, hash.strhash128(io.readfile(path.join(os.scriptdir(), name))))
        end
        local key = hash.strhash128(table.concat(parts, "\n"))
        local file = path.join(INVENTORY_STORE, "inventories", key .. ".lua")
        local saved = os.isfile(file) and io.load(file)
        if saved then
            os.touch(file)
        else
            saved = objc.inventory(cache)
            store_folder(path.directory(file))
            local temporary = file .. "." .. hash.strhash32(cache .. os.mclock()) .. ".tmp"
            io.save(temporary, saved)
            os.mv(temporary, file)
        end
        INVENTORIES[cache] = saved
    end
    INVENTORIES[cache] = INVENTORIES[cache] or objc.inventory(cache)
    return INVENTORIES[cache]
end

local function carried_classes(cache)
    return release_inventory(cache).classes
end

function cxx_runtime(opt, library, releases, folder)
    local libcxx, libstdcxx = "/usr/lib/libc++.1.dylib", "/usr/lib/libstdc++.6.dylib"
    local without = false
    for _, release in ipairs(releases) do
        without = without or not release.libraries[libcxx]
    end
    if not without then
        return {"-lc++"}
    end
    for _, release in ipairs(releases) do
        if not release.libraries[libstdcxx] then
            raise("%s keeps C++ objects, and a release of its band has neither %s nor %s", library.name, libcxx, libstdcxx)
        end
    end
    local symbols = exported_through(releases[1], libstdcxx, {})
    byteorder.sort(symbols)
    os.mkdir(folder)
    return {write_stub(opt.architecture, folder, libstdcxx, symbols, {})}
end

function linked_key(opt, program, arguments, real_paths, outputdir, output)
    if not opt.store then
        return nil
    end
    local parts = {"revenant-link-2", program, environment(), own_text()}
    local folders = {{outputdir, "@outputdir"}, {opt.builddir, "@builddir"}}
    for _, argument in ipairs(arguments) do
        local text = argument
        for _, folder in ipairs(folders) do
            if folder[1] then
                local at = text:find(folder[1], 1, true)
                while at do
                    text = text:sub(1, at - 1) .. folder[2] .. text:sub(at + #folder[1])
                    at = text:find(folder[1], at + #folder[2], true)
                end
            end
        end
        table.insert(parts, text)
        local file = argument:match("^%-Wl,%-[%w_]+,(.+)$") or argument
        if file ~= output and os.isfile(file) then
            table.insert(parts, KEYS[file] or hash.strhash128(io.readfile(file)))
        end
        local other = argument:match("^%-l(.+)$")
        if other then
            local dylib = path.join(outputdir, "lib" .. other .. ".dylib")
            table.insert(parts, os.isfile(dylib) and hash.strhash128(io.readfile(dylib)) or "none")
        end
    end
    for _, framework in ipairs(table.orderkeys(real_paths)) do
        table.insert(parts, framework .. "=" .. real_paths[framework])
    end
    return hash.strhash128(table.concat(parts, "\n"))
end

local function link(opt, library, attach, objects, releases, outputdir, checked)
    local release = checked and checked.release or opt.deployment
    local kept, reexported, left = band(releases[1].exports, objects, checked and later_than(opt, checked.release), {release = release, minimums = opt.minimums or {}, maximums = opt.maximums or {}})
    if #left > 0 then
        local named = {}
        for _, object in ipairs(left) do
            table.insert(named, string.format("%s (%s)", path.filename(opt.origins[object]), (opt.minimums or {})[object] or "no minimum"))
        end
        cprint("${color.warning}note:${clear} the band for iOS %s leaves %d objects of %s out of their registry window (below the minimum or at the maximum): %s",
               release, #named, library.name, table.concat(named, " "))
    end
    if not reexports(opt.deployment) then
        reexported = {}
    end
    if checked then
        local told = duplicated(kept, carried_classes(checked.cache))
        if #told > 0 then
            raise("the band for iOS %s keeps %s, which the release has and does not export: the band cannot leave a class out that nothing says is there, and a process would hold two classes of that name, one of which the runtime picks. Ask the release for the class where it has one, or carry it under a name of Revenant's own.",
                  checked.release, table.concat(told, " "))
        end
    end
    local output = path.join(outputdir, "lib" .. library.name .. ".dylib")
    os.mkdir(outputdir)
    local arguments = {"-target", opt.triple, "-isysroot", opt.sdkdir, "-fuse-ld=" .. opt.ld, "-fobjc-arc",
                       "-dynamiclib", "-Wno-incompatible-sysroot", NOT_ENCRYPTED,
                       "-install_name", path.join(INSTALL_FOLDER, path.filename(output)),
                       "-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__revenant_catlist", "-o", output, attach}
    table.join2(arguments, kept)
    if #reexported > 0 then
        local folder = path.join(opt.builddir, "stubs", path.filename(outputdir), library.name)
        os.tryrm(folder)
        os.mkdir(folder)
        table.join2(arguments, stubs(opt.architecture, library, reexported, releases, folder))
    end
    for _, other in ipairs(library.libraries or {}) do
        table.join2(arguments, {"-L" .. outputdir, "-l" .. other})
    end
    local cxx = false
    for _, object in ipairs(kept) do
        cxx = cxx or opt.origins[object]:endswith(".mm")
    end
    local wanted_archives = {}
    for _, name in ipairs(library.archives or {}) do
        wanted_archives[name] = cxx
    end
    for _, name in ipairs(library and library.c_archives or {}) do
        wanted_archives[name] = true
    end
    for _, language in ipairs(table.orderkeys(wanted_archives)) do
        if wanted_archives[language] then
            local archive = archive_of(opt.archives, language)
            if not archive then
                raise("%s links the static library of the package %s, and the build was given none: pass archives = {%s = {linkdir = ..., link = ..., includedir = ...}}, from the package's installdir",
                      library.name, language, language)
            end
            table.insert(arguments, path.join(archive.linkdir, "lib" .. archive.link .. ".a"))
        end
    end
    if cxx then
        table.join2(arguments, cxx_runtime(opt, library, releases, path.join(opt.builddir, "stubs", path.filename(outputdir), library.name)))
    end
    for _, name in ipairs(library.system or {}) do
        table.insert(arguments, "-l" .. name)
    end
    local real_paths = framework_install_path(library, releases)
    local absent = {}
    for _, framework in ipairs(library.frameworks) do
        if real_paths[framework] then
            table.join2(arguments, {"-framework", framework})
        else
            table.insert(absent, framework)
        end
    end
    if #absent > 0 then
        cprint("${color.warning}note:${clear} the band for iOS %s links %s without %s, which the release does not have", release, library.name, table.concat(absent, " "))
    end
    if #reexported > 0 then
        local list = path.join(opt.builddir, library.name .. ".reexported")
        io.writefile(list, table.concat(reexported, "\n") .. "\n")
        table.insert(arguments, "-Wl,-reexported_symbols_list," .. list)
    end
    local internal = {}
    local seams = opt.root and seam_symbols(opt.root, library) or {}
    for _, object in ipairs(kept) do
        for _, symbol in ipairs(defined_symbols(object)) do
            if internal_symbol(symbol) and not seams[symbol] then
                table.insert(internal, symbol)
            end
        end
    end
    if #internal > 0 then
        local list = path.join(opt.builddir, library.name .. ".internal")
        io.writefile(list, table.concat(table.unique(internal), "\n") .. "\n")
        table.insert(arguments, "-Wl,-unexported_symbols_list," .. list)
    end
    local program, argv = driver(opt, arguments)
    local stored = linked_key(opt, program, argv, real_paths, outputdir, output)
    stored = stored and path.join(opt.store, "links", stored:sub(1, 2), stored .. ".dylib")
    if stored and os.isfile(stored) then
        os.cp(stored, output)
        os.touch(stored)
    else
        os.vrunv(program, argv)
        local embedded
        for _, framework in ipairs(library.frameworks) do
            local real = real_paths[framework]
            if real then
                embedded = embedded or macho.images(macho.read(output))[1].libraries
                local suffix = "/" .. framework .. ".framework/" .. framework
                for _, current in ipairs(embedded) do
                    if current:endswith(suffix) and current ~= real then
                        os.vrunv("xcrun", {"install_name_tool", "-change", current, real, output})
                    end
                end
            end
        end
        if stored then
            store_folder(path.directory(stored))
            local temporary = stored .. "." .. hash.strhash32(output .. os.mclock()) .. ".tmp"
            os.cp(output, temporary)
            os.mv(temporary, stored)
        end
    end
    if sections_of(output)["__DATA,__objc_catlist"] then
        raise("%s kept __objc_catlist: the linker did not rename it, so the runtime would attach every backported method over the system's own", output)
    end
    local held = {}
    for _, symbol in ipairs(defined_symbols(output)) do
        held[symbol] = true
    end
    local missing = {}
    for _, object in ipairs(kept) do
        for _, symbol in ipairs(exported_symbols(object)) do
            if not held[symbol] then
                table.insert(missing, symbol)
            end
        end
    end
    if #missing > 0 then
        byteorder.sort(missing)
        raise("%s holds %d API it does not export, and a port that links against it takes the weak import of the release instead, which is NULL there: %s",
              output, #missing, table.concat(table.slice(missing, 1, math.min(8, #missing)), " ") .. (#missing > 8 and (" and %d more"):format(#missing - 8) or ""))
    end
    return output
end

local function loaded(cache, architecture)
    local release = dyld.load(cache)
    if not table.contains(compatible(architecture), release.architecture) then
        raise("%s holds %s libraries, which an %s build does not run on", cache, release.architecture, architecture)
    end
    return release
end

local function loaded_images(release, binaries, binary, architecture)
    local own = {}
    for _, other in ipairs(binaries) do
        own[path.join(INSTALL_FOLDER, path.filename(other))] = other
    end
    local seen, pending = {}, {path.join(INSTALL_FOLDER, path.filename(binary))}
    while #pending > 0 do
        local install = table.remove(pending)
        if not seen[install] then
            seen[install] = true
            local dependents = release.libraries[install] and release.libraries[install].dependents
            if own[install] then
                for _, image in ipairs(macho.images(macho.read(own[install]))) do
                    if image.architecture == architecture then
                        dependents = image.libraries
                    end
                end
            end
            table.join2(pending, dependents or {})
        end
    end
    return seen
end

function unattached_categories(release, inventory, binaries, architecture)
    local defined, aliases = {}, {}
    for _, binary in ipairs(binaries) do
        for _, symbol in ipairs(defined_symbols(binary, true)) do
            defined[symbol] = true
        end
    end
    local found = {}
    for _, binary in ipairs(binaries) do
        local images
        for proxy, name in pairs(objc.binary_aliases(binary, architecture) or {}) do
            aliases[proxy] = name
            local carried = inventory.classes[name]
            images = images or loaded_images(release, binaries, binary, architecture)
            if not (carried and carried.image and images[carried.image]) and not defined["_OBJC_CLASS_$_" .. proxy] then
                table.insert(found, string.format("%s, which %s aliases in %s, and which no release this band is built for carries where the library's loader can give it what the alias adds", name, proxy, path.filename(binary)))
            end
        end
    end
    for _, binary in ipairs(binaries) do
        for _, category in ipairs(objc.binary_categories(binary, architecture) or {}) do
            local bound = category.bound and category.bound:match("^_OBJC_CLASS_%$_(.+)$")
            local class = category.class and (aliases[category.class] or category.class) or bound
            local attached = category.class ~= nil or (category.bound ~= nil and (release.exports[category.bound] or defined[category.bound]))
            if not attached then
                local members = {}
                for kind, sign in pairs({instance = "-", class_methods = "+"}) do
                    for selector in pairs(category[kind]) do
                        table.insert(members, sign .. selector:sub(2))
                    end
                end
                byteorder.sort(members)
                local named = string.format("%s(%s: %s) in %s", class or "a class this check cannot name", category.name or "?",
                                            table.concat(members, " "), path.filename(binary))
                local carried = class and inventory.classes[class]
                if carried and carried.image then
                    table.insert(found, string.format("%s (the release carries %s in %s without exporting it: alias it through revenant_alias.h)",
                                                      named, class, carried.image))
                else
                    table.insert(found, named)
                end
            end
        end
    end
    byteorder.sort(found)
    return found
end

function check_categories(release, inventory, binaries, architecture, version)
    local found = unattached_categories(release, inventory, binaries, architecture)
    if #found > 0 then
        raise("categories whose class neither iOS %s nor the package exports, and aliases whose class it does not carry in an image the library loads, so the library's loader has no class to give what they add and nothing of it is there: %s",
              version, table.concat(found, " "))
    end
end

local function class_image(inventory, name)
    local class = inventory and inventory.classes and inventory.classes[name]
    return class and class.image or false
end

local function members_of(inventory, classes)
    local found = {}
    for name, class in pairs(inventory and inventory.classes or {}) do
        if classes(name) then
            for kind, sign in pairs({instance = "-", class = "+"}) do
                for selector in pairs(class[kind]) do
                    local plain = selector:sub(2)
                    if not plain:startswith(".cxx_") and plain ~= "load" and not internal_symbol(plain) then
                        table.insert(found, string.format("%s[%s %s]", sign, name, plain))
                    end
                end
            end
        end
    end
    return found
end

function added_members(inventory, ours)
    return members_of(inventory, function (name)
        return not class_image(inventory, name) and not ours[name]
    end)
end

function carried_api(inventory, declared, documented)
    local found = members_of(inventory, function (name)
        return not name:startswith("Revenant")
    end)
    declared = declared or {}
    documented = documented or {}
    for name, protocol in pairs(inventory and inventory.protocols or {}) do
        if declared[name] and not name:startswith("Revenant") then
            for kind, sign in pairs({instance = "-", class = "+"}) do
                for selector in pairs(protocol[kind] or {}) do
                    local plain = selector:sub(2)
                    local spelling = string.format("%s[%s %s]", sign, name, plain)
                    if documented[spelling] and not plain:startswith(".cxx_") and plain ~= "load"
                       and not internal_symbol(plain) then
                        table.insert(found, spelling)
                    end
                end
            end
        end
    end
    return found
end


function surface(binaries, architecture, declared, documented)
    local found = {classes = {}, members = {}, symbols = {}, defined = {}, registered = {}, answered = {}, protocols = {}}
    for _, binary in ipairs(binaries) do
        local ours = {}
        if macho.imported_symbols(binary, architecture)["objc_allocateClassPair"] then
            for literal in pairs(macho.text_literals(binary, architecture)) do
                found.registered[literal] = true
            end
        end
        for _, symbol in ipairs(exported_symbols(binary)) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                ours[class] = true
                found.classes[class] = true
            elseif not symbol:startswith("_OBJC_METACLASS_$_") and not symbol:startswith("_OBJC_IVAR_$_") then
                found.symbols[symbol:sub(2)] = true
                found.defined["_" .. symbol:sub(2)] = true
            end
        end
        local inventory = objc.binary_inventory(binary, architecture)
        for symbol in pairs(found.defined) do
            local proto = symbol:match("^_OBJC_PROTOCOL_%$_(.+)$") or symbol:match("^_OBJC_LABEL_PROTOCOL_%$_(.+)$")
            if proto and not proto:startswith("Revenant") then
                found.protocols[proto] = true
            end
        end
        for name, class in pairs(inventory and inventory.classes or {}) do
            if class.image and not name:startswith("Revenant") then
                found.classes[name] = true
            end
            if (class.image or (found.protocols or {})[name]) and not name:startswith("Revenant") then
                found.classes[name] = true
            end
            if not name:startswith("Revenant") then
                for kind, sign in pairs({instance = "-", class = "+"}) do
                    for selector in pairs(class[kind]) do
                        found.answered[string.format("%s[%s %s]", sign, name, selector:sub(2))] = true
                    end
                end
            end
        end
        for _, member in ipairs(carried_api(inventory, declared, documented)) do
            found.members[member] = true
        end
    end
    return found
end

local STATUSES = {implemented = true, absent = true, ignored = true, owed = true}

local function accessor_of(api)
    local sign, owner, name = api:match("^([-+])%[([%w_]+) ([%w_]+)%]$")
    if sign then
        return owner .. "." .. name
    end
    return api:match("^([%u][%w_]*)%.([%w_]+)$") and api
end

function registry(root)
    local listed, told, incomplete, frameworks = {}, {}, {}, {}
    local unlibraried = {}
    local files = table.join(os.files(path.join(root, "registry", "*.json")), os.files(path.join(root, "registry", "*", "*.json")))
    byteorder.sort(files)
    for _, file in ipairs(files) do
        local folder = path.filename(path.directory(file))
        local named = folder == "registry" and path.filename(file) or folder .. "/" .. path.filename(file)
        named = "registry/" .. named
        frameworks[folder == "registry" and path.basename(file) or folder] = true
        local held = json.decode(io.readfile(file))
        for _, entry in ipairs(held.entries or held) do
            if told[entry.api] then
                table.insert(incomplete, entry.api .. " is named by both " .. told[entry.api] .. " and " .. named)
            end
            told[entry.api] = named
            listed[entry.api] = entry
            local plain = entry.api:gsub("%(%)$", "")
            if (entry.kind == "method" or entry.kind == "property") and not (plain:match("^[-+]%[[%w_]+ .+%]$") or plain:match("^[%w_]+%.[%w_]+$")) then
                table.insert(incomplete, entry.api .. " is a " .. entry.kind .. " not spelled -[Class selector:], +[Class selector:] or Class.name")
            elseif (entry.kind == "class" or entry.kind == "protocol") and not plain:match("^[%u_][%w_]*$") then
                table.insert(incomplete, entry.api .. " is a " .. entry.kind .. " spelled " .. entry.api ..
                                          ", and a " .. entry.kind .. " is named by its interface or its protocol, not by a member")
            end
            if not STATUSES[entry.status] then
                table.insert(incomplete, entry.api .. " says " .. tostring(entry.status) .. ", which is not one of the four answers")
            elseif entry.status == "absent" and entry.maximum == nil then
                table.insert(incomplete, entry.api .. " is absent without a release window (maximum): absent is the release's own window, and a decision not to build the API is owed")
            elseif entry.status ~= "implemented" then
                if not entry.effect then
                    table.insert(incomplete, entry.api .. " is " .. entry.status .. " without an effect")
                elseif entry.status ~= "ignored" and not entry.reason then
                    table.insert(incomplete, entry.api .. " is " .. entry.status .. " without a reason")
                elseif entry.status == "ignored" and not entry.facts then
                    table.insert(incomplete, entry.api .. " is ignored without a file of facts")
                end
            end
        end
    end
    local built = {}
    for _, library in ipairs(LIBRARIES) do
        built[library.folder] = true
    end
    local index = {}
    for _, file in ipairs(os.files(path.join(root, ".gen", "*", "rows.tsv"))) do
        index[path.filename(path.directory(file))] = file
    end
    local read = {}
    for _, folder in ipairs(byteorder.keys(index)) do
        if built[folder] then
            table.insert(read, folder)
        else
            local rows = -1
            for _ in io.readfile(index[folder]):gmatch("[^\n]+") do
                rows = rows + 1
            end
            if rows > 0 then
                table.insert(unlibraried, {folder = folder, rows = rows})
            end
        end
    end
    for _, folder in ipairs(read) do
        local file = index[folder]
        local named = ".gen/" .. folder .. "/rows.tsv"
        frameworks[folder] = true
        local header
        for line in io.readfile(file):gmatch("[^\n]+") do
            local cells = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(cells, cell)
            end
            if not header then
                header = cells
            else
                local row = {}
                for column, name in ipairs(header) do
                    row[name] = cells[column]
                end
                local source = row.source ~= "" and row.source or nil
                local text = source and os.isfile(path.join(root, source)) and io.readfile(path.join(root, source)) or nil
                local pattern = "%f[%w_]" .. row.api:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "%f[^%w_]"
                if row.owner ~= "generated" then
                    table.insert(incomplete, row.api .. " is in " .. named .. " with owner " .. tostring(row.owner) .. ", not generated")
                elseif row.status ~= "implemented" then
                    table.insert(incomplete, row.api .. " is in " .. named .. " as " .. tostring(row.status) .. "; a generated row is implemented")
                elseif not source then
                    table.insert(incomplete, row.api .. " is a generated row with no source")
                elseif not text then
                    table.insert(incomplete, row.api .. " is a generated row whose source " .. source .. " does not exist")
                elseif not text:find(pattern) then
                    table.insert(incomplete, row.api .. " is a generated row, but its source " .. source .. " does not define it")
                end
                if told[row.api] then
                    table.insert(incomplete, row.api .. " is named by both " .. told[row.api] .. " and " .. named)
                end
                told[row.api] = named
                listed[row.api] = {api = row.api, kind = row.kind, introduced = row.introduced, minimum = row.minimum,
                                   maximum = row.maximum, status = row.status, facts = row.facts, source = row.source,
                                   owner = row.owner, declhash = row.declhash}
            end
        end
    end
    local told_pair = {}
    for api, entry in pairs(listed) do
        local other = accessor_of(api)
        local twin = other and other ~= api and listed[other] or nil
        if twin and twin.status ~= entry.status then
            local pair = api < other and (api .. " " .. other) or (other .. " " .. api)
            if not told_pair[pair] then
                told_pair[pair] = true
                table.insert(incomplete, string.format("%s is %s and %s is %s, and they are one API in two spellings (%s and %s), which the port's headers would carry and lower together",
                                                      api, entry.status, other, twin.status, told[api], told[other]))
            end
        end
    end
    return listed, incomplete, byteorder.keys(frameworks), unlibraried
end

local function property_of(selector)
    local found = {}
    local setter = selector:match("^set(%u[%w_]*):$")
    if setter then
        table.insert(found, setter:sub(1, 1):lower() .. setter:sub(2))
    end
    local getter = selector:match("^is(%u[%w_]*)$")
    if getter then
        table.insert(found, getter:sub(1, 1):lower() .. getter:sub(2))
    end
    local acronym = selector:match("^is(%l%u[%w_]*)$")
    if acronym then
        table.insert(found, acronym)
    end
    local literal = selector:match("^([%w_]+)$")
    if literal then
        table.insert(found, literal)
    end
    return found
end

spellings = function(api)
    local plain = api:gsub("%(%)$", "")
    local found = {[plain] = true, [plain .. "()"] = true}
    local class, member = plain:match("^([%u][%w_]*)%.(.+)$")
    if class then
        local accessors = {member, "set" .. member:sub(1, 1):upper() .. member:sub(2) .. ":"}
        if member:match("^[%a][%w_]*$") and not member:match("^is%u") then
            table.insert(accessors, "is" .. member:sub(1, 1):upper() .. member:sub(2))
        end
        if member:match("^%l%u[%w_]*$") then
            table.insert(accessors, "is" .. member)
        end
        for _, selector in ipairs(accessors) do
            found[string.format("-[%s %s]", class, selector)] = true
            found[string.format("+[%s %s]", class, selector)] = true
        end
        for _, property in ipairs(property_of(member)) do
            found[class .. "." .. property] = true
        end
    end
    local sign, owner, selector = plain:match("^([-+])%[([%w_]+) (.+)%]$")
    if sign then
        found[owner .. "." .. selector] = true
        for _, property in ipairs(property_of(selector)) do
            found[owner .. "." .. property] = true
        end
    end
    return found
end

local ORDER = {ignored = 0, owed = 1, absent = 2}

function advice(root, used)
    local listed = registry(root)
    local found = {}
    for api, entry in pairs(listed) do
        if ORDER[entry.status] then
            for spelling in pairs(spellings(api)) do
                local selector = spelling:match("^[-+]%[[%w_]+ (.+)%]$")
                if used[spelling] or (selector and used[selector]) then
                    found[api] = entry
                end
            end
        end
    end
    local named = table.orderkeys(found)
    table.sort(named, function (a, b)
        if ORDER[found[a].status] ~= ORDER[found[b].status] then
            return ORDER[found[a].status] < ORDER[found[b].status]
        end
        return byteorder.less(a, b)
    end)
    local advised = {}
    for _, api in ipairs(named) do
        table.insert(advised, {api = api, status = found[api].status, effect = found[api].effect, introduced = found[api].introduced})
    end
    return advised
end

local function carried_by_release(entry, inventory)
    local function has(class, selector, sign)
        local wanted = sign == "-" and "instance" or "class"
        local seen = {}
        while class ~= nil and inventory.classes[class] ~= nil and not seen[class] do
            seen[class] = true
            local carried = inventory.classes[class]
            if carried[wanted]["-" .. selector] ~= nil then
                return true
            end
            class = carried.superclass
        end
        return false
    end
    if entry.kind == "class" then
        return inventory.classes[entry.api] ~= nil
    elseif entry.kind == "protocol" then
        return nil
    elseif entry.kind == "method" then
        local sign, class, selector = entry.api:match("^([-+])%[([%w_]+) (.+)%]$")
        if sign ~= nil and inventory.classes[class] == nil and (inventory.protocols or {})[class] ~= nil then
            return nil
        end
        return sign ~= nil and has(class, selector, sign)
    elseif entry.kind == "property" then
        local class, property = entry.api:match("^([%w_]+)%.([%w_]+)$")
        return class ~= nil and (has(class, property, "-") or has(class, "set" .. property:sub(1, 1):upper() .. property:sub(2) .. ":", "-"))
    end
    return nil
end

local function in_range(entry, deployment)
    if not deployment then
        return false
    end
    return not (entry.minimum and dyld.compare_versions(deployment, entry.minimum) < 0)
        and not (entry.maximum and dyld.compare_versions(deployment, entry.maximum) >= 0)
end

function entry_of(listed, name, inventory)
    for spelling in pairs(spellings(name)) do
        if listed[spelling] then
            return listed[spelling]
        end
    end
    local owner = name:match("^[-+]%[([%w_]+) ") or name:match("^([%u][%w_]*)%.")
    if not owner then
        return nil
    end
    local carried = inventory and inventory.classes and inventory.classes[owner]
    if carried and carried.image then
        return nil
    end
    return listed[owner]
end

local function header_folders(root)
    return {root, path.join(root, "*"), path.join(root, ".gen", "*")}
end

local function declared_names(root, sdkdir)
    local names, ours = {}, {}
    for _, file in ipairs(os.files(path.join(root, "*.h"))) do
        for word in io.readfile(file):gmatch("[%w_]+") do
            ours[word] = true
        end
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for word in io.readfile(file):gmatch("[%w_]+") do
                ours[word] = true
            end
        end
    end
    if sdkdir and os.isdir(sdkdir) then
        local spelling = type(sdkdir) == "table" and table.concat(sdkdir, " ") or tostring(sdkdir)
        local kept = path.join(dyld.root(), "cache", "sdk-header-names-v1-"
                              .. hash.strhash128(spelling):sub(1, 16) .. ".txt")
        local text = os.isfile(kept) and io.readfile(kept) or nil
        if not text then
            local found = os.tmpfile()
            for _, folder in ipairs({path.join(sdkdir, "usr/include"), path.join(sdkdir, "System/Library/Frameworks")}) do
                if os.isdir(folder) then
                    os.execv("grep", {"-rhoE", "[A-Za-z_][A-Za-z0-9_]*", folder}, {stdout = found})
                end
            end
            text = io.readfile(found) or ""
            os.tryrm(found)
            io.writefile(kept, text)
        end
        for word in text:gmatch("[%w_]+") do
            names[word] = true
        end
    end
    for _, word in ipairs(table.keys(ours)) do
        names[word] = true
    end
    return names
end

local SDK_DECLARATIONS = {}

function sdk_protocol_declarations(sdkdir)
    if not sdkdir or not os.isdir(sdkdir) then
        return {}
    end
    local seen = SDK_DECLARATIONS[sdkdir]
    if not seen then
        seen = {}
        local function scan(folder)
            for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
                for line in io.lines(file) do
                    for protocol in line:gmatch("@protocol%s+([%w_]+)") do
                        if not line:find("@protocol%s+" .. protocol .. "%s*;") then
                            seen[protocol] = true
                        end
                    end
                end
            end
        end
        scan(path.join(sdkdir, "usr/include"))
        for _, framework in ipairs(os.dirs(path.join(sdkdir, "System/Library/Frameworks", "*"))) do
            local resolved = framework
            if os.islink(framework) then
                local target = os.readlink(framework) or ""
                if target:sub(1, 1) ~= "/" then
                    target = path.join(path.directory(framework), target)
                end
                resolved = path.absolute(target)
            end
            scan(path.join(resolved, "Headers"))
        end
        SDK_DECLARATIONS[sdkdir] = seen
    end
    return seen
end

function inline_bodies_of(root)
    local seen = {}
    local function normalise(text)
        text = text:gsub("/%*.-%*/", " "):gsub("//[^\n]*", " ")
        return (text:gsub("%s+", " "))
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for before, after in normalise(io.readfile(file) or ""):gmatch(
                    "([%w_<>%* ]+)%s+([%w_]+)%s*%b()%s*[%w_(),\"%s]*{") do
                seen[after] = true
            end
        end
    end
    return seen
end

function protocol_declared(root, owner, inventory, sdkdir)
    if inventory and inventory.protocols and inventory.protocols[owner] ~= nil then
        return true
    end
    if sdk_protocol_declarations(sdkdir)[owner] then
        return true
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for line in io.lines(file) do
                for protocol in line:gmatch("@protocol%s+([%w_]+)") do
                    if protocol == owner and not line:find("@protocol%s+" .. protocol .. "%s*;") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function declared_protocols(root)
    local declared = {}
    for _, pattern in ipairs({"*.h", "*/*.h", path.join(".gen", "*", "*.h")}) do
        for _, file in ipairs(os.files(path.join(root, pattern))) do
            for line in io.lines(file) do
                for name in line:gmatch("@protocol%s+([%w_]+)") do
                    if not line:find("@protocol%s+" .. name .. "%s*;") then
                        declared[name] = true
                    end
                end
            end
        end
    end
    return declared
end

function documented_names(root)
    local listed = registry(root)
    local names = {}
    for api in pairs(listed) do
        for spelling in pairs(spellings(api)) do
            names[spelling] = true
        end
    end
    return names
end

function registry_step(opt, built, complete, exports)
    return check_registry(opt.root, built, complete, opt.deployment, exports,
                          release_inventory(opt.cache), opt.sdkdir, declared_protocols(opt.root))
end

function check_registry(root, found, complete, deployment, exports, inventory, sdkdir, declared)
    local listed, incomplete = registry(root)
    local unlisted, undocumented = {}, {}
    local declared_by_header
    local inline_bodies
    for _, carried in ipairs({found.classes, found.members, found.symbols}) do
        for name in pairs(carried) do
            local protocol_metadata = name:startswith("_OBJC_PROTOCOL_$_") or name:startswith("_OBJC_LABEL_PROTOCOL_$_")
            if not protocol_metadata and not entry_of(listed, name, inventory) then
                table.insert(unlisted, name)
            end
        end
    end
    local answered, stand_ins = {}, {}
    for name, entry in pairs(listed) do
        if entry.status == "absent" or entry.status == "owed" then
            local present = entry.kind == "class" and found.classes[name] or false
            present = present or ((entry.kind == "constant" or entry.kind == "function") and found.symbols[name:gsub("%(%)$", "")]) or false
            for spelling in pairs(spellings(name)) do
                present = present or (spelling:match("^[-+]%[") and (found.answered or {})[spelling]) or false
            end
            if present then
                table.insert(entry.status == "absent" and answered or stand_ins, name)
            end
        end
    end
    local held, missing = {}, {}
    if inventory then
        for name, entry in pairs(listed) do
            local natively = deployment and entry.introduced and dyld.compare_versions(deployment, entry.introduced) >= 0
            if (entry.status == "absent" or entry.status == "owed") and in_range(entry, deployment) and not natively and carried_by_release(entry, inventory) then
                table.insert(held, name)
            elseif entry.status == "ignored" and in_range(entry, deployment) and carried_by_release(entry, inventory) == false then
                table.insert(missing, name)
            end
        end
    end
    local unbuilt = {}
    local class_only = {}
    if complete ~= false then
        for name, entry in pairs(listed) do
            local built, by_member = false, false
            for spelling in pairs(spellings(name)) do
                built = built or found.classes[spelling] or found.members[spelling] or found.symbols[spelling] or false
                by_member = by_member or (found.members[spelling] or false)
            end
            local owner = name:match("^[-+]%[([%w_]+) ") or name:match("^([%u][%w_]*)%.")
            local by_owner = (owner and found.classes[owner]) or false
            built = built or by_owner or false
            built = built or (entry.kind == "class" and (found.registered or {})[name]) or false
            local carried = deployment and entry.introduced and dyld.compare_versions(entry.introduced, deployment) <= 0
            carried = carried or (exports and exports["_" .. name:gsub("%(%)$", "")]) or false
            local ours = not deployment or in_range(entry, deployment)
            local declared = entry.kind == "protocol" and ((declared or {})[name] or protocol_declared(root, name, inventory, sdkdir)) or
                (owner and listed[owner] and listed[owner].kind == "protocol" and
                 protocol_declared(root, owner, inventory, sdkdir)) or
                (owner and inventory and inventory.protocols and inventory.protocols[owner] ~= nil) or false
            if entry.status == "implemented" and by_owner and by_member == false and ours and not carried and not declared then
                table.insert(class_only, name)
            end
            if entry.kind == "function" and not built then
                inline_bodies = inline_bodies or inline_bodies_of(root)
                local bare = (name:gsub("%(%)$", ""))
                if inline_bodies[bare] then
                    built = true
                end
            end
            if (entry.kind == "type" or entry.kind == "case") and not built then
                declared_by_header = declared_by_header or declared_names(root, sdkdir)
                built = declared_by_header[name] or false
            end
            if entry.status == "implemented" and not built and not carried and ours and not declared then
                table.insert(unbuilt, name)
            elseif entry.status == "implemented" and not entry.facts then
                table.insert(undocumented, name)
            end
        end
    end
    byteorder.sort(unlisted)
    byteorder.sort(unbuilt)
    byteorder.sort(answered)
    byteorder.sort(stand_ins)
    byteorder.sort(held)
    byteorder.sort(missing)
    byteorder.sort(class_only)
    if #stand_ins > 0 then
        cprint("${color.warning}note:${clear} %d owed rows have a stand-in built (the real behaviour is owed)", #stand_ins)
        for _, name in ipairs(stand_ins) do
            cprint("  ${color.warning}%s${clear}", name)
        end
    end
    if #unlisted > 0 or #unbuilt > 0 or #answered > 0 or #held > 0 or #missing > 0 or #incomplete > 0 then
        local lines = {"the registry does not describe what the backports carry:"}
        for _, described in ipairs(incomplete) do
            table.insert(lines, "  " .. described)
        end
        if #unlisted > 0 then
            table.insert(lines, "  built, but no entry in registry/: " .. table.concat(unlisted, "; "))
        end
        if #unbuilt > 0 then
            table.insert(lines, "  listed as implemented, but nothing of that name is built: " .. table.concat(unbuilt, "; "))
        end
        if #answered > 0 then
            table.insert(lines, "  listed as absent, but what is built answers it: " .. table.concat(answered, "; "))
        end
        if #held > 0 then
            table.insert(lines, "  listed as absent, but the release carries it itself, so it is the release's own and not absent: " .. table.concat(held, "; "))
        end
        if #missing > 0 then
            table.insert(lines, "  listed as ignored because the release carries it, but the release does not: " .. table.concat(missing, "; "))
        end
        raise(table.concat(lines, "\n"))
    end
    return #undocumented, #class_only, class_only, stand_ins
end


local function carried_names(object, architecture)
    local names, ours = {}, {}
    for _, symbol in ipairs(exported_symbols(object)) do
        local class = symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
        if class then
            ours[class] = true
        end
        names[class or symbol:sub(2)] = true
    end
    for _, member in ipairs(added_members(objc.binary_inventory(object, architecture), ours)) do
        names[member] = true
    end
    return table.orderkeys(names)
end

local function lower(a, b)
    if a == nil or b == "" then
        return b
    end
    if a == "" or b == nil then
        return a
    end
    return dyld.compare_versions(a, b) <= 0 and a or b
end

local LADDERS = {}

local function ladder(architecture)
    LADDERS[architecture] = LADDERS[architecture] or dyld.held_ladder(compatible(architecture))
    return LADDERS[architecture]
end

local function measured_introduced(opt, symbols)
    return dyld.first_releases(ladder(opt.architecture), opt.sdkdir, symbols)
end

local reexported_from

local function last_openable(architecture)
    local last
    for _, one in ipairs(compatible(architecture)) do
        for _, version in ipairs(firmware.versions(one)) do
            if not last or dyld.compare_versions(version, last) > 0 then
                last = version
            end
        end
    end
    return last
end

local function latest(a, b)
    if a == nil or a == "" then
        return b
    end
    if b == nil or b == "" then
        return a
    end
    return dyld.compare_versions(a, b) >= 0 and a or b
end

function windows(listed, objects, architecture)
    local ends = {}
    for _, object in ipairs(objects) do
        local highest, open, named = nil, false, false
        for _, name in ipairs(carried_names(object, architecture)) do
            local entry = entry_of(listed, name)
            if entry then
                named = true
                if not entry.maximum then
                    open = true
                elseif not highest or dyld.compare_versions(entry.maximum, highest) > 0 then
                    highest = entry.maximum
                end
            end
        end
        if named and not open then
            ends[object] = highest
        end
    end
    return ends
end

function minimums(listed, objects, architecture, deployment, opt)
    local found, problems, bounds, helpers = {}, {}, {}, {}
    local ends = windows(listed, objects, architecture)
    for _, object in ipairs(objects) do
        local names = carried_names(object, architecture)
        if #names == 0 then
            table.insert(helpers, object)
        else
            local by, order = {}, {}
            for _, name in ipairs(names) do
                local entry = entry_of(listed, name)
                if entry then
                    local minimum = entry.minimum or ""
                    if minimum ~= "" and deployment and dyld.compare_versions(minimum, deployment) <= 0 then
                        minimum = ""
                    end
                    if not by[minimum] then
                        by[minimum] = {}
                        table.insert(order, minimum)
                    end
                    table.insert(by[minimum], name)
                end
            end
            if #order > 1 then
                table.sort(order, function (a, b) return lower(a, b) == a and a ~= b end)
                local described = {}
                for _, minimum in ipairs(order) do
                    table.insert(described, string.format("%s with %s", table.concat(by[minimum], " "), minimum == "" and "no registry minimum" or ("registry minimum " .. minimum)))
                end
                table.insert(problems, string.format("%s defines %s; an object is carried from one release on, so split it", path.filename(object), table.concat(described, " and ")))
            end
            bounds[object] = #order == 1 and order[1] or ""
        end
    end
    local definer, helper = {}, {}
    for _, object in ipairs(objects) do
        for _, symbol in ipairs(defined_symbols(object, true)) do
            definer[symbol] = object
        end
    end
    for _, object in ipairs(helpers) do
        helper[object] = true
    end
    local changed = true
    while changed do
        changed = false
        for _, object in ipairs(objects) do
            if bounds[object] then
                for _, symbol in ipairs(undefined_symbols(object)) do
                    local named = definer[symbol]
                    if named and named ~= object and helper[named] then
                        local bound = lower(bounds[named], bounds[object])
                        if bound ~= bounds[named] then
                            bounds[named] = bound
                            changed = true
                        end
                    end
                end
            end
        end
    end
    local unreached = {}
    for _, object in ipairs(objects) do
        if bounds[object] == nil then
            table.insert(unreached, object)
        elseif bounds[object] ~= "" then
            found[object] = bounds[object]
        end
    end
    local needs, inherited = {}, {}
    for _, object in ipairs(unreached) do
        needs[object] = undefined_symbols(object)
    end
    changed = true
    while changed do
        changed = false
        for _, object in ipairs(unreached) do
            for _, symbol in ipairs(needs[object]) do
                local named = definer[symbol]
                local minimum = named and named ~= object and found[named]
                if minimum and (not found[object] or dyld.compare_versions(minimum, found[object]) > 0) then
                    found[object] = minimum
                    inherited[object] = {minimum = minimum, from = named, symbol = symbol}
                    changed = true
                end
            end
        end
    end

    local dropped, exported = {}, {}
    local openable = opt and last_openable(architecture) or nil
    if opt then
        local wanted = {}
        for _, object in ipairs(objects) do
            if bounds[object] ~= nil then
                for _, symbol in ipairs(exported_symbols(object)) do
                    wanted[symbol] = true
                end
                for _, symbol in ipairs(needs[object] or undefined_symbols(object)) do
                    local other = definer[symbol]
                    if other and other ~= object then
                        wanted[symbol] = true
                    end
                end
            end
        end
        exported = measured_introduced(opt, table.orderkeys(wanted))
        for _, object in ipairs(objects) do
            if bounds[object] ~= nil then
                dropped[object] = reexported_from(exported, object)
            end
        end
    end

    local unreachable = {}
    for _, object in ipairs(objects) do
        local minimum_of = found[object]
        local dropped_from = dropped[object]
        for _, symbol in ipairs(needs[object] or undefined_symbols(object)) do
            local named = definer[symbol]
            local minimum = named and named ~= object and found[named]
            local from
            if not minimum and named and named ~= object then
                from = dropped[named]
                local bound = exported[symbol]
                if from and bound and dyld.compare_versions(bound, from) <= 0 then
                    from = nil
                end
            end
            if minimum and (not minimum_of or dyld.compare_versions(minimum, minimum_of) > 0) then
                table.insert(problems, string.format("%s is carried %s and names %s, which %s defines only from %s on; it would not link below that, so give its entries that minimum or move the symbol to a file of its own",
                                                     path.filename(object), minimum_of and ("from " .. minimum_of) or "by every band", symbol, path.filename(named), minimum))
            end
            local first = from and latest(minimum_of, from)
            if from and deployment and not (ends[object] and dyld.compare_versions(first, ends[object]) >= 0) then
                if not dropped_from or dyld.compare_versions(first, dropped_from) < 0 then
                    if not openable or dyld.compare_versions(first, openable) <= 0 then
                        table.insert(problems, string.format("%s is carried %s and names %s, which %s defines only from %s on, the release it exports itself from; a band at or above that release would link this object without it, so give its entries that minimum or move the symbol to a file of its own",
                                                             path.filename(object), minimum_of and ("from " .. minimum_of) or "by every band", symbol, path.filename(named), from))
                    else
                        table.insert(unreachable, string.format("%s names %s, which %s defines only from %s on, and the band that would link this object without it starts at iOS %s, past the last firmware in the catalog for %s",
                                                                 path.filename(object), symbol, path.filename(named), from, first, architecture))
                    end
                end
            end
        end
    end
    local kept = {}
    for _, object in ipairs(unreached) do
        if not found[object] then
            table.insert(kept, object)
        end
    end
    return found, problems, kept, inherited, unreachable, ends
end

function build(opt)
    generate(opt.root, opt.sdkdir)
    INVENTORY_STORE = opt.store
    local release = loaded(opt.cache, opt.architecture)
    opt = table.join(opt, {triple = opt.architecture .. "-apple-ios" .. opt.deployment})
    COMPILED = 0
    local compiling = os.mclock()
    local attach, objects, origins, minimums, maximums = compiled(opt)
    opt = table.join(opt, {origins = origins, minimums = minimums, maximums = maximums})
    local compiled_at = os.mclock()
    local compiled, placed = COMPILED, 0
    for _, library in ipairs(staged_libraries(opt)) do
        placed = placed + (objects[library.name] and #objects[library.name] or 0)
    end
    check_releases(opt, objects, origins)
    local checked_at = os.mclock()
    local _, _, _, unlibraried = registry(opt.root)
    if #unlibraried > 0 then
        local rows, named = 0, {}
        for _, item in ipairs(unlibraried) do
            rows = rows + item.rows
            table.insert(named, string.format("%s (%d)", item.folder, item.rows))
        end
        cprint("${color.warning}note:${clear} %d generated row(s) in %d folder(s) with no library are not implemented, as no library builds the folder (generated, no library): %s",
               rows, #unlibraried, table.concat(named, ", "))
    end
    local built = {}
    for _, library in ipairs(staged_libraries(opt)) do
        table.insert(built, link(opt, library, attach, objects[library.name], {release}, opt.outputdir,
                                 {cache = opt.cache, release = opt.deployment}))
    end
    local linked_at = os.mclock()
    dyld.check(opt.cache, built)
    check_categories(release, release_inventory(opt.cache), built, opt.architecture, opt.deployment)
    if #built == #LIBRARIES then
        check_band_caches(opt, objects)
        local undocumented, class_only, class_only_names = registry_step(opt, surface(built, opt.architecture,
            declared_protocols(opt.root), documented_names(opt.root)), opt.registry, release.exports)
        if undocumented > 0 then
            cprint("${color.warning}note:${clear} %d of the registry's entries name no file of facts yet", undocumented)
        end
        if class_only > 0 then
            cprint("${color.warning}note:${clear} %d implemented member row(s) are answered by their owner class alone," ..
                   " with no member of that name in the build:", class_only)
            for _, name in ipairs(class_only_names or {}) do
                cprint("  ${color.warning}%s${clear}", name)
            end
        end
    end
    print(string.format("build: %s compiled %d of %d objects in %.1fs, measured their releases in %.1fs, linked %d libraries in %.1fs, checked in %.1fs",
                        opt.deployment, compiled, placed, (compiled_at - compiling) / 1000,
                        (checked_at - compiled_at) / 1000, #built, (linked_at - checked_at) / 1000,
                        (os.mclock() - linked_at) / 1000))
    return built
end

function introduced_version(dump, name)
    local found, current
    for line in dump:gmatch("[^\n]+") do
        local dumping = line:match("^Dumping (.-):$")
        if dumping then
            current = dumping
        elseif current == name then
            local version = line:match("^[|`]%-AvailabilityAttr.- ios (%d+[%.%d]*) ")
            if version and (not found or dyld.compare_versions(version, found) < 0) then
                found = version
            end
        end
    end
    return found
end

function availability_names(symbols)
    local names = {}
    for _, symbol in ipairs(symbols) do
        names[symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
              or symbol:match("^_OBJC_IVAR_%$_(.-)%.") or symbol:sub(2)] = true
    end
    return names
end

local LISTED = {}

local function listed(root)
    LISTED[root] = LISTED[root] or registry(root)
    return LISTED[root]
end

function floors(opt)
    local top
    for _, entry in pairs(listed(opt.root)) do
        if entry.minimum and dyld.compare_versions(entry.minimum, opt.deployment) > 0 and (not top or dyld.compare_versions(entry.minimum, top) > 0) then
            top = entry.minimum
        end
    end
    if not top then
        return {}
    end
    local function at(release)
        return table.join(opt, {deployment = release, triple = opt.architecture .. "-apple-ios" .. release})
    end
    local objects, origins, pending = {}, {}, {}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, source in ipairs(sources(opt.root, library)) do
            local object = path.join(opt.builddir, "objects-" .. top, library.folder, path.basename(source) .. ".o")
            os.mkdir(path.directory(object))
            table.insert(pending, {opt = at(top), source = source, object = object})
            table.insert(objects, object)
            origins[object] = source
        end
    end
    compile_all(opt, pending)
    local found, problems, unreached, inherited, unreachable, ends = minimums(listed(opt.root), objects, opt.architecture, opt.deployment, opt)
    local windows_of = {}
    for _, object in ipairs(objects) do
        windows_of[origins[object]] = ends[object]
    end
    if #problems > 0 then
        raise("%d objects cannot be placed by their registry minimum above iOS %s:\n  %s", #problems, opt.deployment, table.concat(problems, "\n  "))
    end
    if #unreachable > 0 then
        cprint("${color.warning}note:${clear} %d object(s) name a definition no band of this machine links, the release that exports the definers' API having no firmware in the catalog: %s",
               #unreachable, table.concat(unreachable, "\n  "))
    end
    local taken = {}
    for _, object in ipairs(objects) do
        local from = inherited[object]
        if from then
            table.insert(taken, string.format("%s (%s, from %s by %s)", path.filename(origins[object]), from.minimum, path.filename(origins[from.from]), from.symbol))
        end
    end
    if #taken > 0 then
        cprint("${color.warning}note:${clear} %d objects carry no API the registry can place and take the highest minimum of the objects they name: %s",
               #taken, table.concat(taken, " "))
    end
    if #unreached > 0 then
        local named = {}
        for _, object in ipairs(unreached) do
            table.insert(named, path.filename(origins[object]))
        end
        cprint("${color.warning}note:${clear} %d objects carry no API the registry can place and no other object names them, so every band from iOS %s keeps them: %s",
               #named, opt.deployment, table.concat(named, " "))
    end
    local placed, pending = {}, {}
    for _, object in ipairs(objects) do
        local minimum = found[object]
        if minimum and dyld.compare_versions(minimum, opt.deployment) > 0 then
            local source = origins[object]
            if minimum ~= top then
                object = path.join(opt.builddir, "objects-" .. minimum, path.filename(path.directory(object)), path.filename(object))
                os.mkdir(path.directory(object))
                table.insert(pending, {opt = at(minimum), source = source, object = object})
            end
            placed[source] = {minimum = minimum, object = object}
        end
    end
    compile_all(opt, pending)
    return placed, windows_of
end

function reexported_from(first, object)
    local from
    for _, symbol in ipairs(exported_symbols(object)) do
        local release = first[symbol]
        if not release then
            return nil
        end
        if not from or dyld.compare_versions(release, from) > 0 then
            from = release
        end
    end
    return from
end

local function measured_names(opt, source, object)
    local file
    if opt.store and KEYS[object] then
        local signature = {}
        for _, step in ipairs(ladder(opt.architecture)) do
            table.insert(signature, step.release .. "=" .. step.architecture .. "=" .. step.source)
        end
        local key = hash.strhash128("revenant-releases-2\n" .. KEYS[object] .. "\n" .. opt.sdkdir .. "\n" .. table.concat(signature, "\n")
                                    .. "\n" .. dyld.first_release_key(ladder(opt.architecture), opt.sdkdir) .. "\n" .. own_text())
        file = path.join(opt.store, "releases", key:sub(1, 2), key .. ".lua")
        local saved = os.isfile(file) and io.load(file)
        if saved then
            os.touch(file)
            return saved.names, saved.earliest
        end
    end
    local names, earliest = {}, {}
    local symbols = exported_symbols(object)
    local first = measured_introduced(opt, symbols)
    for _, symbol in ipairs(symbols) do
        local name = symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
                     or symbol:match("^_OBJC_IVAR_%$_(.-)%.") or symbol:sub(2)
        if earliest[name] == nil then
            table.insert(names, name)
            earliest[name] = false
        end
        local version = first[symbol]
        if version and (not earliest[name] or dyld.compare_versions(version, earliest[name]) < 0) then
            earliest[name] = version
        end
    end
    for _, name in ipairs(names) do
        if not earliest[name] then
            local includes = {}
            for _, flag in ipairs(compile_arguments(opt, source)) do
                if flag:startswith("-I") then
                    table.insert(includes, flag)
                end
            end
            local minimum = opt.minimums and opt.minimums[object]
            local at = opt
            if minimum and minimum ~= "" and opt.deployment and dyld.compare_versions(minimum, opt.deployment) > 0 then
                at = table.join(opt, {deployment = minimum, triple = opt.architecture .. "-apple-ios" .. minimum})
            end
            local dump = os.iorunv(clang(at, table.join(includes, {"-fsyntax-only", "-w", "-Xclang", "-ast-dump", "-Xclang", "-ast-dump-filter", "-Xclang", name, source}), true))
            earliest[name] = introduced_version(dump, name) or false
        end
    end
    if file then
        store_folder(path.directory(file))
        local temporary = file .. "." .. hash.strhash32(object .. os.mclock()) .. ".tmp"
        io.save(temporary, {names = names, earliest = earliest})
        os.mv(temporary, file)
    end
    return names, earliest
end

function releases_in(opt, source, object)
    local names, measured = measured_names(opt, source, object)
    local earliest = {}
    for _, name in ipairs(names) do
        local version = measured[name] or nil
        if not version then
            local entry = entry_of(listed(opt.root), name)
            version = entry and entry.status == "implemented" and entry.introduced or nil
        end
        earliest[name] = version or false
    end
    local releases, unplaced = {}, {}
    for _, name in ipairs(names) do
        local version = earliest[name] or nil
        if version then
            releases[version] = releases[version] or {}
            table.insert(releases[version], name)
        else
            table.insert(unplaced, name)
        end
    end
    return releases, unplaced
end

local function misplaced(source, releases, unplaced)
    if #unplaced > 0 then
        return string.format("neither the SDK, the registry nor a held release's own cache says which iOS release %s arrived in, and %s defines it, so no band can hold it",
                             table.concat(unplaced, " "), path.filename(source))
    end
    local found = table.orderkeys(releases)
    table.sort(found, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    if #found > 1 then
        local described = {}
        for _, version in ipairs(found) do
            table.insert(described, string.format("%s from iOS %s", table.concat(releases[version], " "), version))
        end
        return string.format("%s defines %s; an object carries API that arrived in one release, so split it", path.filename(source), table.concat(described, " and "))
    end
end

local INTRODUCED = {}

local function measured(opt, source, object)
    local key = object .. ":" .. (KEYS[object] or hash.sha256(object))
    if not INTRODUCED[key] then
        local releases, unplaced = releases_in(opt, source, object)
        INTRODUCED[key] = {releases = releases, unplaced = unplaced, problem = misplaced(source, releases, unplaced)}
    end
    return INTRODUCED[key]
end

function introduced_in(opt, source, object)
    local found = measured(opt, source, object)
    if found.problem then
        raise(found.problem)
    end
    return table.orderkeys(found.releases)[1]
end

function later_than(opt, release)
    return function (object)
        return dyld.compare_versions(introduced_in(opt, opt.origins[object], object), release) > 0
    end
end

function check_releases(opt, objects, origins)
    local problems = {}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, object in ipairs(objects[library.name]) do
            if #exported_symbols(object) > 0 then
                local problem = measured(opt, origins[object], object).problem
                if problem then
                    table.insert(problems, string.format("  %s: %s", library.name, problem))
                end
            end
        end
    end
    if #problems > 0 then
        raise("%d objects hold API no single release introduced:\n%s", #problems, table.concat(problems, "\n"))
    end
end

function duplicated(objects, classes)
    local found = {}
    for _, object in ipairs(objects) do
        local defined = {}
        for _, symbol in ipairs(defined_symbols(object, true)) do
            defined[symbol] = true
        end
        for _, symbol in ipairs(exported_symbols(object)) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class and classes[class] and not defined["_OBJC_CLASS_$_Revenant" .. class] then
                found[class] = path.filename(object)
            end
        end
    end
    local named = table.orderkeys(found)
    local told = {}
    for _, class in ipairs(named) do
        table.insert(told, string.format("%s (%s)", class, found[class]))
    end
    return told
end

function band_ranges(points, listed)
    local ranges = {}
    for index, point in ipairs(points) do
        local following = points[index + 1]
        local first, last
        for _, version in ipairs(listed) do
            if dyld.compare_versions(version, point) >= 0 and (not following or dyld.compare_versions(version, following) < 0) then
                first = first or version
                last = version
            end
        end
        if not first and index == 1 then
            raise("no firmware in the catalog runs iOS %s or later%s, so its API has no band", point, following and (" and before " .. following) or "")
        end
        if first then
            table.insert(ranges, {point = point, first = first, last = last})
        end
    end
    return ranges
end

local function release_cache(opt, architectures, release)
    local held = held_cache(opt.architecture, release)
    if held then
        return held
    end
    local cache, found = firmware.ensure(architectures[release], release, {tool = opt.tool})
    if found ~= release then
        raise("the band of iOS %s is checked against that release, and the %s firmware nearest to it is %s", release, architectures[release], tostring(found))
    end
    return cache
end

local function band_plan(opt, objects)
    local points = {[opt.deployment] = true}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, object in ipairs(objects[library.name]) do
            if #exported_symbols(object) > 0 then
                local version = introduced_in(opt, opt.origins[object], object)
                if dyld.compare_versions(version, opt.deployment) > 0 then
                    points[version] = true
                end
            end
            if (opt.minimums or {})[object] then
                points[opt.minimums[object]] = true
            end
            local ends = (opt.maximums or {})[object]
            if ends and dyld.compare_versions(ends, opt.deployment) > 0 then
                points[ends] = true
            end
        end
    end
    points = table.orderkeys(points)
    table.sort(points, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    local architectures = {}
    for _, architecture in ipairs(compatible(opt.architecture)) do
        for _, version in ipairs(firmware.versions(architecture)) do
            architectures[version] = architectures[version] or architecture
        end
    end
    local listed = table.orderkeys(architectures)
    table.sort(listed, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    return band_ranges(points, listed), architectures
end

function check_band_caches(opt, objects)
    local ranges, architectures = band_plan(opt, objects)
    local missing = {}
    for _, range in ipairs(ranges) do
        for _, release in ipairs(table.unique({range.first, range.last})) do
            local held = held_cache(opt.architecture, release)
            local cached = held and path.filename(held):match("^dyld_shared_cache_(.+)$")
            if not held then
                table.insert(missing, string.format("  iOS %s, an end of the band of iOS %s (%s to %s): xmake firmware --arch=%s fetch %s",
                                                    release, range.point, range.first, range.last, architectures[release], release))
            elseif cached and not os.isdir(dyld.outside_source(path.directory(held), cached)) then
                table.insert(missing, string.format("  iOS %s, an end of the band of iOS %s (%s to %s), without the libraries it carries outside its shared cache: xmake firmware --arch=%s fetch %s",
                                                    release, range.point, range.first, range.last, cached, release))
            end
        end
    end
    if #missing > 0 then
        raise("the staged bands cannot have their imports checked: %s does not hold all of %d releases they are checked against\n%s",
              dyld.root(), #missing, table.concat(missing, "\n"))
    end
    return ranges
end

function stage_bands(opt)
    opt = table.join(opt, {triple = opt.architecture .. "-apple-ios" .. opt.deployment})
    local attach, objects, origins, minimums, maximums = compiled(opt)
    opt = table.join(opt, {origins = origins, minimums = minimums, maximums = maximums})
    check_releases(opt, objects, origins)
    local ranges, architectures = band_plan(opt, objects)
    local home = path.join(opt.stage, INSTALL_FOLDER)
    local lines = {}
    for _, range in ipairs(ranges) do
        local releases, signatures, caches = {}, {}, {}
        for _, release in ipairs(table.unique({range.first, range.last})) do
            local file = release_cache(opt, architectures, release)
            local found = loaded(file, opt.architecture)
            table.insert(releases, found)
            table.insert(caches, {cache = file, release = release})
            local reexported = {}
            for _, library in ipairs(staged_libraries(opt)) do
                local _, symbols = band(found.exports, objects[library.name], later_than(opt, release), {release = release, minimums = opt.minimums, maximums = opt.maximums})
                table.join2(reexported, symbols)
            end
            signatures[release] = table.concat(reexported, " ")
        end
        if signatures[range.first] ~= signatures[range.last] then
            raise("iOS %s and %s export different backported symbols (%s, and %s), although the SDK says nothing the backports define arrived between them",
                  range.first, range.last, signatures[range.first], signatures[range.last])
        end
        local built = {}
        for _, library in ipairs(staged_libraries(opt)) do
            table.insert(built, link(opt, library, attach, objects[library.name], releases, path.join(home, "bands", range.first), caches[1]))
        end
        for index, release in ipairs(table.unique({range.first, range.last})) do
            dyld.check(release_cache(opt, architectures, release), built)
            check_categories(releases[index], release_inventory(caches[index].cache), built, opt.architecture, release)
        end
        for index = #built, 1, -1 do
            os.vrunv("xcrun", {"strip", "-x", built[index]})
            signing.sign(opt.ldid, built[index])
        end
        table.insert(lines, range.first .. " " .. range.last)
    end
    io.writefile(path.join(home, "bands", "ranges"), table.concat(lines, "\n") .. "\n")
    return ranges
end

POSTINST = [[
#!/bin/sh
set -e
root="${DPKG_ROOT:-}"
home="$root@HOME@"
version=$(sed -n '/<key>ProductVersion<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$root/System/Library/CoreServices/SystemVersion.plist" 2>/dev/null || true)
if [ -z "$version" ]; then
    echo "@PACKAGE@ cannot read ProductVersion from $root/System/Library/CoreServices/SystemVersion.plist, so it cannot pick the libraries for this iOS" >&2
    exit 1
fi
older() {
    left=$1 right=$2
    while [ -n "$left$right" ]; do
        a=${left%%.*} b=${right%%.*}
        if [ "$left" = "$a" ]; then left=; else left=${left#*.}; fi
        if [ "$right" = "$b" ]; then right=; else right=${right#*.}; fi
        if [ "${a:-0}" -lt "${b:-0}" ]; then return 0; fi
        if [ "${a:-0}" -gt "${b:-0}" ]; then return 1; fi
    done
    return 1
}
band=
while read -r first last; do
    if ! older "$version" "$first" && ! older "$last" "$version"; then
        band=$first
    fi
done < "$home/bands/ranges"
if [ -z "$band" ]; then
    echo "@PACKAGE@ holds no libraries built and checked for iOS $version; it holds them for iOS $(sed 's/ / to /' "$home/bands/ranges" | tr '\n' ',' | sed 's/,$//;s/,/, /g')" >&2
    exit 1
fi
for library in "$home/bands/$band"/*.dylib; do
    ln -sf "bands/$band/${library##*/}" "$home/${library##*/}"
done
]]

PRERM = [[
#!/bin/sh
set -e
if [ "$1" = remove ]; then
    for library in "${DPKG_ROOT:-}@HOME@"/*.dylib; do
        if [ -L "$library" ]; then
            rm -f "$library"
        fi
    done
fi
]]

function write_scripts(folder)
    os.tryrm(folder)
    os.mkdir(folder)
    for name, text in pairs({postinst = POSTINST, prerm = PRERM}) do
        io.writefile(path.join(folder, name), (text:gsub("@HOME@", INSTALL_FOLDER):gsub("@PACKAGE@", PACKAGE)))
    end
end

local function corespotlight_staged(opt)
    for _, library in ipairs(staged_libraries(opt)) do
        if library.name == "CoreSpotlightBackports" then
            return true
        end
    end
    return false
end

local SEARCHBUNDLE_WITHHELD = "sending -appendResults: hangs searchd (measured on an iPad 2, facts/CoreSpotlight/CoreSpotlight.md)"

function write_searchbundle(opt)
    if not corespotlight_staged(opt) then
        return
    end
    local folder = path.join(opt.builddir, "searchbundle", "org.revenant.corespotlight.searchBundle")
    os.tryrm(folder)
    os.mkdir(folder)
    local source = path.join(opt.root, "CoreSpotlight", "SearchBundle", "RevenantSearchDatastore.m")
    local output = path.join(folder, "org.revenant.corespotlight")
    local triple = opt.architecture .. "-apple-ios" .. opt.deployment
    os.vrunv(driver(opt, {"-target", triple, "-isysroot", opt.sdkdir, "-fuse-ld=" .. opt.ld, "-fobjc-arc",
                          "-bundle", "-Os", "-g0", "-Wall", NOT_ENCRYPTED,
                          "-DREVENANT_BACKPORTS_INSTALL_FOLDER=\"" .. INSTALL_FOLDER .. "\"", "-o", output, source, "-framework", "Foundation"}))
    os.vrunv("xcrun", {"strip", "-x", output})
    signing.sign(opt.ldid, output)
    os.cp(path.join(opt.root, "CoreSpotlight", "SearchBundle", "Info.plist"), path.join(folder, "Info.plist"))
    cprint("${color.warning}withheld:${clear} org.revenant.corespotlight.searchBundle is built at %s but not packaged: %s", folder, SEARCHBUNDLE_WITHHELD)
end

function write_deb(opt)
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    local stage = path.join(opt.builddir, "stage")
    os.tryrm(stage)
    local ranges = stage_bands(table.join(opt, {stage = stage}))
    write_searchbundle(table.join(opt, {stage = stage}))
    local covered = {}
    for _, range in ipairs(ranges) do
        table.insert(covered, range.first == range.last and range.first or (range.first .. " to " .. range.last))
    end
    local control = path.join(opt.builddir, "control")
    io.writefile(control, table.concat({
        "Package: " .. PACKAGE,
        "Name: Apple API backports",
        "Architecture: iphoneos-arm",
        "Section: System",
        "Description: Objective-C classes and methods of later iOS releases for the releases that lack them, as the libraries ports built with Revenant load from " .. INSTALL_FOLDER .. "; libraries built and checked for iOS " .. table.concat(covered, ", ")
    }, "\n") .. "\n")
    local scripts = path.join(opt.builddir, "scripts")
    write_scripts(scripts)
    return debian.write({control = control, version = opt.version, root = stage, scripts = scripts, outputdir = opt.outputdir}), ranges
end

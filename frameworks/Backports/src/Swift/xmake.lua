if not is_plat("iphoneos") then
    return
end

add_requires("revenant@boringssl", {alias = "boringssl"})

local SRC = path.directory(os.scriptdir())
local TOOLS = path.join(SRC, "..", "tools")

add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
add_requires("revenant@libcxx", {alias = "libcxx"})
add_requires("revenant@micro-ecc", {alias = "micro-ecc"})
add_requires("revenant@swift 6.4.0", {alias = "swift", host = true, system = false})
add_requires("revenant@swiftui", {alias = "swiftui"})

local LOCALIZED_STRING = "import Foundation\npublic func probe() -> LocalizedStringResource { return LocalizedStringResource(\"\") }"

local APPINTENTS_PROBES = {
    {flag = "REVENANT_APPINTENTS_ATTRIBUTED_STRING",
     body = "import Foundation\npublic func probe() -> AttributedString { return AttributedString(\"x\") }"},
    {flag = "REVENANT_APPINTENTS_MEASUREMENT",
     body = "import Foundation\npublic func probe() -> Measurement { return Measurement(value: 1, unit: UnitLength.meters) }"},
    {flag = "REVENANT_APPINTENTS_RECURRENCE_RULE",
     body = "import Foundation\npublic func probe() -> Calendar.RecurrenceRule { return Calendar.RecurrenceRule(weekOfMonth: 1, weekOfYear: 2, month: 3, dayOfWeek: 4) }"}
}

local CORESPOTLIGHT = "import CoreSpotlight\npublic func probe() -> CSSearchableItem {\n"
    .. "    return CSSearchableItem(uniqueIdentifier: \"x\", domainIdentifier: nil, attributeSet: CSSearchableItemAttributeSet(contentType: \"public.item\"))\n}\n"
    .. "public func probeIndex() -> CSSearchableIndex { return CSSearchableIndex.default() }\n"

local function add_flags(target, flags)
    for _, flag in ipairs(flags) do
        target:add("values", "swift.flags", flag)
    end
end

local SWIFT_DIR = os.scriptdir()

local function stub_text(stub)
    local targets = "[ " .. table.concat(stub.targets, ", ") .. " ]"
    local lines = {"--- !tapi-tbd", "tbd-version: 4", "targets: " .. targets, "install-name: '" .. stub.installName .. "'",
                   "current-version: 1", "compatibility-version: 1", "exports:", "  - targets: " .. targets}
    if #stub.symbols > 0 then
        table.insert(lines, "    symbols: [ " .. table.concat(stub.symbols, ", ") .. " ]")
    end
    if #stub.objcClasses > 0 then
        table.insert(lines, "    objc-classes: [ " .. table.concat(stub.objcClasses, ", ") .. " ]")
    end
    table.insert(lines, "...")
    return table.concat(lines, "\n") .. "\n"
end

target("AppIntents")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_values("swift.flags", "-module-link-name", "AppIntents")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "AppIntents", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local flags = {}
        if swift.probe(target, LOCALIZED_STRING) then
            table.insert(flags, "-DREVENANT_APPINTENTS_CARRIES_LOCALIZED_STRING")
        end
        for _, probe in ipairs(APPINTENTS_PROBES) do
            if swift.probe(target, probe.body) then
                table.insert(flags, "-D" .. probe.flag)
            end
        end
        if swift.probe(target, CORESPOTLIGHT) then
            table.insert(flags, "-DREVENANT_APPINTENTS_CORESPOTLIGHT")
        end
        add_flags(target, flags)
    end)

target("ActivityKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_values("swift.flags", "-module-link-name", "ActivityKit")
    add_deps("AppIntents")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "ActivityKit", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        if swift.probe(target, LOCALIZED_STRING) then
            add_flags(target, {"-DREVENANT_PLATFORM_LOCALIZED_STRING"})
        else
            add_flags(target, {"-DREVENANT_CARRIES_LOCALIZED_STRING"})
        end
    end)

target("TipKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_values("swift.flags", "-module-link-name", "TipKit")
    add_deps("AppIntents")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "TipKit", "*.swift"))
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        if swift.probe(target, LOCALIZED_STRING) then
            add_flags(target, {"-DREVENANT_PLATFORM_LOCALIZED_STRING"})
        else
            add_flags(target, {"-DREVENANT_CARRIES_LOCALIZED_STRING"})
        end
    end)

local function open_gap(name, cause)
    before_build(function (target)
        local toolchain = target:toolchain("apple-ios")
        toolchain:load()
        raise("%s is not yet backported to iOS %s: %s; see the open gaps in frameworks/Backports/README.md", name, toolchain:config("deployment"), cause)
    end)
end

target("WidgetKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_values("swift.flags", "-module-link-name", "WidgetKit")
    add_deps("AppIntents", "ActivityKit")
    add_frameworks("Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "WidgetKit", "*.swift"))
    end)

local function createml(name, folder, deps, flags, gap)
    target(name)
        set_kind("static")
        set_default(false)
        add_rules("@addon/revenant/swift")
        if #deps > 0 then
            add_deps(table.unpack(deps))
        end
        add_frameworks("Accelerate", "Foundation", "CoreFoundation")
        set_optimize("fastest")
        on_load(function (target)
            target:add("files", path.join(SRC, folder, "*.swift"))
        end)
        on_config(function (target)
            add_flags(target, flags or {})
        end)
        if gap then
            open_gap(name, gap)
        end
    target_end()
end

createml("TabularData", "TabularData", {}, {})
createml("CoreML", "CoreML", {}, {"-import-objc-header", path.join(SRC, "CoreML", "RevenantCoreML.h")},
         "ShapedArray.swift names MLMultiArrayDataType, which the SDK's CoreML declares for iOS 11 and later only")
createml("CreateMLComponents", "CreateMLComponents", {"TabularData", "CoreML"}, {}, "it needs CoreML, an open gap")
createml("CreateML", "CreateML", {"CreateMLComponents", "TabularData", "CoreML"}, {}, "it needs CreateMLComponents and CoreML, open gaps")

target("MusicKit")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_packages("micro-ecc")
    add_frameworks("Foundation", "CoreGraphics")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "MusicKit", "*.swift"))
        target:add("files", path.join(SRC, "MusicKit", "RevenantC.c"))
        target:add("includedirs", path.join(SRC, "MusicKit", "include"), {public = true})
        target:add("cflags", "-Os", "-fvisibility=hidden")
    end)
    on_config(function (target)
        add_flags(target, {"-import-objc-header", path.join(SRC, "MusicKit", "include", "MusicKitC.h"), "-I", path.join(SRC, "MusicKit", "include")})
    end)
    open_gap("MusicKit", "Catalog.swift uses URLComponents, which needs iOS 7, and URLQueryItem, which needs iOS 8")
    target_end()

target("SwiftData")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/swift")
    add_frameworks("CoreData", "Foundation", "CoreFoundation")
    set_optimize("fastest")
    on_load(function (target)
        target:add("files", path.join(SRC, "SwiftData", "*.swift"))
    end)
    open_gap("SwiftData", "DefaultStore.swift imports FoundationEssentials, which the iOS 6 SDK does not provide")
    target_end()

local function deployment_of(target)
    local toolchain = target:toolchain("apple-ios")
    toolchain:load()
    return toolchain:config("deployment"), toolchain
end

local function scenekit_flags(target, modules)
    local minimum, toolchain = deployment_of(target)
    local headers = path.join(toolchain:config("sdkdir"), "System", "Library", "Frameworks", "SceneKit.framework", "Headers")
    local apinote = path.join(headers, "SceneKit.apinotes")
    if modules.semver.compare(minimum, "8.0") < 0 or not os.isfile(apinote) then
        return {}
    end
    local folder = path.join(target:autogendir(), "scenekit")
    os.mkdir(folder)
    local overlay = modules.apinotes.overlay(headers, apinote, folder)
    return {"-Xcc", "-ivfsoverlay", "-Xcc", overlay}
end

local function generate_spatial(spatial, folder)
    return spatial.generate(path.join(SRC, "Spatial"), folder)
end

local function overlay(name, folder, opt)
    target(name)
        set_kind("shared")
        set_default(false)
        add_rules("@addon/revenant/swift")
        set_optimize("fastest")
        set_values("swift.module", name:sub(#"swift" + 1))
        add_shflags("-dynamiclib", "-install_name", "@rpath/lib" .. name .. ".dylib", "-Wl,-dead_strip_dylibs", {force = true})
        if opt.generate then
            add_packages("swift")
        end
        if #table.wrap(opt.deps) > 0 then
            add_deps(table.unpack(opt.deps))
        end
        if #table.wrap(opt.frameworks) > 0 then
            add_frameworks(table.unpack(opt.frameworks))
        end
        if #table.wrap(opt.packages) > 0 then
            add_packages(table.unpack(opt.packages))
        end
        if #table.wrap(opt.links) > 0 then
            add_links(table.unpack(opt.links))
        end
        on_load(function (target)
            target:add("files", path.join(SRC, folder, "*.swift"))
            for _, file in ipairs(table.wrap(opt.cfiles)) do
                target:add("files", path.join(SRC, folder, file))
            end
        end)
        before_build(function (target)
            if opt.minimum then
                local semver = import("core.base.semver")
                local minimum = deployment_of(target)
                if semver.compare(minimum, opt.minimum) < 0 then
                    raise("%s is not yet backported to iOS below %s, and this build targets iOS %s: see the open gaps in frameworks/Backports/README.md", name, opt.minimum, minimum)
                end
            end
        end)
        on_config(function (target)
            if opt.stub then
                local stub = import(opt.stub, {rootdir = SWIFT_DIR, anonymous = true}).stub()
                local folder = path.join(target:autogendir(), "stub")
                os.mkdir(folder)
                io.writefile(path.join(folder, "lib" .. stub.library .. ".tbd"), stub_text(stub))
                target:add("linkdirs", folder)
                target:add("links", stub.library)
            end
            if opt.generate then
                local folder = path.join(target:autogendir(), "spatial")
                os.mkdir(folder)
                target:add("files", table.unpack(opt.generate(import("spatial_float", {rootdir = TOOLS, anonymous = true}), folder)))
            end
            local flags = {"-parse-as-library", "-swift-version", "5", "-module-link-name", name,
                           "-Xfrontend", "-disable-implicit-string-processing-module-import"}
            if not opt.concurrency then
                table.join2(flags, {"-Xfrontend", "-disable-implicit-concurrency-module-import"})
            end
            table.join2(flags, table.wrap(opt.flags))
            if opt.scenekit then
                table.join2(flags, scenekit_flags(target, {semver = import("core.base.semver"),
                                                           apinotes = import("apinotes", {rootdir = TOOLS, anonymous = true})}))
            end
            add_flags(target, flags)
            if opt.cmodule then
                add_flags(target, {"-I", path.join(SRC, folder, opt.cmodule)})
                for _, name in ipairs(table.wrap(opt.packages)) do
                    local pkg = target:pkg(name)
                    if pkg then
                        add_flags(target, {"-Xcc", "-I" .. path.join(pkg:installdir(), "include")})
                    end
                end
            end
        end)
    target_end()
end

local FOUNDATION_LINKS = {"swiftDarwin", "swiftObjectiveC", "swiftDispatch", "swiftCoreFoundation", "swiftCoreGraphics", "swiftFoundation"}

overlay("swiftRealityFoundation", "RealityFoundation", {concurrency = true, scenekit = true, minimum = "8.0",
    frameworks = {"Foundation", "CoreFoundation", "QuartzCore", "SceneKit"},
    links = table.join(FOUNDATION_LINKS, {"swiftQuartzCore"})})

overlay("swiftRealityKit", "RealityKit", {concurrency = true, scenekit = true, minimum = "8.0", deps = {"swiftRealityFoundation"},
    frameworks = {"Foundation", "CoreFoundation", "QuartzCore", "SceneKit", "UIKit"},
    links = table.join(FOUNDATION_LINKS, {"swiftQuartzCore"})})

overlay("swiftSpatial", "Spatial", {generate = generate_spatial})

overlay("swiftCloudKit", "CloudKit", {})

overlay("swiftIOSurface", "IOSurface", {})

overlay("swiftWeatherKit", "WeatherKit", {})

overlay("swiftUniformTypeIdentifiers", "UniformTypeIdentifiers", {frameworks = {"MobileCoreServices"}})

overlay("swiftCryptoKit", "CryptoKit", {})

overlay("swiftNetwork", "Network", {frameworks = {"SystemConfiguration", "Security"}, cmodule = "RevenantTLS", stub = "network_stub"})

overlay("swiftStoreKit", "StoreKit", {concurrency = true, frameworks = {"UIKit", "Foundation"}})

overlay("swiftAuthenticationServices", "AuthenticationServices/Updater", {concurrency = true, frameworks = {"Foundation"}})

overlay("swiftTranslation", "Translation", {concurrency = true, packages = {"swiftui"}})

target("swift_backports_tests")
    set_kind("phony")
    set_default(false)
    add_tests("oslock", "uikittraits", "uikitpointer", "uikitavailability", "availability", "metallowering", "translation")
    on_test(function (target, opt)
        import("core.project.project")
        local scripts = {oslock = "os_lock_test.lua", uikittraits = "uikit_traits_test.lua", uikitpointer = "uikit_pointer_test.lua", uikitavailability = "uikit_availability_test.lua", availability = "availability_test.lua", metallowering = "metal_lowering_test.lua", translation = "translation_test.lua"}
        local name = path.filename(opt.name)
        local root = path.join(SRC, "..", "..", "..")
        local runtime = project.required_package("swift-runtime"):installdir()
        local compiler = path.join(project.required_package("swift"):installdir(), "bin", "swiftc")
        local folders = {}
        for _, package in ipairs({"swift-runtime", "swiftui", "combine"}) do
            local required = project.required_package(package)
            for _, folder in ipairs(required and table.wrap((required:envs() or {}).REVENANT_SWIFT_MODULES) or {}) do
                table.insert(folders, folder)
            end
        end
        local ok = os.execv(os.programfile(), {"l", "-P", root, path.join(SRC, "..", "tests", scripts[name])},
                            {try = true, curdir = root, envs = {REVENANT_SWIFT_RUNTIME = runtime, REVENANT_SWIFT_COMPILER = compiler,
                                                                REVENANT_TEST_MODULES = table.concat(folders, ":")}})
        if ok ~= 0 then
            opt.errors = name .. " failed"
        end
        return ok == 0
    end)
target_end()
